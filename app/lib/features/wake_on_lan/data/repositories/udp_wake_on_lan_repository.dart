import '../../domain/repositories/wake_on_lan_repository.dart';
import '../datasources/udp_wake_on_lan_sender_stub.dart'
    if (dart.library.io) '../datasources/udp_wake_on_lan_sender_io.dart'
    if (dart.library.html) '../datasources/udp_wake_on_lan_sender_web.dart'
    as sender;

class UdpWakeOnLanRepository implements WakeOnLanRepository {
  const UdpWakeOnLanRepository();

  static List<int> buildMagicPacket(String macAddress) {
    final mac = macAddress
        .split(':')
        .map((part) => int.parse(part, radix: 16))
        .toList(growable: false);
    final packet = List<int>.filled(6, 0xff, growable: true);
    for (var repetition = 0; repetition < 16; repetition++) {
      packet.addAll(mac);
    }
    return packet;
  }

  @override
  Future<void> sendMagicPacket(String macAddress) =>
      sender.sendMagicPacket(buildMagicPacket(macAddress));
}
