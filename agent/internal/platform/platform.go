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

type Provider interface {
	Metrics(context.Context) (Metrics, error)
	ExecutePower(context.Context, string) error
	ExecuteMedia(context.Context, string, *float64) error
}

type Native struct {
	mu             sync.Mutex
	previousAt     time.Time
	previousCPU    cpu.TimesStat
	previousNetIn  uint64
	previousNetOut uint64
	hasPrevious    bool
}

func New() Provider { return &Native{} }

func (n *Native) Metrics(ctx context.Context) (Metrics, error)       { return n.collectMetrics(ctx) }
func (*Native) ExecuteMedia(context.Context, string, *float64) error { return ErrNotImplemented }

func (n *Native) ResetMetrics() {
	n.mu.Lock()
	defer n.mu.Unlock()
	n.previousAt = time.Time{}
	n.previousCPU = cpu.TimesStat{}
	n.previousNetIn = 0
	n.previousNetOut = 0
	n.hasPrevious = false
}

var ErrNotImplemented = errNotImplemented{}

type errNotImplemented struct{}

func (errNotImplemented) Error() string { return "integração de plataforma ainda não implementada" }
