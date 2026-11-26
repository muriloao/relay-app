package platform

import (
	"context"
	"sync"
	"time"

	"github.com/shirou/gopsutil/v4/cpu"
)

type Metrics struct {
	CPUPercent             float64 `json:"cpu_percent"`
	MemoryUsed             uint64  `json:"memory_used_bytes"`
	MemoryTotal            uint64  `json:"memory_total_bytes"`
	DownloadBytesPerSecond uint64  `json:"download_bytes_per_second"`
	UploadBytesPerSecond   uint64  `json:"upload_bytes_per_second"`
}

type MediaState struct {
	Status      string `json:"status"`
	Player      string `json:"player,omitempty"`
	Playback    string `json:"playback"`
	Title       string `json:"title,omitempty"`
	Artist      string `json:"artist,omitempty"`
	Volume      int    `json:"volume"`
	Muted       bool   `json:"muted"`
	PositionMS  int64  `json:"position_ms,omitempty"`
	DurationMS  int64  `json:"duration_ms,omitempty"`
	ArtworkID   string `json:"artwork_id,omitempty"`
	ArtworkMIME string `json:"artwork_mime_type,omitempty"`
	Artwork     []byte `json:"-"`
	Error       string `json:"error,omitempty"`
}

type Provider interface {
	Capabilities() []string
	Metrics(context.Context) (Metrics, error)
	MediaState(context.Context) (MediaState, error)
	ExecutePower(context.Context, string) error
	ExecuteMedia(context.Context, string, *float64) error
}

type Native struct {
	mu                sync.Mutex
	mediaMu           sync.Mutex
	mediaArtworkKey   string
	mediaArtwork      []byte
	mediaArtworkMIME  string
	previousCPUAt     time.Time
	previousCPU       cpu.TimesStat
	previousNetworkAt time.Time
	previousNetIn     uint64
	previousNetOut    uint64
	hasPreviousCPU    bool
	hasPreviousNet    bool
}

func New() Provider { return &Native{} }

func (n *Native) Metrics(ctx context.Context) (Metrics, error) { return n.collectMetrics(ctx) }
func (n *Native) ResetMetrics() {
	n.mu.Lock()
	defer n.mu.Unlock()
	n.previousCPUAt = time.Time{}
	n.previousCPU = cpu.TimesStat{}
	n.previousNetworkAt = time.Time{}
	n.previousNetIn = 0
	n.previousNetOut = 0
	n.hasPreviousCPU = false
	n.hasPreviousNet = false
}

type MetricSourceFailure struct {
	Source  string `json:"source"`
	Message string `json:"message"`
}

type MetricsError struct {
	Failures []MetricSourceFailure
}

func (e *MetricsError) Error() string {
	return "uma ou mais fontes de métricas falharam"
}

var ErrNotImplemented = errNotImplemented{}
var ErrNoMedia = noMediaError{}

type errNotImplemented struct{}

func (errNotImplemented) Error() string { return "integração de plataforma ainda não implementada" }

type noMediaError struct{}

func (noMediaError) Error() string {
	return "no_media: nenhuma sessão de mídia compatível está ativa"
}
