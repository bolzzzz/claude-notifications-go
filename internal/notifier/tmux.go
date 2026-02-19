package notifier

import (
	"fmt"
	"os"
	"os/exec"
	"strings"
	"time"
)

// IsTmux returns true if the current process is running inside a tmux session.
func IsTmux() bool {
	return os.Getenv("TMUX") != ""
}

// getTmuxSocketPath extracts the tmux socket path from the TMUX env var.
// TMUX format: "/private/tmp/tmux-501/default,12345,0"
func getTmuxSocketPath() string {
	tmuxEnv := os.Getenv("TMUX")
	if tmuxEnv == "" {
		return ""
	}
	// Socket path is everything before the first comma
	if idx := strings.IndexByte(tmuxEnv, ','); idx > 0 {
		return tmuxEnv[:idx]
	}
	return tmuxEnv
}

// getTmuxPath returns the absolute path to the tmux binary.
// ClaudeNotifier.app runs without the user's PATH, so we need the full path.
func getTmuxPath() string {
	if path, err := exec.LookPath("tmux"); err == nil {
		return path
	}
	return "tmux"
}

// GetTmuxPaneTarget returns the current tmux pane target (e.g. "%42")
// for use with tmux select-pane / select-window commands.
func GetTmuxPaneTarget() (string, error) {
	cmd := exec.Command("tmux", "display-message", "-p", "#{pane_id}")
	output, err := cmd.Output()
	if err != nil {
		return "", fmt.Errorf("failed to get tmux pane target: %w", err)
	}
	target := strings.TrimSpace(string(output))
	if target == "" {
		return "", fmt.Errorf("empty tmux pane target")
	}
	return target, nil
}

// buildTmuxNotifierArgs constructs command-line arguments for terminal-notifier
// when running inside tmux. Uses both -activate (to focus the terminal app)
// and -execute (to switch to the correct tmux window/pane) on click.
func buildTmuxNotifierArgs(title, message, paneTarget, bundleID string) []string {
	// Use absolute path to tmux and explicit socket — ClaudeNotifier.app
	// runs without the user's shell PATH, so bare "tmux" won't be found.
	tmuxPath := getTmuxPath()
	socketPath := getTmuxSocketPath()

	var tmuxCmd string
	if socketPath != "" {
		tmuxCmd = fmt.Sprintf(
			"'%s' -S '%s' select-window -t '%s' \\; select-pane -t '%s'",
			tmuxPath, socketPath, paneTarget, paneTarget,
		)
	} else {
		tmuxCmd = fmt.Sprintf(
			"'%s' select-window -t '%s' \\; select-pane -t '%s'",
			tmuxPath, paneTarget, paneTarget,
		)
	}

	args := []string{
		"-title", title,
		"-message", message,
		"-activate", bundleID,
		"-execute", tmuxCmd,
	}

	// Add group ID to prevent notification stacking issues
	args = append(args, "-group", fmt.Sprintf("claude-notif-%d", time.Now().UnixNano()))

	return args
}
