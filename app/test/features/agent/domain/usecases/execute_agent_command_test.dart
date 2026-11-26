import 'package:flutter_test/flutter_test.dart';
import 'package:relay_app/features/agent/domain/entities/agent_command.dart';
import 'package:relay_app/features/agent/domain/entities/agent_command_result.dart';
import 'package:relay_app/features/agent/domain/entities/agent_connection_snapshot.dart';
import 'package:relay_app/features/agent/domain/repositories/agent_gateway.dart';
import 'package:relay_app/features/agent/domain/usecases/execute_agent_command.dart';
import 'package:relay_app/features/machines/domain/entities/machine_profile.dart';

void main() {
  late _FakeAgentGateway gateway;
  late ExecuteAgentCommand execute;

  setUp(() {
    gateway = _FakeAgentGateway(
      const AgentConnectionSnapshot(
        status: AgentConnectionStatus.online,
        capabilities: ['power', 'media'],
      ),
    );
    execute = ExecuteAgentCommand(gateway);
  });

  test('bloquear envia sem exigir confirmação', () async {
    final command = AgentCommand(
      id: 'lock-id',
      type: AgentCommandType.power,
      action: 'lock',
    );

    final result = await execute(command);

    expect(result.accepted, isTrue);
    expect(gateway.sentCommands, [command]);
  });

  test('desligar sem confirmação não envia comando', () async {
    final command = AgentCommand(
      id: 'shutdown-id',
      type: AgentCommandType.power,
      action: 'shutdown',
    );

    final result = await execute(command);

    expect(result.failure, AgentCommandFailure.confirmationRequired);
    expect(gateway.sentCommands, isEmpty);
  });

  test('desligar confirmado mantém o mesmo ID ao enviar', () async {
    final command = AgentCommand(
      id: 'shutdown-id',
      type: AgentCommandType.power,
      action: 'shutdown',
    );

    final result = await execute(command, confirmed: true);

    expect(result.accepted, isTrue);
    expect(gateway.sentCommands.single.id, command.id);
  });

  test('comando bloqueia quando agente está offline', () async {
    gateway.currentSnapshot = AgentConnectionSnapshot.initial;

    final result = await execute(
      AgentCommand(id: 'lock-id', type: AgentCommandType.power, action: 'lock'),
    );

    expect(result.failure, AgentCommandFailure.connectionRequired);
    expect(gateway.sentCommands, isEmpty);
  });

  test('comando bloqueia quando agente não anuncia capacidade power', () async {
    gateway.currentSnapshot = const AgentConnectionSnapshot(
      status: AgentConnectionStatus.online,
      capabilities: ['media'],
    );

    final result = await execute(
      AgentCommand(id: 'lock-id', type: AgentCommandType.power, action: 'lock'),
    );

    expect(result.failure, AgentCommandFailure.capabilityUnavailable);
    expect(gateway.sentCommands, isEmpty);
  });

  test('volume fora do intervalo é rejeitado localmente', () async {
    final result = await execute(
      AgentCommand(
        id: 'volume-id',
        type: AgentCommandType.media,
        action: 'set_volume',
        value: 101,
      ),
    );

    expect(result.failure, AgentCommandFailure.invalidCommand);
    expect(gateway.sentCommands, isEmpty);
  });
}

class _FakeAgentGateway implements AgentGateway {
  _FakeAgentGateway(this.currentSnapshot);

  AgentConnectionSnapshot currentSnapshot;
  final List<AgentCommand> sentCommands = [];

  @override
  AgentConnectionSnapshot get snapshot => currentSnapshot;

  @override
  Stream<AgentConnectionSnapshot> get updates => const Stream.empty();

  @override
  Future<AgentCommandResult> sendCommand(AgentCommand command) async {
    sentCommands.add(command);
    return AgentCommandResult.accepted(requestId: command.id);
  }

  @override
  Future<void> connect(MachineProfile profile, String token) async {}

  @override
  Future<void> disconnect() async {}
}
