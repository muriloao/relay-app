import '../entities/performance_sample.dart';
import '../repositories/performance_history_repository.dart';

class SavePerformanceSample {
  const SavePerformanceSample(this._repository);

  final PerformanceHistoryRepository _repository;

  Future<void> call(String machineId, PerformanceSample sample) =>
      _repository.append(machineId, sample);
}
