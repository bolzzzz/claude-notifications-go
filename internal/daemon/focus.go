//go:build linux

// ABOUTME: Window focus methods for Linux desktop environments.
// ABOUTME: Implements a fallback chain to focus windows on GNOME, KDE, Sway, and other compositors.
package daemon

import (
	"fmt"
	"os/exec"
	"strings"
)

// FocusMethod represents a method for focusing a window
type FocusMethod struct {
	Name string
	Fn   func(terminalName, folderName string) error
}

// GetFocusMethods returns the ordered list of focus methods to try
func GetFocusMethods() []FocusMethod {
	return []FocusMethod{
		{"activate-window-by-title extension", TryActivateWindowByTitle},
		{"GNOME Shell Eval (by window title)", TryGnomeShellEvalByTitle},
		{"GNOME Shell Eval (by app)", TryGnomeShellEval},
		{"GNOME Shell FocusApp", TryGnomeFocusApp},
		{"wlrctl", TryWlrctl},
		{"kdotool", TryKdotool},
		{"xdotool", TryXdotool},
	}
}

// TryFocus attempts to focus a window using available tools.
// folderName is the project folder name used for title-based window search (may be empty).
// It tries each method in order until one succeeds.
func TryFocus(terminalName, folderName string) error {
	methods := GetFocusMethods()

	var lastErr error
	for _, method := range methods {
		if err := method.Fn(terminalName, folderName); err != nil {
			lastErr = err
			continue
		}
		return nil
	}

	return fmt.Errorf("all focus methods failed, last error: %v", lastErr)
}

// TryActivateWindowByTitle uses the activate-window-by-title GNOME extension.
// https://extensions.gnome.org/extension/5021/activate-window-by-title/
// This method does NOT require unsafe_mode and works on GNOME 42+.
func TryActivateWindowByTitle(terminalName, folderName string) error {
	searchTerm := GetSearchTermWithFolder(terminalName, folderName)

	cmd := exec.Command("busctl", "--user", "call",
		"org.gnome.Shell",
		"/de/lucaswerkmeister/ActivateWindowByTitle",
		"de.lucaswerkmeister.ActivateWindowByTitle",
		"activateBySubstring", "s", searchTerm,
	)
	output, err := cmd.CombinedOutput()
	if err != nil {
		return fmt.Errorf("activate-window-by-title extension not available: %w, output: %s", err, string(output))
	}
	return nil
}

// TryGnomeShellEvalByTitle uses GNOME Shell's Eval to find and focus window by title.
// Requires unsafe_mode or development-tools enabled.
func TryGnomeShellEvalByTitle(terminalName, folderName string) error {
	searchTerm := escapeJS(GetSearchTermWithFolder(terminalName, folderName))

	// JavaScript to find window by title and activate it
	js := fmt.Sprintf(`
		(function() {
			let start = Date.now();
			let found = false;
			global.get_window_actors().forEach(function(actor) {
				let win = actor.get_meta_window();
				let title = win.get_title() || '';
				if (title.indexOf('%s') !== -1) {
					win.activate(start);
					found = true;
				}
			});
			return found ? 'activated' : 'no matching window';
		})()
	`, searchTerm)

	cmd := exec.Command("gdbus", "call",
		"--session",
		"--dest", "org.gnome.Shell",
		"--object-path", "/org/gnome/Shell",
		"--method", "org.gnome.Shell.Eval",
		js,
	)
	output, err := cmd.CombinedOutput()
	if err != nil {
		return fmt.Errorf("gdbus Eval failed: %w, output: %s", err, string(output))
	}

	outputStr := string(output)
	if strings.Contains(outputStr, "no matching window") {
		return fmt.Errorf("no window with title containing %q", searchTerm)
	}
	if strings.Contains(outputStr, "false") && !strings.Contains(outputStr, "activated") {
		return fmt.Errorf("Shell.Eval blocked (GNOME 41+ security) - install unsafe-mode-menu extension or activate-window-by-title extension")
	}

	return nil
}

// TryGnomeShellEval uses GNOME Shell's Eval method to activate an app.
// Requires unsafe_mode or development-tools enabled.
func TryGnomeShellEval(terminalName, folderName string) error {
	appID := escapeJS(GetAppID(terminalName))

	// JavaScript to find and activate the app's windows
	js := fmt.Sprintf(`
		(function() {
			let app = Shell.AppSystem.get_default().lookup_app('%s');
			if (app) {
				app.activate();
				return 'activated';
			}
			return 'app not found';
		})()
	`, appID)

	cmd := exec.Command("gdbus", "call",
		"--session",
		"--dest", "org.gnome.Shell",
		"--object-path", "/org/gnome/Shell",
		"--method", "org.gnome.Shell.Eval",
		js,
	)
	output, err := cmd.CombinedOutput()
	if err != nil {
		return fmt.Errorf("gdbus Eval failed: %w, output: %s", err, string(output))
	}

	outputStr := string(output)
	if strings.Contains(outputStr, "app not found") {
		return fmt.Errorf("app not found via Shell.Eval")
	}
	if strings.Contains(outputStr, "false") && !strings.Contains(outputStr, "activated") {
		return fmt.Errorf("Shell.Eval blocked (GNOME 41+ security) - install unsafe-mode-menu extension or activate-window-by-title extension")
	}

	return nil
}

// TryGnomeFocusApp uses GNOME Shell's FocusApp method (available since GNOME 45).
func TryGnomeFocusApp(terminalName, folderName string) error {
	appID := GetAppID(terminalName)

	cmd := exec.Command("gdbus", "call",
		"--session",
		"--dest", "org.gnome.Shell",
		"--object-path", "/org/gnome/Shell",
		"--method", "org.gnome.Shell.FocusApp",
		appID,
	)
	output, err := cmd.CombinedOutput()
	if err != nil {
		return fmt.Errorf("gdbus FocusApp failed: %w, output: %s", err, string(output))
	}
	return nil
}

// TryWlrctl uses wlrctl for wlroots-based compositors (Sway, etc.).
func TryWlrctl(terminalName, folderName string) error {
	if _, err := exec.LookPath("wlrctl"); err != nil {
		return fmt.Errorf("wlrctl not installed")
	}

	// Try app_id first (more reliable)
	appID := GetWlrctlAppID(terminalName)
	cmd := exec.Command("wlrctl", "toplevel", "focus", "app_id:"+appID)
	if err := cmd.Run(); err == nil {
		return nil
	}

	// Fallback to title
	searchTerm := GetSearchTermWithFolder(terminalName, folderName)
	cmd = exec.Command("wlrctl", "toplevel", "focus", "title:"+searchTerm)
	output, err := cmd.CombinedOutput()
	if err != nil {
		return fmt.Errorf("wlrctl failed: %w, output: %s", err, string(output))
	}
	return nil
}

// TryKdotool uses kdotool for KDE Plasma.
func TryKdotool(terminalName, folderName string) error {
	if _, err := exec.LookPath("kdotool"); err != nil {
		return fmt.Errorf("kdotool not installed")
	}

	// Search by class
	className := GetKdotoolClass(terminalName)
	searchCmd := exec.Command("kdotool", "search", "--class", className)
	output, err := searchCmd.CombinedOutput()
	outputStr := strings.TrimSpace(string(output))

	if err != nil || outputStr == "" {
		return fmt.Errorf("no windows found via kdotool")
	}

	windowIDs := strings.Split(outputStr, "\n")

	cmd := exec.Command("kdotool", "windowactivate", windowIDs[0])
	if _, err := cmd.CombinedOutput(); err != nil {
		return fmt.Errorf("kdotool windowactivate failed: %w", err)
	}
	return nil
}

// TryXdotool uses xdotool for X11-based desktop environments
// (XFCE, MATE, Cinnamon, i3, bspwm, and X11 sessions of GNOME/KDE).
func TryXdotool(terminalName, folderName string) error {
	if _, err := exec.LookPath("xdotool"); err != nil {
		return fmt.Errorf("xdotool not installed")
	}

	// Search by class name first (more reliable)
	className := GetXdotoolClass(terminalName)
	searchCmd := exec.Command("xdotool", "search", "--class", className)
	output, err := searchCmd.CombinedOutput()
	outputStr := strings.TrimSpace(string(output))

	if err != nil || outputStr == "" {
		// Fallback: search by window name
		searchTerm := GetSearchTermWithFolder(terminalName, folderName)
		searchCmd = exec.Command("xdotool", "search", "--name", searchTerm)
		output, err = searchCmd.CombinedOutput()
		outputStr = strings.TrimSpace(string(output))
	}

	if err != nil || outputStr == "" {
		return fmt.Errorf("no windows found via xdotool")
	}

	// Take the first matching window
	windowIDs := strings.Split(outputStr, "\n")
	cmd := exec.Command("xdotool", "windowactivate", windowIDs[0])
	if _, err := cmd.CombinedOutput(); err != nil {
		return fmt.Errorf("xdotool windowactivate failed: %w", err)
	}
	return nil
}

// DetectFocusTools returns a map of available focus tools.
func DetectFocusTools() map[string]bool {
	tools := map[string]bool{}

	// Check command-line tools
	for _, tool := range []string{"wlrctl", "kdotool", "xdotool", "gdbus", "busctl"} {
		_, err := exec.LookPath(tool)
		tools[tool] = err == nil
	}

	// Check GNOME activate-window-by-title extension
	cmd := exec.Command("busctl", "--user", "introspect",
		"org.gnome.Shell",
		"/de/lucaswerkmeister/ActivateWindowByTitle",
	)
	output, err := cmd.CombinedOutput()
	tools["activate-window-by-title"] = err == nil && strings.Contains(string(output), "activateBySubstring")

	return tools
}
