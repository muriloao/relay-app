package platform

import (
	"context"
	"strings"
	"time"

	"github.com/shirou/gopsutil/v4/cpu"
	"github.com/shirou/gopsutil/v4/mem"
	gnet "github.com/shirou/gopsutil/v4/net"
)

func (n *Native) collectMetrics(ctx context.Context) (Metrics, error) {
	n.mu.Lock()
	defer n.mu.Unlock()

	now := time.Now()
	result := Metrics{}
	failures := make([]MetricSourceFailure, 0, 3)

	cpuStats, err := cpu.TimesWithContext(ctx, false)
	if err != nil {
		failures = append(failures, MetricSourceFailure{Source: "cpu", Message: err.Error()})
	} else if len(cpuStats) == 0 {
		failures = append(failures, MetricSourceFailure{Source: "cpu", Message: "sistema não retornou contadores"})
	} else {
		if n.hasPreviousCPU {
			elapsed := now.Sub(n.previousCPUAt).Seconds()
			if elapsed > 0 {
				result.CPUPercent = cpuUsagePercent(n.previousCPU, cpuStats[0])
			}
		}
		n.previousCPUAt = now
		n.previousCPU = cpuStats[0]
		n.hasPreviousCPU = true
	}

	memory, err := mem.VirtualMemoryWithContext(ctx)
	if err != nil {
		failures = append(failures, MetricSourceFailure{Source: "memory", Message: err.Error()})
	} else {
		result.MemoryUsed = memory.Used
		result.MemoryTotal = memory.Total
	}

	networkIn, networkOut, err := activeNetworkCounters(ctx)
	if err != nil {
		failures = append(failures, MetricSourceFailure{Source: "network", Message: err.Error()})
	} else {
		if n.hasPreviousNet {
			elapsed := now.Sub(n.previousNetworkAt).Seconds()
			if elapsed > 0 {
				result.DownloadBytesPerSecond = byteRate(n.previousNetIn, networkIn, elapsed)
				result.UploadBytesPerSecond = byteRate(n.previousNetOut, networkOut, elapsed)
			}
		}
		n.previousNetworkAt = now
		n.previousNetIn = networkIn
		n.previousNetOut = networkOut
		n.hasPreviousNet = true
	}

	if len(failures) > 0 {
		return result, &MetricsError{Failures: failures}
	}
	return result, nil
}

func cpuUsagePercent(previous, current cpu.TimesStat) float64 {
	previousTotal := cpuTotal(previous)
	currentTotal := cpuTotal(current)
	if currentTotal <= previousTotal {
		return 0
	}
	previousIdle := previous.Idle + previous.Iowait
	currentIdle := current.Idle + current.Iowait
	totalDelta := currentTotal - previousTotal
	if currentIdle < previousIdle {
		return 0
	}
	idleDelta := currentIdle - previousIdle
	if idleDelta > totalDelta {
		return 0
	}
	used := 100 * (1 - idleDelta/totalDelta)
	if used < 0 {
		return 0
	}
	if used > 100 {
		return 100
	}
	return used
}

func cpuTotal(stat cpu.TimesStat) float64 {
	return stat.User + stat.System + stat.Idle + stat.Nice + stat.Iowait + stat.Irq + stat.Softirq + stat.Steal + stat.Guest + stat.GuestNice
}

func byteRate(previous, current uint64, elapsed float64) uint64 {
	if current <= previous || elapsed <= 0 {
		return 0
	}
	return uint64(float64(current-previous) / elapsed)
}

func activeNetworkCounters(ctx context.Context) (received, sent uint64, err error) {
	interfaces, err := gnet.InterfacesWithContext(ctx)
	if err != nil {
		return 0, 0, err
	}
	active := make(map[string]struct{}, len(interfaces))
	for _, iface := range interfaces {
		up, loopback := false, false
		for _, flag := range iface.Flags {
			switch strings.ToLower(flag) {
			case "up":
				up = true
			case "loopback":
				loopback = true
			}
		}
		if up && !loopback {
			active[iface.Name] = struct{}{}
		}
	}
	counters, err := gnet.IOCountersWithContext(ctx, true)
	if err != nil {
		return 0, 0, err
	}
	for _, counter := range counters {
		if _, ok := active[counter.Name]; !ok {
			continue
		}
		received += counter.BytesRecv
		sent += counter.BytesSent
	}
	return received, sent, nil
}
