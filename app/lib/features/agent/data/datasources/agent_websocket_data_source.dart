import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../../machines/domain/entities/machine_profile.dart';
import '../../domain/entities/agent_connection_snapshot.dart';
import '../../domain/repositories/agent_gateway.dart';

class AgentWebSocketDataSource implements AgentGateway {
  WebSocket? _socket;
  StreamSubscription<dynamic>? _subscription;
  Completer<void>? _authenticationCompleter;
  int _generation = 0;
  AgentConnectionSnapshot _snapshot = AgentConnectionSnapshot.initial;
  final StreamController<AgentConnectionSnapshot> _updates =
      StreamController<AgentConnectionSnapshot>.broadcast();

  @override
  AgentConnectionSnapshot get snapshot => _snapshot;

  @override
  Stream<AgentConnectionSnapshot> get updates => _updates.stream;

  @override
  Future<void> connect(MachineProfile profile, String token) async {
    final generation = ++_generation;
    await _closeSocket();
    if (generation != _generation) return;

    _publish(
      const AgentConnectionSnapshot(status: AgentConnectionStatus.connecting),
    );

    try {
      final socket = await WebSocket.connect(
        Uri(
          scheme: 'ws',
          host: profile.host,
          port: profile.port,
          path: '/ws',
        ).toString(),
      ).timeout(const Duration(seconds: 8));

      if (generation != _generation) {
        await socket.close();
        return;
      }

      _socket = socket;
      socket.pingInterval = const Duration(seconds: 20);
      final authCompleter = Completer<void>();
      _authenticationCompleter = authCompleter;
      _publish(
        const AgentConnectionSnapshot(
          status: AgentConnectionStatus.authenticating,
        ),
      );
      _subscription = socket.listen(
        (data) => _handleMessage(generation, data),
        onError: (Object error, StackTrace stackTrace) {
          _handleSocketError(generation, error);
        },
        onDone: () => _handleSocketDone(generation),
      );
      socket.add(jsonEncode({'type': 'auth', 'token': token}));
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
  Future<void> disconnect() async {
    _generation++;
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
        _publish(
          AgentConnectionSnapshot(
            status: _snapshot.status,
            statusMessage: _snapshot.statusMessage,
            machineName: _snapshot.machineName,
            capabilities: _snapshot.capabilities,
            latestMetrics: _mapPayload(message['payload']),
            latestMediaState: _snapshot.latestMediaState,
          ),
        );
        break;
      case 'metrics_error':
        _publish(
          AgentConnectionSnapshot(
            status: _snapshot.status,
            statusMessage: _snapshot.statusMessage,
            machineName: _snapshot.machineName,
            capabilities: _snapshot.capabilities,
            latestMetrics: _snapshot.latestMetrics,
            metricsFailure: _mapPayload(message['payload']),
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
            latestMediaState: _mapPayload(message['payload']),
          ),
        );
        break;
      case 'command_error':
        _publish(
          AgentConnectionSnapshot(
            status: _snapshot.status,
            statusMessage: message['error'] as String?,
            machineName: _snapshot.machineName,
            capabilities: _snapshot.capabilities,
            latestMetrics: _snapshot.latestMetrics,
            metricsFailure: _snapshot.metricsFailure,
            latestMediaState: _snapshot.latestMediaState,
          ),
        );
        break;
    }
  }

  void _handleSocketError(int generation, Object error) {
    if (generation != _generation) return;
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

  Future<void> _closeSocket() async {
    final subscription = _subscription;
    _subscription = null;
    await subscription?.cancel();
    final socket = _socket;
    _socket = null;
    await socket?.close();
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

  String _friendlyConnectionError(Object error) {
    if (error is TimeoutException) {
      return 'O agente não respondeu dentro do tempo esperado.';
    }
    if (error is StateError) return error.message.toString();
    return 'Não foi possível conectar ao agente. Confira o IP e a rede local.';
  }

  Future<void> dispose() async {
    _generation++;
    _authenticationCompleter = null;
    await _subscription?.cancel();
    await _socket?.close();
    _subscription = null;
    _socket = null;
    await _updates.close();
  }
}
