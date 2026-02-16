//go:build !windows

package notifier

import (
	"os"

	"github.com/777genius/claude-notifications/internal/logging"
)

// sendTerminalBell writes a BEL character to /dev/tty to trigger terminal
// tab indicators (e.g. Ghostty tab highlight, tmux window bell flag).
func sendTerminalBell() {
	f, err := os.OpenFile("/dev/tty", os.O_WRONLY, 0)
	if err != nil {
		logging.Debug("Could not open /dev/tty for bell: %v", err)
		return
	}
	defer f.Close()
	if _, err := f.Write([]byte("\a")); err != nil {
		logging.Debug("Failed to write bell to /dev/tty: %v", err)
	}
}
