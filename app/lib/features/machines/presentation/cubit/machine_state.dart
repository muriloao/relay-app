import '../../../agent/domain/entities/agent_connection_snapshot.dart';
import '../../domain/entities/machine_profile.dart';

class MachineState {
  const MachineState({
    this.profiles = const [],
    this.selectedMachineId,
    this.isLoading = false,
    this.pageError,
    this.connection = AgentConnectionSnapshot.initial,
  });

  final List<MachineProfile> profiles;
  final String? selectedMachineId;
  final bool isLoading;
  final String? pageError;
  final AgentConnectionSnapshot connection;

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
  }) => MachineState(
    profiles: profiles ?? this.profiles,
    selectedMachineId: clearSelectedMachine
        ? null
        : selectedMachineId ?? this.selectedMachineId,
    isLoading: isLoading ?? this.isLoading,
    pageError: clearPageError ? null : pageError ?? this.pageError,
    connection: connection ?? this.connection,
  );
}
