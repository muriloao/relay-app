package config

import (
	"crypto/rand"
	"encoding/hex"
	"encoding/json"
	"errors"
	"os"
	"path/filepath"
)

const DefaultPort = 8765

type Config struct {
	Name  string `json:"name"`
	Port  int    `json:"port"`
	Token string `json:"token"`
}

func Load(path string) (Config, error) {
	if path == "" {
		var err error
		path, err = DefaultPath()
		if err != nil {
			return Config{}, err
		}
	}
	machineName := hostname()
	cfg := Config{Name: machineName, Port: DefaultPort}
	changed := false
	data, err := os.ReadFile(path)
	if err == nil {
		if err := json.Unmarshal(data, &cfg); err != nil {
			return Config{}, err
		}
	} else if !errors.Is(err, os.ErrNotExist) {
		return Config{}, err
	} else {
		changed = true
	}
	if cfg.Port < 1 || cfg.Port > 65535 {
		return Config{}, errors.New("port deve estar entre 1 e 65535")
	}
	if cfg.Name == "" || cfg.Name == "Relay PC" {
		cfg.Name = machineName
		changed = true
	}
	if cfg.Token == "" {
		var token [32]byte
		if _, err := rand.Read(token[:]); err != nil {
			return Config{}, err
		}
		cfg.Token = hex.EncodeToString(token[:])
		changed = true
	}
	if changed {
		if err := os.MkdirAll(filepath.Dir(path), 0700); err != nil {
			return Config{}, err
		}
		data, err := json.MarshalIndent(cfg, "", "  ")
		if err != nil {
			return Config{}, err
		}
		if err := os.WriteFile(path, data, 0600); err != nil {
			return Config{}, err
		}
	}
	return cfg, nil
}

func hostname() string {
	name, err := os.Hostname()
	if err != nil || name == "" {
		return "Relay PC"
	}
	return name
}

func DefaultPath() (string, error) {
	base, err := os.UserConfigDir()
	if err != nil {
		return "", err
	}
	return filepath.Join(base, "relay", "config.json"), nil
}
