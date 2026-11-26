import '../entities/performance_sample.dart';

abstract interface class PerformanceHistoryRepository {
  Future<List<PerformanceSample>> load(String machineId);

  Future<void> append(String machineId, PerformanceSample sample);
}
