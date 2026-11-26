import 'dart:convert';
import 'dart:io';

class PairingPayload {
  const PairingPayload({
    required this.name,
    required this.host,
    required this.port,
    required this.mac,
    required this.token,
  });

  final String name;
  final String host;
  final int port;
  final String mac;
  final String token;

  factory PairingPayload.decode(String raw) {
    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      throw const FormatException('O QR não contém um JSON válido.');
    }
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('O QR não contém dados de pareamento.');
    }

    final name = decoded['name'];
    final host = decoded['ip'];
    final port = decoded['port'];
    final mac = decoded['mac'];
    final token = decoded['token'];
    if (name is! String ||
        host is! String ||
        port is! int ||
        mac is! String ||
        token is! String) {
      throw const FormatException('O QR não contém os campos esperados.');
    }

    final cleanName = name.trim();
    final cleanHost = host.trim();
    final cleanMac = mac.trim();
    final cleanToken = token.trim();
    if (cleanName.isEmpty) {
      throw const FormatException('O nome da máquina está vazio.');
    }
    if (InternetAddress.tryParse(cleanHost) == null) {
      throw const FormatException('O endereço IP do QR é inválido.');
    }
    if (port < 1 || port > 65535) {
      throw const FormatException('A porta do agente é inválida.');
    }
    if (!RegExp(r'^(?:[0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}$').hasMatch(cleanMac)) {
      throw const FormatException('O endereço MAC do QR é inválido.');
    }
    if (cleanToken.isEmpty) {
      throw const FormatException('O QR não contém o token do agente.');
    }

    return PairingPayload(
      name: cleanName,
      host: cleanHost,
      port: port,
      mac: cleanMac,
      token: cleanToken,
    );
  }

  PairingPayload copyWith({String? name, String? host}) => PairingPayload(
    name: name ?? this.name,
    host: host ?? this.host,
    port: port,
    mac: mac,
    token: token,
  );
}
