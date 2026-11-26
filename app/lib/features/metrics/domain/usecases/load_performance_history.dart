import '../entities/performance_sample.dart';
import '../repositories/performance_history_repository.dart';

class LoadPerformanceHistory {
  const LoadPerformanceHistory(this._repository);

  final PerformanceHistoryRepository _repository;

  Future<List<PerformanceSample>> call(String machineId) =>
      _repository.load(machineId);
}
