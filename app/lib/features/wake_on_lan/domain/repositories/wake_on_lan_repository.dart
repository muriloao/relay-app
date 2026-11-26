abstract interface class WakeOnLanRepository {
  Future<void> sendMagicPacket(String macAddress);
}
