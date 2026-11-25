//go:build darwin

package platform

import (
	"context"
	"fmt"
	"os/exec"
	"strings"
	"time"
)

func (Native) ExecutePower(ctx context.Context, action string) error {
	var script string
	switch action {
	case "lock":
		// Uses the documented Control-Command-Q lock-screen shortcut.
		script = `tell application "System Events" to keystroke "q" using {control down, command down}`
	case "shutdown":
		script = `tell application "System Events" to shut down`
	case "restart":
		script = `tell application "System Events" to restart`
	default:
		return fmt.Errorf("ação de energia não suportada no macOS: %s", action)
	}
	commandCtx, cancel := context.WithTimeout(ctx, 15*time.Second)
	defer cancel()
	output, err := exec.CommandContext(commandCtx, "/usr/bin/osascript", "-e", script).CombinedOutput()
	if err != nil {
		message := strings.TrimSpace(string(output))
		if message == "" {
			message = err.Error()
		}
		return fmt.Errorf("ação %s no macOS falhou: %s", action, message)
	}
	return nil
}
