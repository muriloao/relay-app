import 'dart:math';

enum AgentCommandType { media, power }

class AgentCommand {
  const AgentCommand({
    required this.id,
    required this.type,
    required this.action,
    this.value,
  });

  final String id;
  final AgentCommandType type;
  final String action;
  final double? value;

  String get requiredCapability => type.name;

  bool get requiresConfirmation =>
      type == AgentCommandType.power &&
      (action == 'shutdown' || action == 'restart');

  static AgentCommand create({
    required AgentCommandType type,
    required String action,
    double? value,
  }) => AgentCommand(
    id: _newRequestId(),
    type: type,
    action: action,
    value: value,
  );

  static String _newRequestId() {
    final random = Random.secure();
    return List.generate(
      16,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
  }
}
