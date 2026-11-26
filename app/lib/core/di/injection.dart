import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/agent/data/datasources/agent_websocket_data_source.dart';
import '../../features/agent/domain/usecases/execute_agent_command.dart';
import '../../features/agent/domain/repositories/agent_gateway.dart';
import '../../features/machines/data/datasources/hive_machine_local_data_source.dart';
import '../../features/machines/data/datasources/secure_token_local_data_source.dart';
import '../../features/machines/data/repositories/machine_repository_impl.dart';
import '../../features/machines/domain/repositories/machine_repository.dart';
import '../../features/machines/domain/usecases/load_machine_profiles.dart';
import '../../features/machines/domain/usecases/read_machine_token.dart';
import '../../features/machines/domain/usecases/save_machine_pairing.dart';
import '../../features/machines/presentation/cubit/machine_cubit.dart';
import '../../router/app_router.dart';
import 'service_locator.dart';

Future<void> configureDependencies() async {
  await Hive.initFlutter();
  final profilesBox = await Hive.openBox<String>('relay.machine_profiles');

  getIt
    ..registerSingleton<Box<String>>(profilesBox)
    ..registerLazySingleton<SharedPreferencesAsync>(SharedPreferencesAsync.new)
    ..registerLazySingleton<FlutterSecureStorage>(
      () => const FlutterSecureStorage(),
    )
    ..registerLazySingleton<Dio>(
      () => Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 5),
          receiveTimeout: const Duration(seconds: 10),
          sendTimeout: const Duration(seconds: 10),
          headers: const {'Accept': 'application/json'},
        ),
      ),
    )
    ..registerLazySingleton<HiveMachineLocalDataSource>(
      () => HiveMachineLocalDataSource(
        profilesBox: getIt<Box<String>>(),
        legacyPreferences: getIt<SharedPreferencesAsync>(),
      ),
    )
    ..registerLazySingleton<SecureTokenLocalDataSource>(
      () => SecureTokenLocalDataSource(getIt<FlutterSecureStorage>()),
    )
    ..registerLazySingleton<MachineRepository>(
      () => MachineRepositoryImpl(
        localDataSource: getIt<HiveMachineLocalDataSource>(),
        tokenDataSource: getIt<SecureTokenLocalDataSource>(),
      ),
    )
    ..registerLazySingleton<LoadMachineProfiles>(
      () => LoadMachineProfiles(getIt<MachineRepository>()),
    )
    ..registerLazySingleton<SaveMachinePairing>(
      () => SaveMachinePairing(getIt<MachineRepository>()),
    )
    ..registerLazySingleton<ReadMachineToken>(
      () => ReadMachineToken(getIt<MachineRepository>()),
    )
    ..registerLazySingleton<AgentGateway>(AgentWebSocketDataSource.new)
    ..registerLazySingleton<ExecuteAgentCommand>(
      () => ExecuteAgentCommand(getIt<AgentGateway>()),
    )
    ..registerFactory<MachineCubit>(
      () => MachineCubit(
        loadMachineProfiles: getIt<LoadMachineProfiles>(),
        saveMachinePairing: getIt<SaveMachinePairing>(),
        readMachineToken: getIt<ReadMachineToken>(),
        executeAgentCommand: getIt<ExecuteAgentCommand>(),
        agentGateway: getIt<AgentGateway>(),
      ),
    )
    ..registerSingleton(createAppRouter());
}
