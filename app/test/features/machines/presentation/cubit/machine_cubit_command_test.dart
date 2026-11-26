import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:relay_app/features/agent/domain/entities/agent_command.dart';
import 'package:relay_app/features/agent/domain/entities/agent_command_result.dart';
import 'package:relay_app/features/agent/domain/entities/agent_connection_snapshot.dart';
import 'package:relay_app/features/agent/domain/repositories/agent_gateway.dart';
import 'package:relay_app/features/agent/domain/usecases/execute_agent_command.dart';
import 'package:relay_app/features/machines/domain/entities/machine_profile.dart';
import 'package:relay_app/features/machines/domain/repositories/machine_repository.dart';
import 'package:relay_app/features/machines/domain/usecases/load_machine_profiles.dart';
import 'package:relay_app/features/machines/domain/usecases/read_machine_token.dart';
import 'package:relay_app/features/machines/domain/usecases/save_machine_pairing.dart';
import 'package:relay_app/features/pairing/domain/entities/pairing_payload.dart';
import 'package:relay_app/features/machines/presentation/cubit/command_execution_state.dart';
import 'package:relay_app/features/machines/presentation/cubit/machine_cubit.dart';

void main() {
  late _FakeAgentGateway gateway;
  late MachineCubit cubit;

  setUp(() {
    gateway = _FakeAgentGateway();
    const repository = _EmptyMachineRepository();
    cubit = MachineCubit(
      loadMachineProfiles: LoadMachineProfiles(repository),
      saveMachinePairing: SaveMachinePairing(repository),
      readMachineToken: ReadMachineToken(repository),
      executeAgentCommand: ExecuteAgentCommand(gateway),
      agentGateway: gateway,
    );
  });

  tearDown(() async {
    await cubit.close();
    await gateway.close();
  });

  test('bloqueio passa por enviando e termina aceito', () async {
    final command = _lockCommand();

    final execution = cubit.executeCommand(command);
    expect(
      cubit.state.commandExecutions['power:lock']?.status,
      CommandExecutionStatus.sending,
    );
    await execution;

    final result = cubit.state.commandExecutions['power:lock'];
    expect(result?.status, CommandExecutionStatus.accepted);
    expect(result?.requestId, command.id);
  });

  test('erro do agente termina em falha sem mudar conexão', () async {
    gateway.result = AgentCommandResult.rejected(
      requestId: 'lock-id',
      failure: AgentCommandFailure.agentRejected,
      message: 'Permissão negada.',
    );

    await cubit.executeCommand(_lockCommand());

    final result = cubit.state.commandExecutions['power:lock'];
    expect(result?.status, CommandExecutionStatus.failed);
    expect(result?.message, 'Permissão negada.');
    expect(cubit.state.connection.status, AgentConnectionStatus.online);
  });

  test('reinício aguarda confirmação e reusa o ID quando confirmado', () async {
    const command = AgentCommand(
      id: 'restart-id',
      type: AgentCommandType.power,
      action: 'restart',
    );

    await cubit.executeCommand(command);
    expect(
      cubit.state.commandExecutions['power:restart']?.status,
      CommandExecutionStatus.awaitingConfirmation,
    );
    expect(gateway.sentCommands, isEmpty);

    await cubit.executeCommand(command, confirmed: true);

    expect(gateway.sentCommands.single.id, command.id);
    expect(
      cubit.state.commandExecutions['power:restart']?.status,
      CommandExecutionStatus.accepted,
    );
  });
}

AgentCommand _lockCommand() => const AgentCommand(
  id: 'lock-id',
  type: AgentCommandType.power,
  action: 'lock',
);

class _FakeAgentGateway implements AgentGateway {
  final StreamController<AgentConnectionSnapshot> _updates =
      StreamController<AgentConnectionSnapshot>.broadcast();
  final List<AgentCommand> sentCommands = [];
  AgentCommandResult? result;

  @override
  AgentConnectionSnapshot get snapshot => const AgentConnectionSnapshot(
    status: AgentConnectionStatus.online,
    capabilities: ['power', 'media'],
  );

  @override
  Stream<AgentConnectionSnapshot> get updates => _updates.stream;

  @override
  Future<AgentCommandResult> sendCommand(AgentCommand command) async {
    sentCommands.add(command);
    return result ?? AgentCommandResult.accepted(requestId: command.id);
  }

  @override
  Future<void> connect(MachineProfile profile, String token) async {}

  @override
  Future<void> disconnect() async {}

  Future<void> close() => _updates.close();
}

class _EmptyMachineRepository implements MachineRepository {
  const _EmptyMachineRepository();

  @override
  Future<List<MachineProfile>> loadProfiles() async => const [];

  @override
  Future<String> readToken(String profileId) async => '';

  @override
  Future<MachineProfile> savePairing(PairingPayload pairing) =>
      throw UnimplementedError();
}
