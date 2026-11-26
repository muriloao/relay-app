class MachineProfile {
  const MachineProfile({
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
}
