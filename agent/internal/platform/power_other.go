//go:build !windows && !darwin

package platform

import (
	"context"
	"fmt"
)

func (*Native) ExecutePower(_ context.Context, action string) error {
	return fmt.Errorf("ação de energia não suportada neste sistema: %s", action)
}
