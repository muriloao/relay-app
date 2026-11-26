import '../../../metrics/domain/entities/metrics_collection_failure.dart';
import '../../../metrics/domain/entities/performance_sample.dart';

class AgentMetricsModel {
  const AgentMetricsModel({
    required this.cpuPercent,
    required this.memoryUsedBytes,
    required this.memoryTotalBytes,
    required this.downloadBytesPerSecond,
    required this.uploadBytesPerSecond,
  });

  final double cpuPercent;
  final int memoryUsedBytes;
  final int memoryTotalBytes;
  final int downloadBytesPerSecond;
  final int uploadBytesPerSecond;

  factory AgentMetricsModel.fromJson(Map<String, dynamic> json) {
    final cpu = json['cpu_percent'];
    if (cpu is! num || !cpu.isFinite || cpu < 0 || cpu > 100) {
      throw const FormatException('cpu_percent inválido');
    }
    return AgentMetricsModel(
      cpuPercent: cpu.toDouble(),
      memoryUsedBytes: _requiredInteger(json, 'memory_used_bytes'),
      memoryTotalBytes: _requiredInteger(json, 'memory_total_bytes'),
      downloadBytesPerSecond: _requiredInteger(
        json,
        'download_bytes_per_second',
      ),
      uploadBytesPerSecond: _requiredInteger(json, 'upload_bytes_per_second'),
    );
  }

  PerformanceSample toEntity(DateTime capturedAt) => PerformanceSample(
    capturedAt: capturedAt,
    cpuPercent: cpuPercent,
    memoryUsedBytes: memoryUsedBytes,
    memoryTotalBytes: memoryTotalBytes,
    downloadBytesPerSecond: downloadBytesPerSecond,
    uploadBytesPerSecond: uploadBytesPerSecond,
  );

  static int _requiredInteger(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is! num || !value.isFinite || value < 0) {
      throw FormatException('$key inválido');
    }
    return value.toInt();
  }
}

class MetricsCollectionFailureModel {
  const MetricsCollectionFailureModel._();

  static MetricsCollectionFailure fromJson(
    Map<String, dynamic> json,
    DateTime fallbackTime,
  ) {
    final rawTimestamp = json['timestamp'];
    final timestamp = rawTimestamp is String
        ? DateTime.tryParse(rawTimestamp)
        : null;
    final failures = json['failures'];
    final parsedFailures = <MetricSourceFailure>[];
    if (failures is List) {
      for (final failure in failures) {
        if (failure is! Map) continue;
        final source = failure['source'];
        final message = failure['message'];
        if (source is! String || message is! String) continue;
        parsedFailures.add(
          MetricSourceFailure(source: source, message: message),
        );
      }
    }
    if (parsedFailures.isEmpty) {
      parsedFailures.add(
        const MetricSourceFailure(
          source: 'collector',
          message: 'O agente informou uma falha na coleta.',
        ),
      );
    }
    return MetricsCollectionFailure(
      capturedAt: timestamp?.toLocal() ?? fallbackTime,
      failures: parsedFailures,
    );
  }
}
