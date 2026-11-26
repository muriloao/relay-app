import 'dart:io';

Future<void> sendMagicPacket(List<int> packet) async {
  final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
  try {
    socket.broadcastEnabled = true;
    final sent = socket.send(packet, InternetAddress('255.255.255.255'), 9);
    if (sent != packet.length) {
      throw const SocketException(
        'Não foi possível enviar o pacote Wake-on-LAN.',
      );
    }
  } finally {
    socket.close();
  }
}
