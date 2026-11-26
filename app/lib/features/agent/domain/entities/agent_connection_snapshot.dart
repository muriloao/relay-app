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
  final Map<String, dynamic>? latestMetrics;
  final Map<String, dynamic>? metricsFailure;
  final Map<String, dynamic>? latestMediaState;

  static const initial = AgentConnectionSnapshot(
    status: AgentConnectionStatus.disconnected,
  );
}
