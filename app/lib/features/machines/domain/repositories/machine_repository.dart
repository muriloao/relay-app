import '../../../pairing/domain/entities/pairing_payload.dart';
import '../entities/machine_profile.dart';

abstract interface class MachineRepository {
  Future<List<MachineProfile>> loadProfiles();

  Future<MachineProfile> savePairing(PairingPayload pairing);

  Future<String> readToken(String profileId);
}
