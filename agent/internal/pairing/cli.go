package pairing

import (
	"encoding/json"
	"fmt"
	"net/http"
	"strings"
	"time"

	qrcode "github.com/skip2/go-qrcode"
	"github.com/muriloao/relay-app/internal/protocol"
)

func fetch(address, path string, dst any) error {
	client := http.Client{Timeout: 3*time.Second}
	resp, err := client.Get("http://"+address+path)
	if err != nil { return fmt.Errorf("daemon não respondeu em %s: %w", address, err) }
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK { return fmt.Errorf("daemon retornou HTTP %d", resp.StatusCode) }
	return json.NewDecoder(resp.Body).Decode(dst)
}

func Status(address string) error {
	var status map[string]any
	if err := fetch(address, "/admin/status", &status); err != nil { return err }
	for key, value := range status { fmt.Printf("%s: %v\n", key, value) }
	return nil
}

func ShowQR(address string) error {
	var info protocol.PairingInfo
	if err := fetch(address, "/admin/pairing", &info); err != nil { return err }
	payload, err := json.Marshal(info)
	if err != nil { return err }
	qr, err := qrcode.New(string(payload), qrcode.Medium)
	if err != nil { return err }
	qr.DisableBorder = false
	// Unicode half-block renderer preserves the QR's square modules in common terminals.
	bitmap := qr.Bitmap()
	for y := 0; y < len(bitmap); y += 2 {
		for x := 0; x < len(bitmap[y]); x++ {
			top, bottom := bitmap[y][x], y+1 < len(bitmap) && bitmap[y+1][x]
			switch { case top && bottom: fmt.Print("█"); case top: fmt.Print("▀"); case bottom: fmt.Print("▄"); default: fmt.Print(" ") }
		}
		fmt.Println()
	}
	fmt.Printf("Pareamento: %s\n", strings.TrimSpace(string(payload)))
	return nil
}
