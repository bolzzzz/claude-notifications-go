//go:build windows

package notifier

import (
	"os"

	"github.com/777genius/claude-notifications/internal/logging"
)

// sendTerminalBell writes a BEL character to os.Stdout to trigger terminal
// tab indicators on Windows terminals (e.g. Windows Terminal, PowerShell, cmd).
// On Windows there is no /dev/tty, so we write to Stdout as the closest equivalent
// to the controlling terminal. Stdout is preferred over Stderr to avoid losing
// the bell when stderr is redirected (e.g. 2> errors.log).
func sendTerminalBell() {
	if _, err := os.Stdout.Write([]byte("\a")); err != nil {
		logging.Debug("Could not write bell to stdout: %v", err)
	}
}
