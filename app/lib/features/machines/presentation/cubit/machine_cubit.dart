import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../agent/domain/entities/agent_connection_snapshot.dart';
import '../../../agent/domain/repositories/agent_gateway.dart';
import '../../../pairing/domain/entities/pairing_payload.dart';
import '../../domain/entities/machine_profile.dart';
import '../../domain/usecases/load_machine_profiles.dart';
import '../../domain/usecases/read_machine_token.dart';
import '../../domain/usecases/save_machine_pairing.dart';
import 'machine_state.dart';

class MachineCubit extends Cubit<MachineState> {
  MachineCubit({
    required LoadMachineProfiles loadMachineProfiles,
    required SaveMachinePairing saveMachinePairing,
    required ReadMachineToken readMachineToken,
    required AgentGateway agentGateway,
  }) : this._(
         loadMachineProfiles,
         saveMachinePairing,
         readMachineToken,
         agentGateway,
       );

  MachineCubit._(
    this._loadMachineProfiles,
    this._saveMachinePairing,
    this._readMachineToken,
    this._agentGateway,
  ) : super(MachineState(connection: _agentGateway.snapshot)) {
    _connectionSubscription = _agentGateway.updates.listen((connection) {
      emit(state.copyWith(connection: connection));
    });
  }

  final LoadMachineProfiles _loadMachineProfiles;
  final SaveMachinePairing _saveMachinePairing;
  final ReadMachineToken _readMachineToken;
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
