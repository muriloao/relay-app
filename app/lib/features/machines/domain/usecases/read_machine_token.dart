import '../repositories/machine_repository.dart';

class ReadMachineToken {
  const ReadMachineToken(this._repository);

  final MachineRepository _repository;

  Future<String> call(String profileId) => _repository.readToken(profileId);
}
