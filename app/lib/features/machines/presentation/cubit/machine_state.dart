import '../../../agent/domain/entities/agent_connection_snapshot.dart';
import '../../../metrics/domain/entities/performance_sample.dart';
import 'command_execution_state.dart';
import '../../domain/entities/machine_profile.dart';
import 'wake_on_lan_execution_state.dart';

class MachineState {
  const MachineState({
    this.profiles = const [],
    this.selectedMachineId,
    this.isLoading = false,
    this.pageError,
    this.connection = AgentConnectionSnapshot.initial,
    this.commandExecutions = const {},
    this.performanceHistory = const [],
    this.isHistoryLoading = false,
    this.historyError,
    this.wakeOnLan = const WakeOnLanExecutionState(),
  });

  final List<MachineProfile> profiles;
  final String? selectedMachineId;
  final bool isLoading;
  final String? pageError;
  final AgentConnectionSnapshot connection;
  final Map<String, CommandExecutionState> commandExecutions;
  final List<PerformanceSample> performanceHistory;
  final bool isHistoryLoading;
  final String? historyError;
  final WakeOnLanExecutionState wakeOnLan;

  MachineProfile? get selectedProfile {
    for (final profile in profiles) {
      if (profile.id == selectedMachineId) return profile;
    }
    return null;
  }

  MachineState copyWith({
    List<MachineProfile>? profiles,
    String? selectedMachineId,
    bool clearSelectedMachine = false,
    bool? isLoading,
    String? pageError,
    bool clearPageError = false,
    AgentConnectionSnapshot? connection,
    Map<String, CommandExecutionState>? commandExecutions,
    List<PerformanceSample>? performanceHistory,
    bool? isHistoryLoading,
    String? historyError,
    bool clearHistoryError = false,
    WakeOnLanExecutionState? wakeOnLan,
  }) => MachineState(
    profiles: profiles ?? this.profiles,
    selectedMachineId: clearSelectedMachine
        ? null
        : selectedMachineId ?? this.selectedMachineId,
    isLoading: isLoading ?? this.isLoading,
    pageError: clearPageError ? null : pageError ?? this.pageError,
    connection: connection ?? this.connection,
    commandExecutions: commandExecutions ?? this.commandExecutions,
    performanceHistory: performanceHistory ?? this.performanceHistory,
    isHistoryLoading: isHistoryLoading ?? this.isHistoryLoading,
    historyError: clearHistoryError ? null : historyError ?? this.historyError,
    wakeOnLan: wakeOnLan ?? this.wakeOnLan,
  );
}
