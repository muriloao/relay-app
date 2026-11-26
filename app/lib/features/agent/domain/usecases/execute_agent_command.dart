import '../entities/agent_command.dart';
import '../entities/agent_command_result.dart';
import '../entities/agent_connection_snapshot.dart';
import '../repositories/agent_gateway.dart';

class ExecuteAgentCommand {
  const ExecuteAgentCommand(this._agentGateway);

  final AgentGateway _agentGateway;

  Future<AgentCommandResult> call(
    AgentCommand command, {
    bool confirmed = false,
  }) async {
    if (!_isValid(command)) {
      return AgentCommandResult.rejected(
        requestId: command.id,
        failure: AgentCommandFailure.invalidCommand,
        message: 'O comando ou seus parâmetros são inválidos.',
      );
    }
    final connection = _agentGateway.snapshot;
    if (connection.status != AgentConnectionStatus.online) {
      return AgentCommandResult.rejected(
        requestId: command.id,
        failure: AgentCommandFailure.connectionRequired,
      );
    }
    final hasActionCapability = connection.capabilities.contains(
      command.actionCapability,
    );
    final supportsCommand = command.type == AgentCommandType.power
        ? hasActionCapability || connection.supportsPowerAction(command.action)
        : connection.capabilities.contains(command.requiredCapability);
    if (!supportsCommand) {
      return AgentCommandResult.rejected(
        requestId: command.id,
        failure: AgentCommandFailure.capabilityUnavailable,
      );
    }

    if (command.requiresConfirmation && !confirmed) {
      return AgentCommandResult.rejected(
        requestId: command.id,
        failure: AgentCommandFailure.confirmationRequired,
      );
    }

    return _agentGateway.sendCommand(command);
  }

  bool _isValid(AgentCommand command) {
    if (command.type == AgentCommandType.power) {
      return const {'shutdown', 'lock', 'restart'}.contains(command.action) &&
          command.value == null;
    }

    const mediaActions = {
      'play_pause',
      'next',
      'previous',
      'set_volume',
      'toggle_mute',
    };
    if (!mediaActions.contains(command.action)) return false;
    if (command.action == 'set_volume') {
      return command.value != null &&
          command.value!.isFinite &&
          command.value! >= 0 &&
          command.value! <= 100;
    }
    return command.value == null;
  }
}
