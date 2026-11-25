package platform

import "context"

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

type Native struct{}

func New() Provider { return Native{} }

// Metrics collection and media control are independent follow-up integrations.
func (Native) Metrics(context.Context) (Metrics, error)             { return Metrics{}, nil }
func (Native) ExecuteMedia(context.Context, string, *float64) error { return ErrNotImplemented }

var ErrNotImplemented = errNotImplemented{}

type errNotImplemented struct{}

func (errNotImplemented) Error() string { return "integração de plataforma ainda não implementada" }
