//go:build darwin

package platform

import (
	"context"
	"fmt"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
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
set positionText to "0"
set durationText to "0"
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
      tell application "Music" to set positionText to player position as text
      tell application "Music" to set durationText to (duration of current track / 1000) as text
    end try
  else
    try
      tell application "Spotify" to set titleText to name of current track as text
      tell application "Spotify" to set artistText to artist of current track as text
      tell application "Spotify" to set positionText to player position as text
      tell application "Spotify" to set durationText to (duration of current track / 1000) as text
    end try
  end if
end if
set volumeInfo to get volume settings
set volumeLevel to output volume of volumeInfo as text
set isMuted to output muted of volumeInfo as text

return chosen & sep & chosenState & sep & titleText & sep & artistText & sep & volumeLevel & sep & isMuted & sep & positionText & sep & durationText`
	out, err := runAppleScript(ctx, script)
	if err != nil {
		return MediaState{}, err
	}
	parts := strings.Split(strings.TrimSpace(out), mediaSeparator)
	if len(parts) != 8 {
		return MediaState{}, fmt.Errorf("resposta inválida ao consultar estado de mídia")
	}
	volume, err := strconv.Atoi(parts[4])
	if err != nil {
		return MediaState{}, fmt.Errorf("volume retornado pelo macOS inválido: %w", err)
	}
	position, _ := strconv.ParseFloat(parts[6], 64)
	duration, _ := strconv.ParseFloat(parts[7], 64)
	state := MediaState{Status: "ok", Player: parts[0], Playback: parts[1], Title: parts[2], Artist: parts[3], Volume: volume, Muted: parts[5] == "true", PositionMS: int64(position * 1000), DurationMS: int64(duration * 1000)}
	artworkKey := state.Player + "\x00" + state.Title + "\x00" + state.Artist
	n.mediaMu.Lock()
	cached := n.mediaArtworkKey == artworkKey
	if cached {
		state.Artwork = append([]byte(nil), n.mediaArtwork...)
		state.ArtworkMIME = n.mediaArtworkMIME
	}
	n.mediaMu.Unlock()
	if !cached && state.Player != "" {
		if artwork, mimeType, readErr := readMacArtwork(ctx, state.Player); readErr == nil {
			state.Artwork = artwork
			state.ArtworkMIME = mimeType
		}
		n.mediaMu.Lock()
		n.mediaArtworkKey = artworkKey
		n.mediaArtwork = append(n.mediaArtwork[:0], state.Artwork...)
		n.mediaArtworkMIME = state.ArtworkMIME
		n.mediaMu.Unlock()
	} else if !cached {
		n.mediaMu.Lock()
		n.mediaArtworkKey = artworkKey
		n.mediaArtwork = nil
		n.mediaArtworkMIME = ""
		n.mediaMu.Unlock()
	}
	if state.Player == "" {
		state.Status = "no_media"
		state.Playback = "no_media"
	}
	return state, nil
}

func readMacArtwork(ctx context.Context, player string) ([]byte, string, error) {
	file, err := os.CreateTemp("", "relay-media-cover-*.img")
	if err != nil {
		return nil, "", err
	}
	defer os.Remove(file.Name())
	if err := file.Close(); err != nil {
		return nil, "", err
	}
	path := strings.ReplaceAll(filepath.Clean(file.Name()), `"`, `\"`)
	script := fmt.Sprintf(`tell application %q to write (data of artwork 1 of current track) to POSIX file "%s"`, player, path)
	if err := runAppleScriptAction(ctx, script); err != nil {
		return nil, "", err
	}
	data, err := os.ReadFile(file.Name())
	if err != nil {
		return nil, "", err
	}
	if len(data) == 0 || len(data) > 2*1024*1024 {
		return nil, "", fmt.Errorf("capa de mídia vazia ou acima do limite")
	}
	return data, http.DetectContentType(data), nil
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
		if action == "seek" {
			if value == nil || *value < 0 || *value > 86400000 {
				return fmt.Errorf("seek exige posição entre 0 e 86400000 ms")
			}
			state, err := n.MediaState(ctx)
			if err != nil {
				return err
			}
			if state.Status == "no_media" {
				return ErrNoMedia
			}
			seconds := *value / 1000
			return runAppleScriptAction(ctx, fmt.Sprintf("tell application %q to set player position to %.3f", state.Player, seconds))
		}
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

func (*Native) Capabilities() []string {
	return []string{"metrics", "media", "power", "power.lock", "power.shutdown", "power.restart"}
}
