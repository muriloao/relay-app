import '../entities/machine_profile.dart';
import '../repositories/machine_repository.dart';

class LoadMachineProfiles {
  const LoadMachineProfiles(this._repository);

  final MachineRepository _repository;

  Future<List<MachineProfile>> call() => _repository.loadProfiles();
}
