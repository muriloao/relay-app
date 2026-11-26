import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../../agent/domain/entities/agent_connection_snapshot.dart';
import '../../domain/entities/performance_sample.dart';

class PerformanceOverview extends StatelessWidget {
  const PerformanceOverview({
    required this.connection,
    required this.history,
    this.isHistoryLoading = false,
    this.historyError,
    super.key,
  });

  final AgentConnectionSnapshot connection;
  final List<PerformanceSample> history;
  final bool isHistoryLoading;
  final String? historyError;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sample =
        connection.latestMetrics ?? (history.isEmpty ? null : history.last);
    final live = connection.status == AgentConnectionStatus.online;
    final hasFailure = connection.metricsFailure != null;
    final label = hasFailure
        ? 'Falha na coleta'
        : live
        ? sample == null
              ? 'Conectado · aguardando métricas'
              : 'Atualizando em tempo real'
        : history.isEmpty
        ? 'Aguardando conexão'
        : 'Histórico local · offline';
    final indicatorColor = hasFailure
        ? theme.colorScheme.error
        : live
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurfaceVariant;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Desempenho do sistema',
                style: theme.textTheme.titleMedium,
              ),
            ),
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: indicatorColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
        if (hasFailure || historyError != null) ...[
          const SizedBox(height: 8),
          Text(
            [?connection.metricsFailure?.summary, ?historyError].join('\n'),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
        ],
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 600;
            final gap = compact ? 10.0 : 16.0;
            final halfWidth = (constraints.maxWidth - gap) / 2;
            final threeColumnWidth = (constraints.maxWidth - gap * 2) / 3;
            final cardWidth = compact ? halfWidth : threeColumnWidth;
            final cardHeight = compact ? 234.0 : 270.0;

            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                _PerformanceCard(
                  width: cardWidth,
                  height: cardHeight,
                  title: 'CPU',
                  icon: Icons.memory_outlined,
                  color: const Color(0xFF7DB596),
                  value: sample == null
                      ? '—'
                      : '${_decimal(sample.cpuPercent, 1)}%',
                  detail: 'Uso total do processador',
                  values: history.map((item) => item.cpuPercent).toList(),
                  minY: 0,
                  maxY: 100,
                  footerRight: sample == null
                      ? '—'
                      : _clockLabel(sample.capturedAt),
                ),
                _PerformanceCard(
                  width: cardWidth,
                  height: cardHeight,
                  title: 'Memória RAM',
                  icon: Icons.monitor_outlined,
                  color: const Color(0xFF88AFC6),
                  value: sample == null
                      ? '—'
                      : '${_decimal(sample.memoryPercent, 1)}%',
                  detail: sample == null
                      ? 'Uso de memória'
                      : '${_gib(sample.memoryUsedBytes)} GB de ${_gib(sample.memoryTotalBytes)} GB em uso',
                  values: history.map((item) => item.memoryPercent).toList(),
                  minY: 0,
                  maxY: 100,
                  footerRight: sample == null
                      ? '—'
                      : _clockLabel(sample.capturedAt),
                ),
                _PerformanceCard(
                  width: compact ? constraints.maxWidth : cardWidth,
                  height: cardHeight,
                  title: 'Rede',
                  icon: Icons.hub_outlined,
                  color: const Color(0xFFD0AD72),
                  value: '',
                  detail: '',
                  values: history
                      .map(
                        (item) =>
                            (item.downloadBytesPerSecond +
                                    item.uploadBytesPerSecond)
                                .toDouble(),
                      )
                      .toList(),
                  minY: 0,
                  maxY: null,
                  footerRight: sample == null
                      ? '—'
                      : _clockLabel(sample.capturedAt),
                  networkSample: sample,
                ),
              ],
            );
          },
        ),
        if (isHistoryLoading) ...[
          const SizedBox(height: 10),
          const LinearProgressIndicator(minHeight: 2),
        ],
      ],
    );
  }
}

class _PerformanceCard extends StatelessWidget {
  const _PerformanceCard({
    required this.width,
    required this.height,
    required this.title,
    required this.icon,
    required this.color,
    required this.value,
    required this.detail,
    required this.values,
    required this.minY,
    required this.maxY,
    required this.footerRight,
    this.networkSample,
  });

  final double width;
  final double height;
  final String title;
  final IconData icon;
  final Color color;
  final String value;
  final String detail;
  final List<double> values;
  final double minY;
  final double? maxY;
  final String footerRight;
  final PerformanceSample? networkSample;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final network = networkSample != null;
    return SizedBox(
      width: width,
      height: height,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF141414),
          border: Border.all(color: const Color(0xFF2D2D2F)),
          borderRadius: BorderRadius.circular(8),
        ),
        padding: const EdgeInsets.fromLTRB(18, 17, 18, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                Icon(icon, size: 19, color: theme.colorScheme.onSurfaceVariant),
              ],
            ),
            if (network)
              _NetworkReadout(sample: networkSample!)
            else ...[
              const SizedBox(height: 24),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.headlineLarge?.copyWith(
                  fontSize: width < 180 ? 28 : 36,
                  fontWeight: FontWeight.w400,
                  height: 1,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(height: 9),
              Text(
                detail,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const Spacer(),
            SizedBox(
              height: 54,
              width: double.infinity,
              child: CustomPaint(
                painter: _SparklinePainter(
                  values: values,
                  color: color,
                  minY: minY,
                  maxY: maxY,
                  gridColor: const Color(0xFF2D2D2F),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Últimos 60 segundos',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                Text(
                  footerRight,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _NetworkReadout extends StatelessWidget {
  const _NetworkReadout({required this.sample});

  final PerformanceSample sample;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Row(
        children: [
          Expanded(
            child: _NetworkRate(
              label: 'Download',
              icon: Icons.south,
              rate: sample.downloadBytesPerSecond,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _NetworkRate(
              label: 'Upload',
              icon: Icons.north,
              rate: sample.uploadBytesPerSecond,
            ),
          ),
        ],
      ),
    );
  }
}

class _NetworkRate extends StatelessWidget {
  const _NetworkRate({
    required this.label,
    required this.icon,
    required this.rate,
  });

  final String label;
  final IconData icon;
  final int rate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            '${_decimal(rate / 1000000, 1)} MB/s',
            style: theme.textTheme.titleLarge?.copyWith(
              fontSize: 25,
              fontWeight: FontWeight.w400,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Icon(icon, size: 13, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 5),
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SparklinePainter extends CustomPainter {
  const _SparklinePainter({
    required this.values,
    required this.color,
    required this.minY,
    required this.maxY,
    required this.gridColor,
  });

  final List<double> values;
  final Color color;
  final double minY;
  final double? maxY;
  final Color gridColor;

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (final fraction in const [1 / 3, 2 / 3]) {
      final y = size.height * fraction;
      const dashWidth = 4.0;
      const dashSpace = 5.0;
      for (double x = 0; x < size.width; x += dashWidth + dashSpace) {
        canvas.drawLine(
          Offset(x, y),
          Offset(math.min(x + dashWidth, size.width), y),
          gridPaint,
        );
      }
    }
    if (values.isEmpty) return;

    final rangeMax = maxY ?? math.max(1.0, values.reduce(math.max));
    final range = math.max(1.0, rangeMax - minY).toDouble();
    final points = <Offset>[];
    for (var index = 0; index < values.length; index++) {
      final x = values.length == 1
          ? size.width
          : index / (values.length - 1) * size.width;
      final normalized = ((values[index] - minY) / range).clamp(0.0, 1.0);
      final y = size.height - normalized * (size.height - 4) - 2;
      points.add(Offset(x, y));
    }

    final linePath = Path()..moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      linePath.lineTo(point.dx, point.dy);
    }
    final areaPath = Path.from(linePath)
      ..lineTo(points.last.dx, size.height)
      ..lineTo(points.first.dx, size.height)
      ..close();
    canvas.drawPath(areaPath, Paint()..color = color.withValues(alpha: .08));
    canvas.drawPath(
      linePath,
      Paint()
        ..color = color
        ..strokeWidth = 1.6
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter oldDelegate) =>
      oldDelegate.values != values ||
      oldDelegate.color != color ||
      oldDelegate.maxY != maxY ||
      oldDelegate.minY != minY;
}

String _decimal(num value, int digits) =>
    value.toStringAsFixed(digits).replaceAll('.', ',');

String _gib(int bytes) => _decimal(bytes / (1024 * 1024 * 1024), 1);

String _clockLabel(DateTime value) =>
    '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}:${value.second.toString().padLeft(2, '0')}';
