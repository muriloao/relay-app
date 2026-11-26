import '../../domain/entities/performance_sample.dart';
import '../../domain/repositories/performance_history_repository.dart';
import '../datasources/hive_performance_history_data_source.dart';

class PerformanceHistoryRepositoryImpl implements PerformanceHistoryRepository {
  const PerformanceHistoryRepositoryImpl(this._dataSource);

  final HivePerformanceHistoryDataSource _dataSource;

  @override
  Future<List<PerformanceSample>> load(String machineId) =>
      _dataSource.load(machineId);

  @override
  Future<void> append(String machineId, PerformanceSample sample) =>
      _dataSource.append(machineId, sample);
}
