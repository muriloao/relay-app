import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:relay_app/features/metrics/data/datasources/hive_performance_history_data_source.dart';
import 'package:relay_app/features/metrics/domain/entities/performance_sample.dart';

void main() {
  late Directory tempDirectory;
  late Box<String> box;
  late HivePerformanceHistoryDataSource dataSource;

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp('relay-metrics-');
    Hive.init(tempDirectory.path);
    box = await Hive.openBox<String>('history-test');
    dataSource = HivePerformanceHistoryDataSource(
      historyBox: box,
      maxSamples: 60,
    );
  });

  tearDown(() async {
    await box.close();
    await Hive.close();
    await tempDirectory.delete(recursive: true);
  });

  test(
    'persiste por máquina e limita o histórico às últimas 60 amostras',
    () async {
      for (var index = 0; index < 65; index++) {
        await dataSource.append('machine-a', _sample(index));
      }

      final history = await dataSource.load('machine-a');
      final otherMachine = await dataSource.load('machine-b');

      expect(history, hasLength(60));
      expect(history.first.cpuPercent, 5);
      expect(history.last.cpuPercent, 64);
      expect(otherMachine, isEmpty);
    },
  );
}

PerformanceSample _sample(int index) => PerformanceSample(
  capturedAt: DateTime.utc(2026, 1, 1).add(Duration(seconds: index)),
  cpuPercent: index.toDouble(),
  memoryUsedBytes: index,
  memoryTotalBytes: 100,
  downloadBytesPerSecond: index * 10,
  uploadBytesPerSecond: index * 5,
);
