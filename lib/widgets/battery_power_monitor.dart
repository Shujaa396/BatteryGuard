import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/battery_power_record.dart';
import '../services/device_battery_details.dart';

class BatteryPowerMonitor extends StatefulWidget {
  const BatteryPowerMonitor({
    super.key,
    required this.details,
    required this.animationsEnabled,
  });

  final DeviceBatteryDetails? details;
  final bool animationsEnabled;

  @override
  State<BatteryPowerMonitor> createState() => _BatteryPowerMonitorState();
}

class _BatteryPowerMonitorState extends State<BatteryPowerMonitor>
    with SingleTickerProviderStateMixin {
  late final AnimationController _flowController;
  double _previousWatts = 0;
  bool _hasAnimatedReading = false;

  @override
  void initState() {
    super.initState();
    _flowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1250),
    );
    _syncFlow();
  }

  @override
  void didUpdateWidget(covariant BatteryPowerMonitor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.animationsEnabled != widget.animationsEnabled ||
        oldWidget.details?.powerDirection != widget.details?.powerDirection ||
        oldWidget.details?.powerWatts != widget.details?.powerWatts) {
      _syncFlow();
    }
  }

  void _syncFlow() {
    final details = widget.details;
    final direction = details?.powerDirection;
    final watts = details?.powerWatts;
    final shouldAnimate =
        widget.animationsEnabled &&
        watts != null &&
        watts > 0 &&
        (direction == BatteryPowerDirection.charging ||
            direction == BatteryPowerDirection.discharging);
    if (shouldAnimate) {
      if (!_flowController.isAnimating) _flowController.repeat();
    } else if (_flowController.isAnimating) {
      _flowController
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _flowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final details = widget.details;
    final direction =
        details?.powerDirection ?? BatteryPowerDirection.unavailable;
    final watts = details?.powerWatts;
    final accent = _accentFor(direction);
    final label = _labelFor(direction);
    final canShowPower =
        watts != null &&
        (direction == BatteryPowerDirection.charging ||
            direction == BatteryPowerDirection.discharging);

    return Semantics(
      container: true,
      label: canShowPower
          ? '$label, ${watts.toStringAsFixed(2)} watts, battery-side power'
          : '$label, power unavailable',
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: direction == BatteryPowerDirection.discharging
                ? [
                    colors.surface.withValues(alpha: 0.97),
                    accent.withValues(alpha: 0.12),
                    const Color(0xFFFFB86B).withValues(alpha: 0.05),
                  ]
                : [
                    colors.surface.withValues(alpha: 0.97),
                    accent.withValues(alpha: 0.12),
                  ],
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: accent.withValues(alpha: 0.28)),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: 0.08),
              blurRadius: 22,
              offset: const Offset(0, 9),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.13),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(_iconFor(direction), color: accent, size: 23),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(
                              color: accent,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.15,
                            ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _subtitleFor(direction),
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(color: colors.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 13),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Expanded(
                  child: canShowPower
                      ? TweenAnimationBuilder<double>(
                          key: ValueKey<String>(
                            '${direction.name}:${watts.toStringAsFixed(3)}',
                          ),
                          tween: Tween<double>(
                            begin: _hasAnimatedReading ? _previousWatts : watts,
                            end: watts,
                          ),
                          duration: widget.animationsEnabled
                              ? const Duration(milliseconds: 600)
                              : Duration.zero,
                          curve: Curves.easeOutCubic,
                          onEnd: () {
                            _previousWatts = watts;
                            _hasAnimatedReading = true;
                          },
                          builder: (context, value, child) => Text(
                            value.toStringAsFixed(2),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.displaySmall
                                ?.copyWith(
                                  color: accent,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -1.4,
                                ),
                          ),
                        )
                      : Text(
                          direction == BatteryPowerDirection.idle
                              ? '—'
                              : 'Unavailable',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.headlineMedium
                              ?.copyWith(
                                color: colors.onSurfaceVariant,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                ),
                const SizedBox(width: 8),
                Text(
                  'W',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: colors.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 11),
            SizedBox(
              height: 30,
              child: AnimatedBuilder(
                animation: _flowController,
                builder: (context, child) {
                  return CustomPaint(
                    painter: _PowerFlowPainter(
                      progress: _flowController.value,
                      direction: direction,
                      color: accent,
                      animated: widget.animationsEnabled && canShowPower,
                    ),
                    child: child,
                  );
                },
                child: const SizedBox.expand(),
              ),
            ),
            const SizedBox(height: 11),
            Row(
              children: [
                Expanded(
                  child: _ReadingValue(
                    label: 'VOLTAGE',
                    value: _formatVoltage(details?.voltageVolts),
                    icon: Icons.electric_bolt_outlined,
                    color: accent,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ReadingValue(
                    label: 'CURRENT',
                    value: _formatCurrent(details?.currentMilliamps),
                    icon: Icons.bolt_rounded,
                    color: accent,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 11),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Battery-side measurement · not wall-charger watts',
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: colors.onSurfaceVariant),
                  ),
                ),
                if (details != null)
                  Text(
                    _formatTime(details.updatedAt),
                    style: Theme.of(context).textTheme.labelSmall
                        ?.copyWith(color: colors.onSurfaceVariant),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _accentFor(BatteryPowerDirection direction) {
    return switch (direction) {
      BatteryPowerDirection.charging => const Color(0xFF5BE7FF),
      BatteryPowerDirection.discharging => const Color(0xFFB18AFF),
      BatteryPowerDirection.idle => const Color(0xFF68E3B1),
      BatteryPowerDirection.unavailable => const Color(0xFF91A0B7),
    };
  }

  String _labelFor(BatteryPowerDirection direction) {
    return switch (direction) {
      BatteryPowerDirection.charging => 'LIVE POWER IN',
      BatteryPowerDirection.discharging => 'LIVE POWER OUT',
      BatteryPowerDirection.idle => 'NO ACTIVE BATTERY FLOW',
      BatteryPowerDirection.unavailable => 'POWER FLOW UNAVAILABLE',
    };
  }

  String _subtitleFor(BatteryPowerDirection direction) {
    return switch (direction) {
      BatteryPowerDirection.charging => 'Electrical power entering the battery',
      BatteryPowerDirection.discharging =>
        'Electrical power delivered by the battery',
      BatteryPowerDirection.idle => 'Battery is full or not actively charging',
      BatteryPowerDirection.unavailable =>
        'Android has not reported a reliable flow direction',
    };
  }

  IconData _iconFor(BatteryPowerDirection direction) {
    return switch (direction) {
      BatteryPowerDirection.charging => Icons.south_east_rounded,
      BatteryPowerDirection.discharging => Icons.north_west_rounded,
      BatteryPowerDirection.idle => Icons.battery_full_rounded,
      BatteryPowerDirection.unavailable => Icons.electric_bolt_outlined,
    };
  }

  String _formatVoltage(double? value) =>
      value == null ? 'Unavailable' : '${value.toStringAsFixed(2)} V';

  String _formatCurrent(double? value) =>
      value == null ? 'Unavailable' : '${value.round()} mA';

  String _formatTime(DateTime time) {
    final local = time.toLocal();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    final second = local.second.toString().padLeft(2, '0');
    return '$hour:$minute:$second';
  }
}

class _ReadingValue extends StatelessWidget {
  const _ReadingValue({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
      decoration: BoxDecoration(
        color: colors.surface.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: color.withValues(alpha: 0.13)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 17, color: color),
          const SizedBox(width: 7),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: colors.onSurfaceVariant,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class BatteryPowerHistoryCard extends StatelessWidget {
  const BatteryPowerHistoryCard({
    super.key,
    required this.records,
    required this.historyUnavailable,
    required this.onRetry,
  });

  final List<BatteryPowerRecord> records;
  final bool historyUnavailable;
  final VoidCallback onRetry;

  static const int _visibleSamples = 240;
  static const Color _inColor = Color(0xFF5BE7FF);
  static const Color _outColor = Color(0xFFB18AFF);

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final recent = records.length > _visibleSamples
        ? records.sublist(records.length - _visibleSamples)
        : records;
    final charging = BatteryPowerStatistics.fromRecords(
      recent,
      BatteryPowerDirection.charging,
    );
    final discharging = BatteryPowerStatistics.fromRecords(
      recent,
      BatteryPowerDirection.discharging,
    );

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.surface.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: colors.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.show_chart_rounded, color: _inColor),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  'Live power history',
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              Text(
                '${recent.length} samples',
                style: Theme.of(context).textTheme.labelSmall
                    ?.copyWith(color: colors.onSurfaceVariant),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Battery-side power readings stored on this device.',
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: colors.onSurfaceVariant),
          ),
          const SizedBox(height: 13),
          if (historyUnavailable)
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Local power history is unavailable.',
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: colors.onSurfaceVariant),
                  ),
                ),
                TextButton(onPressed: onRetry, child: const Text('Retry')),
              ],
            )
          else if (recent.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 18),
              child: Center(
                child: Text(
                  'Waiting for reliable voltage and current readings.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium
                      ?.copyWith(color: colors.onSurfaceVariant),
                ),
              ),
            )
          else ...[
            SizedBox(
              height: 128,
              width: double.infinity,
              child: CustomPaint(
                painter: _BatteryPowerHistoryPainter(
                  records: recent,
                  gridColor: colors.outlineVariant.withValues(alpha: 0.4),
                ),
              ),
            ),
            const SizedBox(height: 11),
            _StatisticsLine(
              title: 'POWER IN',
              statistics: charging,
              color: _inColor,
            ),
            const SizedBox(height: 8),
            _StatisticsLine(
              title: 'POWER OUT',
              statistics: discharging,
              color: _outColor,
            ),
          ],
        ],
      ),
    );
  }
}

class _StatisticsLine extends StatelessWidget {
  const _StatisticsLine({
    required this.title,
    required this.statistics,
    required this.color,
  });

  final String title;
  final BatteryPowerStatistics statistics;
  final Color color;

  @override
  Widget build(BuildContext context) {
    String format(double? value) =>
        value == null ? '—' : '${value.toStringAsFixed(2)} W';

    return Row(
      children: [
        SizedBox(
          width: 72,
          child: Text(
            title,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
            ),
          ),
        ),
        Expanded(
          child: Text(
            'Min ${format(statistics.minimumWatts)}  ·  '
            'Avg ${format(statistics.averageWatts)}  ·  '
            'Max ${format(statistics.maximumWatts)}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

class _BatteryPowerHistoryPainter extends CustomPainter {
  const _BatteryPowerHistoryPainter({
    required this.records,
    required this.gridColor,
  });

  final List<BatteryPowerRecord> records;
  final Color gridColor;

  @override
  void paint(Canvas canvas, Size size) {
    const inset = 8.0;
    final plot = Rect.fromLTRB(
      inset,
      inset,
      size.width - inset,
      size.height - inset,
    );
    final grid = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (var index = 0; index < 3; index++) {
      final y = plot.top + plot.height * index / 2;
      canvas.drawLine(Offset(plot.left, y), Offset(plot.right, y), grid);
    }
    if (records.isEmpty) return;

    final minimum = records
        .map((record) => record.powerWatts)
        .reduce((a, b) => a < b ? a : b);
    final maximum = records
        .map((record) => record.powerWatts)
        .reduce((a, b) => a > b ? a : b);
    final range = math.max(maximum - minimum, 0.05);
    final points = List<Offset>.generate(records.length, (index) {
      final x = records.length == 1
          ? plot.center.dx
          : plot.left + plot.width * index / (records.length - 1);
      final y =
          plot.bottom -
          (records[index].powerWatts - minimum) / range * plot.height;
      return Offset(x, y);
    }, growable: false);

    if (points.length == 1) {
      canvas.drawCircle(
        points.single,
        3.5,
        Paint()..color = _colorFor(records.single.direction),
      );
      return;
    }

    for (var index = 0; index < points.length - 1; index++) {
      canvas.drawLine(
        points[index],
        points[index + 1],
        Paint()
          ..color = _colorFor(records[index + 1].direction)
          ..strokeWidth = 2.5
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  Color _colorFor(BatteryPowerDirection direction) {
    return direction == BatteryPowerDirection.charging
        ? const Color(0xFF5BE7FF)
        : const Color(0xFFB18AFF);
  }

  @override
  bool shouldRepaint(covariant _BatteryPowerHistoryPainter oldDelegate) =>
      oldDelegate.records != records || oldDelegate.gridColor != gridColor;
}

class _PowerFlowPainter extends CustomPainter {
  const _PowerFlowPainter({
    required this.progress,
    required this.direction,
    required this.color,
    required this.animated,
  });

  final double progress;
  final BatteryPowerDirection direction;
  final Color color;
  final bool animated;

  @override
  void paint(Canvas canvas, Size size) {
    final centerY = size.height / 2;
    final left = 5.0;
    final right = size.width - 5;
    final isCharging = direction == BatteryPowerDirection.charging;
    final active = isCharging || direction == BatteryPowerDirection.discharging;
    final trackPaint = Paint()
      ..color = color.withValues(alpha: 0.2)
      ..strokeWidth = 2;
    canvas.drawLine(Offset(left, centerY), Offset(right, centerY), trackPaint);
    if (!active) return;

    final arrowX = isCharging ? right : left;
    final arrowDirection = isCharging ? 1.0 : -1.0;
    final arrowPaint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(arrowX - arrowDirection * 5, centerY - 5),
      Offset(arrowX, centerY),
      arrowPaint,
    );
    canvas.drawLine(
      Offset(arrowX - arrowDirection * 5, centerY + 5),
      Offset(arrowX, centerY),
      arrowPaint,
    );

    if (!animated) return;
    for (var index = 0; index < 5; index++) {
      final phase = (progress + index / 5) % 1;
      final position = isCharging ? phase : 1 - phase;
      final x = left + (right - left) * position;
      final particleColor = isCharging
          ? color
          : Color.lerp(color, const Color(0xFFFFB86B), index / 4) ?? color;
      canvas.drawCircle(
        Offset(x, centerY),
        2 + (index % 2).toDouble(),
        Paint()
          ..color = particleColor.withValues(alpha: 0.4 + (index % 3) * 0.2),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _PowerFlowPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.direction != direction ||
      oldDelegate.color != color ||
      oldDelegate.animated != animated;
}
