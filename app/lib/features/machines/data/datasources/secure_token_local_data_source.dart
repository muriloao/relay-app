import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureTokenLocalDataSource {
  SecureTokenLocalDataSource(this._storage);

  static const _tokenKeyPrefix = 'relay.agent_token.';

  final FlutterSecureStorage _storage;

  Future<void> saveToken(String profileId, String token) =>
      _storage.write(key: '$_tokenKeyPrefix$profileId', value: token);

  Future<String> readToken(String profileId) async {
    final token = await _storage.read(key: '$_tokenKeyPrefix$profileId');
    if (token == null || token.isEmpty) {
      throw StateError('O token salvo para esta máquina não está disponível.');
    }
    return token;
  }

  Future<void> deleteToken(String profileId) =>
      _storage.delete(key: '$_tokenKeyPrefix$profileId');
}
