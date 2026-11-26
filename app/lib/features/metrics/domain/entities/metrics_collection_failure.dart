class MetricSourceFailure {
  const MetricSourceFailure({required this.source, required this.message});

  final String source;
  final String message;
}

class MetricsCollectionFailure {
  const MetricsCollectionFailure({
    required this.capturedAt,
    required this.failures,
  });

  final DateTime capturedAt;
  final List<MetricSourceFailure> failures;

  String get summary => failures
      .map((failure) => '${_sourceLabel(failure.source)}: ${failure.message}')
      .join('\n');

  String _sourceLabel(String source) => switch (source) {
    'cpu' => 'CPU',
    'memory' => 'Memória',
    'network' => 'Rede',
    _ => 'Coleta',
  };
}
