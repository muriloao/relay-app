import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:relay_app/features/agent/data/datasources/agent_websocket_data_source.dart';
import 'package:relay_app/features/agent/domain/entities/agent_command.dart';
import 'package:relay_app/features/agent/domain/entities/agent_command_result.dart';
import 'package:relay_app/features/agent/domain/entities/agent_connection_snapshot.dart';
import 'package:relay_app/features/machines/domain/entities/machine_profile.dart';

void main() {
  late HttpServer server;
  late AgentWebSocketDataSource dataSource;
  late Future<void> Function(WebSocket socket, Map<String, dynamic> command)
  handleCommand;
  late Future<void> Function(WebSocket socket) handleAuthentication;
  late Completer<Map<String, dynamic>> receivedCommand;

  setUp(() async {
    receivedCommand = Completer<Map<String, dynamic>>();
    handleCommand = (_, _) async {};
    handleAuthentication = (_) async {};
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      final socket = await WebSocketTransformer.upgrade(request);
      socket.add(
        jsonEncode({
          'type': 'auth_ok',
          'capabilities': ['power', 'media'],
        }),
      );
      socket.listen((rawMessage) async {
        final message =
            jsonDecode(rawMessage as String) as Map<String, dynamic>;
        if (message['type'] == 'auth') {
          await handleAuthentication(socket);
          return;
        }
        if (!receivedCommand.isCompleted) receivedCommand.complete(message);
        await handleCommand(socket, message);
      });
    });
    dataSource = AgentWebSocketDataSource(
      commandTimeout: const Duration(milliseconds: 40),
    );
  });

  tearDown(() async {
    await dataSource.dispose();
    await server.close(force: true);
  });

  Future<void> connect() => dataSource.connect(
    MachineProfile(
      id: 'machine-id',
      name: 'Test machine',
      host: InternetAddress.loopbackIPv4.address,
      port: server.port,
      mac: '00:11:22:33:44:55',
    ),
    'test-token',
  );

  AgentCommand lockCommand() => const AgentCommand(
    id: 'lock-request-id',
    type: AgentCommandType.power,
    action: 'lock',
  );

  test('envia bloqueio e correlaciona command_ack pelo ID', () async {
    handleCommand = (socket, command) async {
      socket.add(jsonEncode({'type': 'command_ack', 'id': command['id']}));
    };
    await connect();

    final result = await dataSource.sendCommand(lockCommand());
    final sent = await receivedCommand.future;

    expect(sent['type'], 'power_command');
    expect(sent['action'], 'lock');
    expect(sent['id'], lockCommand().id);
    expect(result.accepted, isTrue);
    expect(result.requestId, lockCommand().id);
  });

  test('correlaciona command_error e propaga a mensagem do agente', () async {
    handleCommand = (socket, command) async {
      socket.add(
        jsonEncode({
          'type': 'command_error',
          'id': command['id'],
          'error': 'Permissão do sistema negada.',
        }),
      );
    };
    await connect();

    final result = await dataSource.sendCommand(lockCommand());

    expect(result.failure, AgentCommandFailure.agentRejected);
    expect(result.message, 'Permissão do sistema negada.');
  });

  test('retorna timeout quando o agente não responde', () async {
    await connect();

    final result = await dataSource.sendCommand(lockCommand());
    await receivedCommand.future;

    expect(result.failure, AgentCommandFailure.timeout);
  });

  test('falha pendência quando a conexão cai antes da resposta', () async {
    handleCommand = (socket, _) async {
      await socket.close();
    };
    await connect();

    final resultFuture = dataSource.sendCommand(lockCommand());
    await receivedCommand.future;
    final result = await resultFuture;

    expect(result.failure, AgentCommandFailure.transport);
  });

  test('não trata desconexão durante reinício como falha certa', () async {
    handleCommand = (socket, _) async {
      await socket.close();
    };
    await connect();
    const command = AgentCommand(
      id: 'restart-request-id',
      type: AgentCommandType.power,
      action: 'restart',
    );

    final resultFuture = dataSource.sendCommand(command);
    await receivedCommand.future;
    final result = await resultFuture;

    expect(result.transitionUnconfirmed, isTrue);
    expect(result.failure, isNull);
    expect(result.message, contains('Verifique o estado da máquina'));
  });

  test(
    'timeout durante desligamento também indica transição incerta',
    () async {
      await connect();
      const command = AgentCommand(
        id: 'shutdown-request-id',
        type: AgentCommandType.power,
        action: 'shutdown',
      );

      final result = await dataSource.sendCommand(command);
      await receivedCommand.future;

      expect(result.transitionUnconfirmed, isTrue);
      expect(result.failure, isNull);
    },
  );

  test(
    'converte metrics_update recebido no WebSocket em amostra tipada',
    () async {
      handleAuthentication = (socket) async {
        socket.add(
          jsonEncode({
            'type': 'metrics_update',
            'status': 'ok',
            'payload': {
              'cpu_percent': 23.5,
              'memory_used_bytes': 4300000000,
              'memory_total_bytes': 8000000000,
              'download_bytes_per_second': 12800000,
              'upload_bytes_per_second': 1400000,
            },
          }),
        );
      };
      final metricsUpdate = dataSource.updates.firstWhere(
        (snapshot) => snapshot.latestMetrics != null,
      );

      await connect();
      final snapshot = await metricsUpdate;

      expect(snapshot.status, AgentConnectionStatus.online);
      expect(snapshot.latestMetrics?.cpuPercent, 23.5);
      expect(snapshot.latestMetrics?.memoryUsedBytes, 4300000000);
      expect(snapshot.latestMetrics?.downloadBytesPerSecond, 12800000);
      expect(snapshot.metricsFailure, isNull);
    },
  );
}
