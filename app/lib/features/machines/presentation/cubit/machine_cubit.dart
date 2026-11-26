import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../agent/domain/entities/agent_command.dart';
import '../../../agent/domain/entities/agent_command_result.dart';
import '../../../agent/domain/entities/agent_connection_snapshot.dart';
import '../../../agent/domain/repositories/agent_gateway.dart';
import '../../../agent/domain/usecases/execute_agent_command.dart';
import '../../../pairing/domain/entities/pairing_payload.dart';
import '../../domain/entities/machine_profile.dart';
import '../../domain/usecases/load_machine_profiles.dart';
import '../../domain/usecases/read_machine_token.dart';
import '../../domain/usecases/save_machine_pairing.dart';
import 'command_execution_state.dart';
import 'machine_state.dart';

class MachineCubit extends Cubit<MachineState> {
  MachineCubit({
    required LoadMachineProfiles loadMachineProfiles,
    required SaveMachinePairing saveMachinePairing,
    required ReadMachineToken readMachineToken,
    required ExecuteAgentCommand executeAgentCommand,
    required AgentGateway agentGateway,
  }) : this._(
         loadMachineProfiles,
         saveMachinePairing,
         readMachineToken,
         executeAgentCommand,
         agentGateway,
       );

  MachineCubit._(
    this._loadMachineProfiles,
    this._saveMachinePairing,
    this._readMachineToken,
    this._executeAgentCommand,
    this._agentGateway,
  ) : super(MachineState(connection: _agentGateway.snapshot)) {
    _connectionSubscription = _agentGateway.updates.listen((connection) {
      emit(state.copyWith(connection: connection));
    });
  }

  final LoadMachineProfiles _loadMachineProfiles;
  final SaveMachinePairing _saveMachinePairing;
  final ReadMachineToken _readMachineToken;
  final ExecuteAgentCommand _executeAgentCommand;
  final AgentGateway _agentGateway;
  late final StreamSubscription<AgentConnectionSnapshot>
  _connectionSubscription;

  Future<void> loadProfiles() async {
    emit(state.copyWith(isLoading: true, clearPageError: true));
    try {
      final profiles = await _loadMachineProfiles();
      emit(
        state.copyWith(
          profiles: profiles,
          selectedMachineId: profiles.isEmpty ? null : profiles.first.id,
          clearSelectedMachine: profiles.isEmpty,
          isLoading: false,
          clearPageError: true,
        ),
      );
      if (profiles.isNotEmpty) await _connect(profiles.first);
    } catch (error) {
      emit(
        state.copyWith(
          isLoading: false,
          pageError: 'Não foi possível abrir as máquinas salvas: $error',
        ),
      );
    }
  }

  Future<void> selectMachine(String profileId) async {
    MachineProfile? profile;
    for (final item in state.profiles) {
      if (item.id == profileId) {
        profile = item;
        break;
      }
    }
    if (profile == null || state.selectedMachineId == profile.id) return;

    emit(state.copyWith(selectedMachineId: profile.id));
    await _connect(profile);
  }

  Future<String?> addPairing(PairingPayload pairing) async {
    try {
      final profile = await _saveMachinePairing(pairing);
      emit(
        state.copyWith(
          profiles: [...state.profiles, profile],
          selectedMachineId: profile.id,
          clearPageError: true,
        ),
      );
      await _connect(profile);
      return null;
    } catch (error) {
      return 'Não foi possível salvar o pareamento: $error';
    }
  }

  Future<void> reconnectSelected() async {
    final profile = state.selectedProfile;
    if (profile != null) await _connect(profile);
  }

  Future<void> executeCommand(
    AgentCommand command, {
    bool confirmed = false,
  }) async {
    final commandKey = '${command.type.name}:${command.action}';
    final currentExecution = state.commandExecutions[commandKey];
    if (currentExecution?.status == CommandExecutionStatus.sending) return;

    if (command.requiresConfirmation && !confirmed) {
      final result = await _executeAgentCommand(command);
      if (isClosed) return;
      _updateCommandExecution(
        commandKey,
        CommandExecutionState(
          requestId: command.id,
          status: result.failure == AgentCommandFailure.confirmationRequired
              ? CommandExecutionStatus.awaitingConfirmation
              : CommandExecutionStatus.failed,
          message: _commandMessage(result),
        ),
      );
      return;
    }

    _updateCommandExecution(
      commandKey,
      CommandExecutionState(
        requestId: command.id,
        status: CommandExecutionStatus.sending,
      ),
    );

    final result = await _executeAgentCommand(command, confirmed: confirmed);
    if (isClosed) return;
    _updateCommandExecution(
      commandKey,
      CommandExecutionState(
        requestId: result.requestId,
        status: result.accepted
            ? CommandExecutionStatus.accepted
            : CommandExecutionStatus.failed,
        message: result.accepted ? null : _commandMessage(result),
      ),
    );
  }

  void _updateCommandExecution(
    String commandKey,
    CommandExecutionState execution,
  ) {
    final commandExecutions = Map<String, CommandExecutionState>.of(
      state.commandExecutions,
    )..[commandKey] = execution;
    emit(state.copyWith(commandExecutions: commandExecutions));
  }

  String? _commandMessage(AgentCommandResult result) =>
      switch (result.failure) {
        AgentCommandFailure.confirmationRequired =>
          'Este comando exige confirmação.',
        AgentCommandFailure.connectionRequired =>
          'Conecte-se à máquina para enviar comandos.',
        AgentCommandFailure.capabilityUnavailable =>
          'O agente não oferece suporte a este comando.',
        AgentCommandFailure.invalidCommand =>
          result.message ?? 'O comando ou seus parâmetros são inválidos.',
        AgentCommandFailure.timeout =>
          result.message ?? 'O agente não confirmou o comando dentro do prazo.',
        AgentCommandFailure.transport =>
          result.message ?? 'A conexão foi perdida antes da confirmação.',
        AgentCommandFailure.agentRejected =>
          result.message ?? 'O agente não conseguiu executar o comando.',
        null => null,
      };

  Future<void> _connect(MachineProfile profile) async {
    try {
      final token = await _readMachineToken(profile.id);
      if (isClosed || state.selectedMachineId != profile.id) return;
      await _agentGateway.connect(profile, token);
    } catch (error) {
      if (isClosed) return;
      emit(
        state.copyWith(
          connection: AgentConnectionSnapshot(
            status: AgentConnectionStatus.error,
            statusMessage: 'Não foi possível abrir o perfil: $error',
          ),
        ),
      );
    }
  }

  @override
  Future<void> close() async {
    await _connectionSubscription.cancel();
    return super.close();
  }
}
