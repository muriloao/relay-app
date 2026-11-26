class PerformanceSample {
  const PerformanceSample({
    required this.capturedAt,
    required this.cpuPercent,
    required this.memoryUsedBytes,
    required this.memoryTotalBytes,
    required this.downloadBytesPerSecond,
    required this.uploadBytesPerSecond,
  });

  final DateTime capturedAt;
  final double cpuPercent;
  final int memoryUsedBytes;
  final int memoryTotalBytes;
  final int downloadBytesPerSecond;
  final int uploadBytesPerSecond;

  double get memoryPercent =>
      memoryTotalBytes == 0 ? 0 : memoryUsedBytes / memoryTotalBytes * 100;
}
