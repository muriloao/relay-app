//go:build !windows && !darwin

package platform

import (
	"context"
	"fmt"
)

func (*Native) MediaState(context.Context) (MediaState, error) {
	return MediaState{Status: "unavailable", Playback: "unavailable", Error: "controle de mídia não suportado nesta plataforma"}, nil
}

func (*Native) ExecuteMedia(context.Context, string, *float64) error { return ErrNotImplemented }

func (*Native) ExecutePower(_ context.Context, action string) error {
	return fmt.Errorf("ação de energia não suportada neste sistema: %s", action)
}
