package main

import (
	"context"
	"flag"
	"fmt"
	"log/slog"
	"os"
	"os/signal"
	"syscall"

	"github.com/muriloao/relay-app/internal/agent"
	"github.com/muriloao/relay-app/internal/config"
	"github.com/muriloao/relay-app/internal/pairing"
)

func main() {
	if err := run(os.Args[1:]); err != nil {
		fmt.Fprintln(os.Stderr, "relay:", err)
		os.Exit(1)
	}
}

func run(args []string) error {
	if len(args) == 0 {
		return usage()
	}
	switch args[0] {
	case "serve":
		fs := flag.NewFlagSet("serve", flag.ContinueOnError)
		configPath := fs.String("config", "", "caminho para arquivo JSON de configuração")
		if err := fs.Parse(args[1:]); err != nil { return err }
		cfg, err := config.Load(*configPath)
		if err != nil { return err }
		ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
		defer stop()
		return agent.New(cfg, slog.Default()).Run(ctx)
	case "pair", "status":
		fs := flag.NewFlagSet(args[0], flag.ContinueOnError)
		address := fs.String("address", "127.0.0.1:8765", "endereço local do daemon")
		if err := fs.Parse(args[1:]); err != nil { return err }
		if args[0] == "status" { return pairing.Status(*address) }
		return pairing.ShowQR(*address)
	default:
		return usage()
	}
}

func usage() error {
	return fmt.Errorf("uso: relay <serve|status|pair> [opções]")
}
