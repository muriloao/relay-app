package agent

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"log/slog"
	"net"
	"net/http"
	"strings"
	"sync"
	"time"

	"github.com/coder/websocket"
	"github.com/muriloao/relay-app/internal/config"
	"github.com/muriloao/relay-app/internal/platform"
	"github.com/muriloao/relay-app/internal/protocol"
)

type Server struct {
	cfg      config.Config
	log      *slog.Logger
	platform platform.Provider
	clients  sync.Map
	started  time.Time
}

func New(cfg config.Config, logger *slog.Logger) *Server {
	if logger == nil {
		logger = slog.Default()
	}
	return &Server{cfg: cfg, log: logger, platform: platform.New(), started: time.Now()}
}

func (s *Server) Run(ctx context.Context) error {
	mux := http.NewServeMux()
	mux.HandleFunc("/ws", s.websocket)
	mux.HandleFunc("/admin/status", s.localOnly(s.status))
	mux.HandleFunc("/admin/pairing", s.localOnly(s.pairing))
	server := &http.Server{Addr: fmt.Sprintf("0.0.0.0:%d", s.cfg.Port), Handler: mux, ReadHeaderTimeout: 5 * time.Second}
	go s.broadcastMetrics(ctx)
	go func() { <-ctx.Done(); _ = server.Shutdown(context.Background()) }()
	s.log.Info("daemon iniciado", "port", s.cfg.Port, "machine", s.cfg.Name)
	err := server.ListenAndServe()
	if errors.Is(err, http.ErrServerClosed) {
		return nil
	}
	return err
}

func (s *Server) localOnly(next http.HandlerFunc) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		ip, _, err := net.SplitHostPort(r.RemoteAddr)
		if err != nil || !net.ParseIP(ip).IsLoopback() {
			http.Error(w, "forbidden", http.StatusForbidden)
			return
		}
		next(w, r)
	}
}

func (s *Server) status(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}
	writeJSON(w, map[string]any{"status": "running", "name": s.cfg.Name, "port": s.cfg.Port, "uptime_seconds": int(time.Since(s.started).Seconds())})
}

func (s *Server) pairing(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}
	ip, mac := localNetworkIdentity()
	writeJSON(w, protocol.PairingInfo{IP: ip, Port: s.cfg.Port, MAC: mac, Token: s.cfg.Token, Name: s.cfg.Name})
}

func localNetworkIdentity() (string, string) {
	interfaces, _ := net.Interfaces()
	for _, iface := range interfaces {
		if iface.Flags&net.FlagUp == 0 || iface.Flags&net.FlagLoopback != 0 || len(iface.HardwareAddr) == 0 {
			continue
		}
		addrs, _ := iface.Addrs()
		for _, addr := range addrs {
			ip, _, _ := net.ParseCIDR(addr.String())
			if ip != nil && ip.To4() != nil && !ip.IsLoopback() {
				return ip.String(), iface.HardwareAddr.String()
			}
		}
	}
	return "127.0.0.1", ""
}

func (s *Server) websocket(w http.ResponseWriter, r *http.Request) {
	c, err := websocket.Accept(w, r, &websocket.AcceptOptions{InsecureSkipVerify: true})
	if err != nil {
		return
	}
	defer c.Close(websocket.StatusNormalClosure, "")
	ctx := r.Context()
	_, raw, err := c.Read(ctx)
	if err != nil {
		return
	}
	var auth protocol.Message
	if json.Unmarshal(raw, &auth) != nil || auth.Type != "auth" || auth.Token == "" || auth.Token != s.cfg.Token {
		_ = c.Write(ctx, websocket.MessageText, marshal(protocol.Response{Type: "auth_error", Error: "invalid token"}))
		c.Close(websocket.StatusPolicyViolation, "authentication failed")
		return
	}
	if err := c.Write(ctx, websocket.MessageText, marshal(protocol.Response{Type: "auth_ok", OK: true, MachineName: s.cfg.Name, Capabilities: []string{"metrics", "media", "power"}})); err != nil {
		return
	}
	s.clients.Store(c, struct{}{})
	defer s.clients.Delete(c)
	for {
		_, raw, err := c.Read(ctx)
		if err != nil {
			return
		}
		var msg protocol.Message
		if json.Unmarshal(raw, &msg) != nil {
			s.send(c, ctx, protocol.Response{Type: "command_error", Error: "invalid message"})
			continue
		}
		s.handleMessage(c, ctx, msg)
	}
}

func (s *Server) handleMessage(c *websocket.Conn, ctx context.Context, msg protocol.Message) {
	var err error
	switch msg.Type {
	case "media_command":
		err = s.platform.ExecuteMedia(ctx, msg.Action, msg.Value)
	case "power_command":
		if !validPower(msg.Action) {
			err = fmt.Errorf("ação de energia desconhecida: %s", msg.Action)
		} else {
			err = s.platform.ExecutePower(ctx, msg.Action)
		}
	default:
		err = fmt.Errorf("unknown message type")
	}
	if err != nil {
		s.send(c, ctx, protocol.Response{Type: "command_error", ID: msg.ID, Error: err.Error()})
		return
	}
	s.send(c, ctx, protocol.Response{Type: "command_ack", ID: msg.ID, OK: true})
}

func validPower(action string) bool {
	return strings.Contains("|shutdown|lock|restart|", "|"+action+"|")
}
func (s *Server) send(c *websocket.Conn, ctx context.Context, v protocol.Response) bool {
	return c.Write(ctx, websocket.MessageText, marshal(v)) == nil
}
func marshal(v any) []byte { b, _ := json.Marshal(v); return b }
func writeJSON(w http.ResponseWriter, v any) {
	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(v)
}

func (s *Server) broadcastMetrics(ctx context.Context) {
	var ticker *time.Ticker
	wasActive := false
	for {
		active := false
		s.clients.Range(func(_, _ any) bool { active = true; return false })
		if active && !wasActive {
			if resetter, ok := s.platform.(interface{ ResetMetrics() }); ok {
				resetter.ResetMetrics()
			}
		}
		wasActive = active
		if active && ticker == nil {
			ticker = time.NewTicker(time.Second)
		}
		if !active && ticker != nil {
			ticker.Stop()
			ticker = nil
		}
		if ticker == nil {
			select {
			case <-ctx.Done():
				return
			case <-time.After(500 * time.Millisecond):
			}
			continue
		}
		select {
		case <-ctx.Done():
			ticker.Stop()
			return
		case <-ticker.C:
			metrics, err := s.platform.Metrics(ctx)
			if err != nil {
				s.log.Warn("metrics collection failed", "error", err)
				continue
			}
			payload := marshal(metrics)
			s.clients.Range(func(key, _ any) bool {
				c := key.(*websocket.Conn)
				writeCtx, cancel := context.WithTimeout(ctx, 500*time.Millisecond)
				defer cancel()
				_ = c.Write(writeCtx, websocket.MessageText, marshal(protocol.Response{Type: "metrics_update", Payload: json.RawMessage(payload)}))
				return true
			})
		}
	}
}
