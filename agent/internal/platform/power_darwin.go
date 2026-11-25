//go:build darwin

package platform

import (
	"context"
	"fmt"
	"os/exec"
	"strconv"
	"strings"
	"time"
)

const mediaSeparator = "\x1f"

func (n *Native) MediaState(ctx context.Context) (MediaState, error) {
	script := `set sep to (ASCII character 31)
set chosen to ""
set chosenState to ""
set titleText to ""
set artistText to ""
tell application "System Events" to set musicRunning to (name of processes) contains "Music"
tell application "System Events" to set spotifyRunning to (name of processes) contains "Spotify"
if musicRunning then
  try
    tell application "Music" to set playerState to player state as text
    if playerState is "playing" then
      set chosen to "Music"
      set chosenState to "playing"
    else if playerState is "paused" then
      set chosen to "Music"
      set chosenState to "paused"
    end if
  end try
end if
if spotifyRunning then
  try
    tell application "Spotify" to set playerState to player state as text
    if playerState is "playing" then
      set chosen to "Spotify"
      set chosenState to "playing"
    else if playerState is "paused" and chosen is "" then
      set chosen to "Spotify"
      set chosenState to "paused"
    end if
  end try
end if
if chosen is not "" then
  if chosen is "Music" then
    try
      tell application "Music" to set titleText to name of current track as text
      tell application "Music" to set artistText to artist of current track as text
    end try
  else
    try
      tell application "Spotify" to set titleText to name of current track as text
      tell application "Spotify" to set artistText to artist of current track as text
    end try
  end if
end if
set volumeInfo to get volume settings
set volumeLevel to output volume of volumeInfo as text
set isMuted to output muted of volumeInfo as text
return chosen & sep & chosenState & sep & titleText & sep & artistText & sep & volumeLevel & sep & isMuted`
	out, err := runAppleScript(ctx, script)
	if err != nil {
		return MediaState{}, err
	}
	parts := strings.Split(strings.TrimSpace(out), mediaSeparator)
	if len(parts) != 6 {
		return MediaState{}, fmt.Errorf("resposta inválida ao consultar estado de mídia")
	}
	volume, err := strconv.Atoi(parts[4])
	if err != nil {
		return MediaState{}, fmt.Errorf("volume retornado pelo macOS inválido: %w", err)
	}
	state := MediaState{Status: "ok", Player: parts[0], Playback: parts[1], Title: parts[2], Artist: parts[3], Volume: volume, Muted: parts[5] == "true"}
	if state.Player == "" {
		state.Status = "no_media"
		state.Playback = "no_media"
	}
	return state, nil
}

func (n *Native) ExecuteMedia(ctx context.Context, action string, value *float64) error {
	if action == "set_volume" {
		if value == nil || *value < 0 || *value > 100 {
			return fmt.Errorf("set_volume exige valor entre 0 e 100")
		}
		return runAppleScriptAction(ctx, fmt.Sprintf("set volume output volume %d", int(*value+0.5)))
	}
	if action == "toggle_mute" {
		return runAppleScriptAction(ctx, `set volumeInfo to get volume settings
if output muted of volumeInfo is true then
  set volume without output muted
else
  set volume with output muted
end if`)
	}
	if action != "play_pause" && action != "next" && action != "previous" {
		return fmt.Errorf("ação de mídia desconhecida: %s", action)
	}
	state, err := n.MediaState(ctx)
	if err != nil {
		return err
	}
	if state.Status == "no_media" {
		return ErrNoMedia
	}
	commands := map[string]string{"play_pause": "playpause", "next": "next track", "previous": "previous track"}
	return runAppleScriptAction(ctx, fmt.Sprintf("tell application %q to %s", state.Player, commands[action]))
}

func runAppleScriptAction(ctx context.Context, script string) error {
	_, err := runAppleScript(ctx, script)
	return err
}

func runAppleScript(ctx context.Context, script string) (string, error) {
	commandCtx, cancel := context.WithTimeout(ctx, 10*time.Second)
	defer cancel()
	output, err := exec.CommandContext(commandCtx, "/usr/bin/osascript", "-e", script).CombinedOutput()
	if err != nil {
		message := strings.TrimSpace(string(output))
		if message == "" {
			message = err.Error()
		}
		return "", fmt.Errorf("controle de mídia no macOS falhou: %s", message)
	}
	return strings.TrimSpace(string(output)), nil
}

func (*Native) ExecutePower(ctx context.Context, action string) error {
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
