import 'dart:math';

import '../../../pairing/domain/entities/pairing_payload.dart';
import '../../domain/entities/machine_profile.dart';
import '../../domain/repositories/machine_repository.dart';
import '../datasources/hive_machine_local_data_source.dart';
import '../datasources/secure_token_local_data_source.dart';

class MachineRepositoryImpl implements MachineRepository {
  factory MachineRepositoryImpl({
    required HiveMachineLocalDataSource localDataSource,
    required SecureTokenLocalDataSource tokenDataSource,
  }) => MachineRepositoryImpl._(localDataSource, tokenDataSource);

  MachineRepositoryImpl._(this._localDataSource, this._tokenDataSource);

  final HiveMachineLocalDataSource _localDataSource;
  final SecureTokenLocalDataSource _tokenDataSource;

  @override
  Future<List<MachineProfile>> loadProfiles() =>
      _localDataSource.loadProfiles();

  @override
  Future<MachineProfile> savePairing(PairingPayload pairing) async {
    final profile = MachineProfile(
      id: _newId(),
      name: pairing.name,
      host: pairing.host,
      port: pairing.port,
      mac: pairing.mac,
    );
    await _tokenDataSource.saveToken(profile.id, pairing.token);
    try {
      await _localDataSource.saveProfile(profile);
    } catch (_) {
      await _tokenDataSource.deleteToken(profile.id);
      rethrow;
    }
    return profile;
  }

  @override
  Future<String> readToken(String profileId) =>
      _tokenDataSource.readToken(profileId);

  String _newId() {
    final random = Random.secure();
    return List.generate(
      16,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
  }
}
