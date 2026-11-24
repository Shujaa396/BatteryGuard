import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/battery_health_assessment.dart';
import '../models/battery_health_record.dart';
import '../services/device_battery_details.dart';

class BatteryHealthScreen extends StatelessWidget {
  const BatteryHealthScreen({
    super.key,
    required this.details,
    required this.history,
    required this.historyUnavailable,
    required this.onRetryHistory,
    required this.animationsEnabled,
  });

  final DeviceBatteryDetails? details;
  final List<BatteryHealthRecord> history;
  final bool historyUnavailable;
  final VoidCallback onRetryHistory;
  final bool animationsEnabled;

  static const Color _cyan = Color(0xFF5BE7FF);
  static const Color _green = Color(0xFF68E3B1);
  static const Color _orange = Color(0xFFFFB86B);
  static const Color _red = Color(0xFFFF657A);

  BatteryHealthAssessment get _assessment =>
      BatteryHealthAssessment.fromCapacities(
        fullChargeCapacityMah: null,
        designCapacityMah: null,
      );

  String _formatMah(double? value) =>
      value == null ? 'Unavailable' : '${value.round()} mAh';

  Color _healthColor(BatteryHealthAssessment assessment) {
    return switch (assessment.classification) {
      'Excellent' => _green,
      'Good' => _cyan,
      'Fair' => _orange,
      'Poor' => _red,
      _ => _cyan,
    };
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final assessment = _assessment;
    final accent = _healthColor(assessment);
    final temperature = details?.temperatureCelsius;
    final temperatureWarning = temperature != null && temperature >= 45;
    final healthStatus = details?.health ?? 'Unavailable';

    return LayoutBuilder(
      builder: (context, constraints) {
        final contentWidth = constraints.maxWidth.clamp(0.0, 1000.0).toDouble();
        final horizontalPadding = contentWidth >= 680 ? 32.0 : 20.0;
        final availableWidth = (contentWidth - horizontalPadding * 2).clamp(
          0.0,
          contentWidth,
        );
        final columns = availableWidth >= 650 ? 2 : 1;
        final cardWidth = (availableWidth - (columns - 1) * 14) / columns;

        return Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: contentWidth,
            child: SingleChildScrollView(
              key: const PageStorageKey<String>('battery-health-scroll'),
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                12,
                horizontalPadding,
                30,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Battery health',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.8,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'A clear picture, without guessing.',
                    style: Theme.of(context).textTheme.bodyMedium
                        ?.copyWith(color: colors.onSurfaceVariant),
                  ),
                  const SizedBox(height: 18),
                  _buildHealthHero(context, assessment, accent, healthStatus),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 14,
                    runSpacing: 14,
                    children: [
                      SizedBox(
                        width: cardWidth,
                        child: _metricCard(
                          context,
                          title: 'Remaining charge',
                          value: _formatMah(details?.remainingChargeMah),
                          subtitle: 'Android charge counter; this is charge left, not full capacity.',
                          icon: Icons.battery_5_bar_rounded,
                          color: _cyan,
                        ),
                      ),
                      SizedBox(
                        width: cardWidth,
                        child: _metricCard(
                          context,
                          title: 'Full-charge capacity',
                          value: _formatMah(assessment.fullChargeCapacityMah),
                          subtitle: 'Not exposed to this app by Android.',
                          icon: Icons.battery_full_rounded,
                          color: _green,
                        ),
                      ),
                      SizedBox(
                        width: cardWidth,
                        child: _metricCard(
                          context,
                          title: 'Design capacity',
                          value: _formatMah(assessment.designCapacityMah),
                          subtitle:
                              'No reliable original capacity is available.',
                          icon: Icons.factory_outlined,
                          color: _orange,
                        ),
                      ),
                      SizedBox(
                        width: cardWidth,
                        child: _metricCard(
                          context,
                          title: 'Cycle count',
                          value: 'Unavailable',
                          subtitle:
                              'The device does not expose this to the app.',
                          icon: Icons.replay_rounded,
                          color: const Color(0xFFB18AFF),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildInsights(
                    context,
                    assessment,
                    healthStatus,
                    temperature,
                    temperatureWarning,
                  ),
                  const SizedBox(height: 16),
                  _buildHistory(context),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHealthHero(
    BuildContext context,
    BatteryHealthAssessment assessment,
    Color accent,
    String healthStatus,
  ) {
    final colors = Theme.of(context).colorScheme;
    final percent = assessment.healthPercent;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colors.surface.withValues(alpha: 0.97),
            accent.withValues(alpha: 0.12),
          ],
        ),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: accent.withValues(alpha: 0.25)),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.08),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween<double>(
              begin: 0,
              end: percent == null ? 0 : percent.clamp(0, 100) / 100,
            ),
            duration: animationsEnabled
                ? const Duration(milliseconds: 900)
                : Duration.zero,
            curve: Curves.easeOutCubic,
            builder: (context, progress, child) {
              return SizedBox(
                width: 194,
                height: 194,
                child: CustomPaint(
                  painter: _HealthRingPainter(
                    progress: progress,
                    accent: accent,
                    track: colors.onSurface.withValues(alpha: 0.08),
                  ),
                  child: child,
                ),
              );
            },
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  percent == null ? '—' : '$percent%',
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1.5,
                    color: accent,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'BATTERY HEALTH',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: colors.onSurfaceVariant,
                    letterSpacing: 1.4,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 15),
          Text(
            percent == null
                ? 'Battery health percentage unavailable on this device.'
                : '${assessment.classification} battery health',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(color: accent, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 7),
          Text(
            'Android reports condition: $healthStatus',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: colors.onSurfaceVariant),
          ),
          if (assessment.degradationPercent != null) ...[
            const SizedBox(height: 5),
            Text(
              'Estimated degradation: ${assessment.degradationPercent}%',
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: colors.onSurfaceVariant),
            ),
          ],
        ],
      ),
    );
  }

  Widget _metricCard(
    BuildContext context, {
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      constraints: const BoxConstraints(minHeight: 150),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colors.surface.withValues(alpha: 0.96),
            color.withValues(alpha: 0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(21),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 23),
          const SizedBox(height: 13),
          Text(
            title.toUpperCase(),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: colors.onSurfaceVariant,
              letterSpacing: 1.05,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.4),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: colors.onSurfaceVariant, height: 1.3),
          ),
        ],
      ),
    );
  }

  Widget _buildInsights(
    BuildContext context,
    BatteryHealthAssessment assessment,
    String healthStatus,
    double? temperature,
    bool temperatureWarning,
  ) {
    final colors = Theme.of(context).colorScheme;
    final accent = temperatureWarning ? _red : _cyan;
    final temperatureText = temperature == null
        ? 'Battery temperature is not reported.'
        : 'Battery temperature is ${temperature.toStringAsFixed(1)} °C.';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.surface.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: accent.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                temperatureWarning
                    ? Icons.warning_amber_rounded
                    : Icons.insights_rounded,
                color: accent,
              ),
              const SizedBox(width: 9),
              Text(
                'Battery insights',
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 11),
          Text(
            assessment.healthPercent == null
                ? 'Android provides a reported condition and remaining charge, but not reliable full-charge and original design capacities to this app. Charge level or remaining charge alone cannot establish battery degradation.'
                : 'Health is calculated only from device-reported full-charge and design capacities.',
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: colors.onSurfaceVariant, height: 1.4),
          ),
          const SizedBox(height: 10),
          Text(
            temperatureWarning
                ? '$temperatureText Consider reducing heat and heavy use while charging.'
                : temperatureText,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: temperatureWarning ? _red : colors.onSurfaceVariant,
              fontWeight: temperatureWarning ? FontWeight.w700 : null,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            'Source: Android battery broadcast and BatteryManager. '
            'Condition reported: $healthStatus. '
            'No capacity percentage or degradation is inferred.',
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: colors.onSurfaceVariant, height: 1.35),
          ),
        ],
      ),
    );
  }

  Widget _buildHistory(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final samples = history
        .where((record) => record.remainingChargeMah != null)
        .toList(growable: false);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.surface.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: colors.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.show_chart_rounded, color: _cyan),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  'Battery history',
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              Text(
                '${samples.length} samples',
                style: Theme.of(context).textTheme.labelSmall
                    ?.copyWith(color: colors.onSurfaceVariant),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Remaining charge counter (mAh), not full capacity or health.',
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: colors.onSurfaceVariant),
          ),
          const SizedBox(height: 14),
          if (historyUnavailable)
            _historyUnavailable(context)
          else if (samples.length < 2)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 22),
              child: Center(
                child: Text(
                  'History is collecting. A chart appears after more charge readings are recorded.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium
                      ?.copyWith(color: colors.onSurfaceVariant),
                ),
              ),
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: 150,
                  width: double.infinity,
                  child: CustomPaint(
                    painter: _ChargeHistoryPainter(
                      values: samples
                          .map((record) => record.remainingChargeMah!)
                          .toList(growable: false),
                      lineColor: _cyan,
                      gridColor: colors.outlineVariant.withValues(alpha: 0.4),
                    ),
                  ),
                ),
                const SizedBox(height: 9),
                Text(
                  'Latest: ${_formatMah(samples.last.remainingChargeMah)} · '
                  '${_formatDate(samples.last.measuredAt)}',
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: colors.onSurfaceVariant),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _historyUnavailable(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(
          child: Text(
            'Local battery history could not be loaded.',
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: colors.onSurfaceVariant),
          ),
        ),
        TextButton(onPressed: onRetryHistory, child: const Text('Retry')),
      ],
    );
  }

  String _formatDate(DateTime date) {
    final local = date.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$month/$day $hour:$minute';
  }
}

class _HealthRingPainter extends CustomPainter {
  const _HealthRingPainter({
    required this.progress,
    required this.accent,
    required this.track,
  });

  final double progress;
  final Color accent;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 12;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final trackPaint = Paint()
      ..color = track
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12;
    canvas.drawCircle(center, radius, trackPaint);

    if (progress <= 0) return;
    final progressPaint = Paint()
      ..shader = const SweepGradient(
        colors: [Color(0xFF5BE7FF), Color(0xFF568BFF), Color(0xFFB18AFF)],
        startAngle: -math.pi / 2,
        endAngle: math.pi * 3 / 2,
      ).createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 12;
    canvas.drawArc(
      rect,
      -math.pi / 2,
      math.pi * 2 * progress,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _HealthRingPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.accent != accent ||
      oldDelegate.track != track;
}

class _ChargeHistoryPainter extends CustomPainter {
  const _ChargeHistoryPainter({
    required this.values,
    required this.lineColor,
    required this.gridColor,
  });

  final List<double> values;
  final Color lineColor;
  final Color gridColor;

  @override
  void paint(Canvas canvas, Size size) {
    const horizontalInset = 8.0;
    const verticalInset = 10.0;
    final plot = Rect.fromLTRB(
      horizontalInset,
      verticalInset,
      size.width - horizontalInset,
      size.height - verticalInset,
    );
    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (var index = 0; index < 3; index++) {
      final y = plot.top + plot.height * index / 2;
      canvas.drawLine(Offset(plot.left, y), Offset(plot.right, y), gridPaint);
    }

    if (values.length < 2) return;
    final minimum = values.reduce(math.min);
    final maximum = values.reduce(math.max);
    final range = math.max(maximum - minimum, 1.0);
    final path = Path();
    for (var index = 0; index < values.length; index++) {
      final x = plot.left + plot.width * index / (values.length - 1);
      final y = plot.bottom - (values[index] - minimum) / range * plot.height;
      if (index == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = lineColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant _ChargeHistoryPainter oldDelegate) =>
      oldDelegate.values != values ||
      oldDelegate.lineColor != lineColor ||
      oldDelegate.gridColor != gridColor;
}
