import 'dart:convert';

import 'package:hive/hive.dart';

import '../../domain/entities/performance_sample.dart';

class HivePerformanceHistoryDataSource {
  const HivePerformanceHistoryDataSource({
    required this._historyBox,
    this.maxSamples = 60,
  });

  final Box<String> _historyBox;
  final int maxSamples;

  Future<List<PerformanceSample>> load(String machineId) async {
    final encoded = _historyBox.get(machineId);
    if (encoded == null || encoded.isEmpty) return const [];
    final decoded = jsonDecode(encoded);
    if (decoded is! List) {
      throw const FormatException('Histórico local de métricas inválido.');
    }
    return decoded
        .whereType<Map>()
        .map((item) => _decodeSample(Map<String, dynamic>.from(item)))
        .toList(growable: false);
  }

  Future<void> append(String machineId, PerformanceSample sample) async {
    final history = [...await load(machineId), sample];
    final boundedHistory = history.length > maxSamples
        ? history.sublist(history.length - maxSamples)
        : history;
    await _historyBox.put(
      machineId,
      jsonEncode(boundedHistory.map(_encodeSample).toList(growable: false)),
    );
  }

  Map<String, Object> _encodeSample(PerformanceSample sample) => {
    'captured_at': sample.capturedAt.toIso8601String(),
    'cpu_percent': sample.cpuPercent,
    'memory_used_bytes': sample.memoryUsedBytes,
    'memory_total_bytes': sample.memoryTotalBytes,
    'download_bytes_per_second': sample.downloadBytesPerSecond,
    'upload_bytes_per_second': sample.uploadBytesPerSecond,
  };

  PerformanceSample _decodeSample(Map<String, dynamic> json) {
    final capturedAt = DateTime.tryParse(json['captured_at'] as String? ?? '');
    final cpu = json['cpu_percent'];
    if (capturedAt == null || cpu is! num) {
      throw const FormatException('Amostra local de métricas inválida.');
    }
    return PerformanceSample(
      capturedAt: capturedAt,
      cpuPercent: cpu.toDouble(),
      memoryUsedBytes: _integer(json['memory_used_bytes']),
      memoryTotalBytes: _integer(json['memory_total_bytes']),
      downloadBytesPerSecond: _integer(json['download_bytes_per_second']),
      uploadBytesPerSecond: _integer(json['upload_bytes_per_second']),
    );
  }

  int _integer(Object? value) {
    if (value is! num) {
      throw const FormatException('Valor local de métricas inválido.');
    }
    return value.toInt();
  }
}
