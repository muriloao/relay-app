import '../../../pairing/domain/entities/pairing_payload.dart';
import '../entities/machine_profile.dart';
import '../repositories/machine_repository.dart';

class SaveMachinePairing {
  const SaveMachinePairing(this._repository);

  final MachineRepository _repository;

  Future<MachineProfile> call(PairingPayload pairing) =>
      _repository.savePairing(pairing);
}
