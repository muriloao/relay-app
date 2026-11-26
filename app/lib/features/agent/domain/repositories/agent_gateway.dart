import '../../../machines/domain/entities/machine_profile.dart';
import '../entities/agent_command.dart';
import '../entities/agent_command_result.dart';
import '../entities/agent_connection_snapshot.dart';

abstract interface class AgentGateway {
  AgentConnectionSnapshot get snapshot;

  Stream<AgentConnectionSnapshot> get updates;

  Future<void> connect(MachineProfile profile, String token);

  Future<AgentCommandResult> sendCommand(AgentCommand command);

  Future<void> disconnect();
}
