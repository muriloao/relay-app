import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../../../machines/domain/entities/machine_profile.dart';
import '../../../metrics/domain/entities/metrics_collection_failure.dart';
import '../models/agent_metrics_model.dart';
import '../models/agent_media_state_model.dart';
import '../../domain/entities/agent_command.dart';
import '../../domain/entities/agent_command_result.dart';
import '../../domain/entities/agent_connection_snapshot.dart';
import '../../domain/repositories/agent_gateway.dart';

class AgentWebSocketDataSource implements AgentGateway {
  AgentWebSocketDataSource({this.commandTimeout = const Duration(seconds: 10)});

  WebSocketChannel? _socket;
  StreamSubscription<dynamic>? _subscription;
  Completer<void>? _authenticationCompleter;
  int _generation = 0;
  AgentConnectionSnapshot _snapshot = AgentConnectionSnapshot.initial;
  final StreamController<AgentConnectionSnapshot> _updates =
      StreamController<AgentConnectionSnapshot>.broadcast();
  final Map<String, _PendingCommand> _pendingCommands = {};

  final Duration commandTimeout;

  @override
  AgentConnectionSnapshot get snapshot => _snapshot;

  @override
  Stream<AgentConnectionSnapshot> get updates => _updates.stream;

  @override
  Future<void> connect(MachineProfile profile, String token) async {
    final generation = ++_generation;
    _resolvePendingOnDisconnect(
      'A conexão foi substituída por uma nova sessão.',
    );
    await _closeSocket();
    if (generation != _generation) return;

    _publish(
      const AgentConnectionSnapshot(status: AgentConnectionStatus.connecting),
    );

    try {
      final socket = WebSocketChannel.connect(
        Uri(scheme: 'ws', host: profile.host, port: profile.port, path: '/ws'),
      );
      await socket.ready.timeout(const Duration(seconds: 8));

      if (generation != _generation) {
        await socket.sink.close();
        return;
      }

      _socket = socket;
      final authCompleter = Completer<void>();
      _authenticationCompleter = authCompleter;
      _publish(
        const AgentConnectionSnapshot(
          status: AgentConnectionStatus.authenticating,
        ),
      );
      _subscription = socket.stream.listen(
        (data) => _handleMessage(generation, data),
        onError: (Object error, StackTrace stackTrace) {
          _handleSocketError(generation, error);
        },
        onDone: () => _handleSocketDone(generation),
      );
      socket.sink.add(jsonEncode({'type': 'auth', 'token': token}));
      await authCompleter.future.timeout(const Duration(seconds: 8));
    } catch (error) {
      if (generation != _generation) return;
      _authenticationCompleter = null;
      await _closeSocket();
      _publish(
        AgentConnectionSnapshot(
          status: AgentConnectionStatus.error,
          statusMessage: _friendlyConnectionError(error),
        ),
      );
    }
  }

  @override
  Future<AgentCommandResult> sendCommand(AgentCommand command) async {
    final socket = _socket;
    if (socket == null || _snapshot.status != AgentConnectionStatus.online) {
      return AgentCommandResult.rejected(
        requestId: command.id,
        failure: AgentCommandFailure.connectionRequired,
      );
    }

    final completer = Completer<AgentCommandResult>();
    final pending = _PendingCommand(
      completer: completer,
      mayDisconnectAgent: command.mayDisconnectAgent,
    );
    _pendingCommands[command.id] = pending;
    final message = <String, Object?>{
      'type': '${command.type.name}_command',
      'id': command.id,
      'action': command.action,
      if (command.value != null) 'value': command.value,
    };

    try {
      socket.sink.add(jsonEncode(message));
      return await completer.future.timeout(
        commandTimeout,
        onTimeout: () => pending.mayDisconnectAgent
            ? AgentCommandResult.transitionUnconfirmed(
                requestId: command.id,
                message: _transitionUnconfirmedMessage,
              )
            : AgentCommandResult.rejected(
                requestId: command.id,
                failure: AgentCommandFailure.timeout,
                message: 'O agente não confirmou o comando dentro do prazo.',
              ),
      );
    } catch (error) {
      return AgentCommandResult.rejected(
        requestId: command.id,
        failure: AgentCommandFailure.transport,
        message: _friendlyConnectionError(error),
      );
    } finally {
      if (identical(_pendingCommands[command.id], pending)) {
        _pendingCommands.remove(command.id);
      }
    }
  }

  @override
  Future<void> disconnect() async {
    _generation++;
    _resolvePendingOnDisconnect('A conexão com o agente foi encerrada.');
    _authenticationCompleter = null;
    await _closeSocket();
    _publish(AgentConnectionSnapshot.initial);
  }

  void _handleMessage(int generation, dynamic data) {
    if (generation != _generation || data is! String) return;

    final Map<String, dynamic> message;
    try {
      final decoded = jsonDecode(data);
      if (decoded is! Map<String, dynamic>) return;
      message = decoded;
    } on FormatException {
      _publish(
        const AgentConnectionSnapshot(
          status: AgentConnectionStatus.error,
          statusMessage: 'O agente enviou uma mensagem inválida.',
        ),
      );
      return;
    }

    switch (message['type']) {
      case 'auth_ok':
        final receivedCapabilities = message['capabilities'];
        _publish(
          AgentConnectionSnapshot(
            status: AgentConnectionStatus.online,
            machineName: message['machine_name'] as String?,
            capabilities: receivedCapabilities is List
                ? receivedCapabilities.whereType<String>().toList()
                : const [],
          ),
        );
        final completer = _authenticationCompleter;
        if (completer != null && !completer.isCompleted) completer.complete();
        _authenticationCompleter = null;
        break;
      case 'auth_error':
        final reason =
            message['error'] as String? ?? 'Token recusado pelo agente.';
        _publish(
          AgentConnectionSnapshot(
            status: AgentConnectionStatus.error,
            statusMessage: reason,
          ),
        );
        final completer = _authenticationCompleter;
        if (completer != null && !completer.isCompleted) {
          completer.completeError(StateError(reason));
        }
        _authenticationCompleter = null;
        break;
      case 'metrics_update':
        final payload = _mapPayload(message['payload']);
        if (payload == null) {
          _publishMetricsFailure(
            const FormatException(
              'O agente enviou métricas em formato inválido.',
            ),
          );
          break;
        }
        try {
          final sample = AgentMetricsModel.fromJson(payload)
              .toEntity(DateTime.now());
          _publish(
            AgentConnectionSnapshot(
              status: _snapshot.status,
              statusMessage: _snapshot.statusMessage,
              machineName: _snapshot.machineName,
              capabilities: _snapshot.capabilities,
              latestMetrics: sample,
              latestMediaState: _snapshot.latestMediaState,
            ),
          );
        } on FormatException catch (error) {
          _publishMetricsFailure(error);
        }
        break;
      case 'metrics_error':
        final payload = _mapPayload(message['payload']) ?? const {};
        _publish(
          AgentConnectionSnapshot(
            status: _snapshot.status,
            statusMessage: _snapshot.statusMessage,
            machineName: _snapshot.machineName,
            capabilities: _snapshot.capabilities,
            latestMetrics: _snapshot.latestMetrics,
            metricsFailure: MetricsCollectionFailureModel.fromJson(
              payload,
              DateTime.now(),
            ),
            latestMediaState: _snapshot.latestMediaState,
          ),
        );
        break;
      case 'media_state':
        _publish(
          AgentConnectionSnapshot(
            status: _snapshot.status,
            statusMessage: _snapshot.statusMessage,
            machineName: _snapshot.machineName,
            capabilities: _snapshot.capabilities,
            latestMetrics: _snapshot.latestMetrics,
            metricsFailure: _snapshot.metricsFailure,
            latestMediaState: AgentMediaStateModel.fromJson(
              _mapPayload(message['payload']),
              envelopeStatus: message['status'],
            ).toEntity(),
          ),
        );
        break;
      case 'command_error':
        _resolveCommandError(message);
        break;
      case 'command_ack':
        _resolveCommandAck(message);
        break;
    }
  }

  void _handleSocketError(int generation, Object error) {
    if (generation != _generation) return;
    _resolvePendingOnDisconnect(_friendlyConnectionError(error));
    final completer = _authenticationCompleter;
    if (completer != null && !completer.isCompleted) {
      completer.completeError(error);
    }
    _publish(
      AgentConnectionSnapshot(
        status: AgentConnectionStatus.error,
        statusMessage: _friendlyConnectionError(error),
      ),
    );
  }

  void _handleSocketDone(int generation) {
    if (generation != _generation) return;
    _resolvePendingOnDisconnect(
      'A conexão com o agente foi encerrada antes da confirmação.',
    );
    _socket = null;
    _subscription = null;
    final completer = _authenticationCompleter;
    if (completer != null && !completer.isCompleted) {
      completer.completeError(
        StateError('O agente encerrou a conexão antes de autenticar.'),
      );
    }
    _authenticationCompleter = null;
    if (_snapshot.status != AgentConnectionStatus.error) {
      _publish(
        const AgentConnectionSnapshot(
          status: AgentConnectionStatus.disconnected,
          statusMessage: 'A conexão com o agente foi encerrada.',
        ),
      );
    }
  }

  void _resolveCommandAck(Map<String, dynamic> message) {
    final requestId = message['id'];
    if (requestId is! String) return;
    final pending = _pendingCommands.remove(requestId);
    if (pending == null || pending.completer.isCompleted) return;
    pending.completer.complete(
      AgentCommandResult.accepted(requestId: requestId),
    );
  }

  void _resolveCommandError(Map<String, dynamic> message) {
    final requestId = message['id'];
    if (requestId is! String) {
      _failPendingCommands(
        AgentCommandFailure.agentRejected,
        message['error'] as String? ?? 'O agente rejeitou o comando.',
      );
      return;
    }
    final pending = _pendingCommands.remove(requestId);
    if (pending == null || pending.completer.isCompleted) return;
    pending.completer.complete(
      AgentCommandResult.rejected(
        requestId: requestId,
        failure: AgentCommandFailure.agentRejected,
        message: message['error'] as String? ?? 'O agente rejeitou o comando.',
      ),
    );
  }

  void _failPendingCommands(AgentCommandFailure failure, String message) {
    final pending = _pendingCommands.entries.toList(growable: false);
    _pendingCommands.clear();
    for (final entry in pending) {
      if (entry.value.completer.isCompleted) continue;
      entry.value.completer.complete(
        AgentCommandResult.rejected(
          requestId: entry.key,
          failure: failure,
          message: message,
        ),
      );
    }
  }

  void _resolvePendingOnDisconnect(String message) {
    final pending = _pendingCommands.entries.toList(growable: false);
    _pendingCommands.clear();
    for (final entry in pending) {
      final request = entry.value;
      if (request.completer.isCompleted) continue;
      if (request.mayDisconnectAgent) {
        request.completer.complete(
          AgentCommandResult.transitionUnconfirmed(
            requestId: entry.key,
            message: _transitionUnconfirmedMessage,
          ),
        );
      } else {
        request.completer.complete(
          AgentCommandResult.rejected(
            requestId: entry.key,
            failure: AgentCommandFailure.transport,
            message: message,
          ),
        );
      }
    }
  }

  Future<void> _closeSocket() async {
    final subscription = _subscription;
    _subscription = null;
    await subscription?.cancel();
    final socket = _socket;
    _socket = null;
    await socket?.sink.close();
  }

  void _publish(AgentConnectionSnapshot snapshot) {
    _snapshot = snapshot;
    if (!_updates.isClosed) _updates.add(snapshot);
  }

  Map<String, dynamic>? _mapPayload(Object? payload) {
    if (payload is Map<String, dynamic>) return payload;
    if (payload is Map) return Map<String, dynamic>.from(payload);
    return null;
  }

  void _publishMetricsFailure(Object error) {
    _publish(
      AgentConnectionSnapshot(
        status: _snapshot.status,
        statusMessage: _snapshot.statusMessage,
        machineName: _snapshot.machineName,
        capabilities: _snapshot.capabilities,
        latestMetrics: _snapshot.latestMetrics,
        metricsFailure: MetricsCollectionFailure(
          capturedAt: DateTime.now(),
          failures: [
            MetricSourceFailure(source: 'collector', message: error.toString()),
          ],
        ),
        latestMediaState: _snapshot.latestMediaState,
      ),
    );
  }

  String _friendlyConnectionError(Object error) {
    if (error is TimeoutException) {
      return 'O agente não respondeu dentro do tempo esperado.';
    }
    if (error is StateError) return error.message.toString();
    return 'Não foi possível conectar ao agente. Confira o IP e a rede local.';
  }

  Future<void> dispose() async {
    _generation++;
    _resolvePendingOnDisconnect('O serviço de conexão foi encerrado.');
    _authenticationCompleter = null;
    await _subscription?.cancel();
    await _socket?.sink.close();
    _subscription = null;
    _socket = null;
    await _updates.close();
  }
}

const _transitionUnconfirmedMessage =
    'A conexão foi encerrada durante o desligamento ou reinício. Verifique o estado da máquina; o app não consegue confirmar se a transição terminou.';

class _PendingCommand {
  const _PendingCommand({
    required this.completer,
    required this.mayDisconnectAgent,
  });

  final Completer<AgentCommandResult> completer;
  final bool mayDisconnectAgent;
}
