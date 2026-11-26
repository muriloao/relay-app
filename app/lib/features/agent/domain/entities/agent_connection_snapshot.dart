import '../../../metrics/domain/entities/metrics_collection_failure.dart';
import '../../../metrics/domain/entities/performance_sample.dart';

enum AgentConnectionStatus {
  disconnected,
  connecting,
  authenticating,
  online,
  error,
}

class AgentConnectionSnapshot {
  const AgentConnectionSnapshot({
    required this.status,
    this.statusMessage,
    this.machineName,
    this.capabilities = const [],
    this.latestMetrics,
    this.metricsFailure,
    this.latestMediaState,
  });

  final AgentConnectionStatus status;
  final String? statusMessage;
  final String? machineName;
  final List<String> capabilities;
  final PerformanceSample? latestMetrics;
  final MetricsCollectionFailure? metricsFailure;
  final Map<String, dynamic>? latestMediaState;

  bool supportsPowerAction(String action) =>
      capabilities.contains('power.$action') ||
      (capabilities.contains('power') &&
          const {'lock', 'shutdown', 'restart'}.contains(action));

  static const initial = AgentConnectionSnapshot(
    status: AgentConnectionStatus.disconnected,
  );
}
