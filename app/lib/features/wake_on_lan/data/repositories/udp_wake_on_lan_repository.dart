import 'dart:io';

import '../../domain/repositories/wake_on_lan_repository.dart';

class UdpWakeOnLanRepository implements WakeOnLanRepository {
  const UdpWakeOnLanRepository();

  static List<int> buildMagicPacket(String macAddress) {
    final mac = macAddress
        .split(':')
        .map((part) => int.parse(part, radix: 16))
        .toList(growable: false);
    final packet = List<int>.filled(6, 0xff);
    for (var repetition = 0; repetition < 16; repetition++) {
      packet.addAll(mac);
    }
    return packet;
  }

  @override
  Future<void> sendMagicPacket(String macAddress) async {
    final packet = buildMagicPacket(macAddress);
    final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    try {
      socket.broadcastEnabled = true;
      final sent = socket.send(packet, InternetAddress('255.255.255.255'), 9);
      if (sent != 102) {
        throw const SocketException(
          'Não foi possível enviar o pacote Wake-on-LAN.',
        );
      }
    } finally {
      socket.close();
    }
  }
}
