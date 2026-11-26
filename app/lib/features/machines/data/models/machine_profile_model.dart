import '../../domain/entities/machine_profile.dart';

class MachineProfileModel {
  const MachineProfileModel({
    required this.id,
    required this.name,
    required this.host,
    required this.port,
    required this.mac,
  });

  final String id;
  final String name;
  final String host;
  final int port;
  final String mac;

  factory MachineProfileModel.fromEntity(MachineProfile profile) =>
      MachineProfileModel(
        id: profile.id,
        name: profile.name,
        host: profile.host,
        port: profile.port,
        mac: profile.mac,
      );

  factory MachineProfileModel.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final name = json['name'];
    final host = json['host'];
    final port = json['port'];
    final mac = json['mac'];
    if (id is! String ||
        name is! String ||
        host is! String ||
        port is! int ||
        mac is! String) {
      throw const FormatException('Perfil de máquina inválido.');
    }
    return MachineProfileModel(
      id: id,
      name: name,
      host: host,
      port: port,
      mac: mac,
    );
  }

  MachineProfile toEntity() =>
      MachineProfile(id: id, name: name, host: host, port: port, mac: mac);

  Map<String, Object> toJson() => {
    'id': id,
    'name': name,
    'host': host,
    'port': port,
    'mac': mac,
  };
}
