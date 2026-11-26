import 'dart:convert';

import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/machine_profile.dart';
import '../models/machine_profile_model.dart';

class HiveMachineLocalDataSource {
  factory HiveMachineLocalDataSource({
    required Box<String> profilesBox,
    required SharedPreferencesAsync legacyPreferences,
  }) => HiveMachineLocalDataSource._(profilesBox, legacyPreferences);

  HiveMachineLocalDataSource._(this._profilesBox, this._legacyPreferences);

  static const _legacyProfilesKey = 'relay.machine_profiles.v1';

  final Box<String> _profilesBox;
  final SharedPreferencesAsync _legacyPreferences;
  Future<void>? _migrationTask;

  Future<List<MachineProfile>> loadProfiles() async {
    await _migrateLegacyProfiles();
    return _profilesBox.values
        .map(
          (raw) => MachineProfileModel.fromJson(_decodeProfile(raw)).toEntity(),
        )
        .toList(growable: false);
  }

  Future<void> saveProfile(MachineProfile profile) => _profilesBox.put(
    profile.id,
    jsonEncode(MachineProfileModel.fromEntity(profile).toJson()),
  );

  Future<void> _migrateLegacyProfiles() =>
      _migrationTask ??= _performLegacyMigration();

  Future<void> _performLegacyMigration() async {
    if (_profilesBox.isNotEmpty) return;

    final raw = await _legacyPreferences.getString(_legacyProfilesKey);
    if (raw == null || raw.isEmpty) return;

    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      throw const FormatException('A lista local de máquinas está corrompida.');
    }
    if (decoded is! List) {
      throw const FormatException('A lista local de máquinas é inválida.');
    }

    final profiles = decoded.map((item) {
      if (item is! Map<String, dynamic>) {
        throw const FormatException('Um perfil local está inválido.');
      }
      return MachineProfileModel.fromJson(item).toEntity();
    });
    final entries = <String, String>{
      for (final profile in profiles)
        profile.id: jsonEncode(
          MachineProfileModel.fromEntity(profile).toJson(),
        ),
    };
    if (entries.isNotEmpty) await _profilesBox.putAll(entries);
    await _legacyPreferences.remove(_legacyProfilesKey);
  }

  Map<String, dynamic> _decodeProfile(String raw) {
    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      throw const FormatException('Um perfil salvo no Hive está corrompido.');
    }
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Um perfil salvo no Hive é inválido.');
    }
    return decoded;
  }
}
