import '../repositories/wake_on_lan_repository.dart';

class WakeMachine {
  const WakeMachine(this._repository);

  final WakeOnLanRepository _repository;

  Future<void> call(String macAddress) {
    final normalized = macAddress.trim();
    if (!RegExp(r'^(?:[0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}$')
        .hasMatch(normalized)) {
      throw const FormatException(
        'O endereço MAC salvo para esta máquina é inválido.',
      );
    }
    return _repository.sendMagicPacket(normalized);
  }
}
