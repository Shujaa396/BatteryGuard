import 'dart:math' as math;

import 'package:flutter/material.dart';

class BatteryIndicator extends StatefulWidget {
  const BatteryIndicator({
    super.key,
    required this.batteryLevel,
    required this.stateLabel,
    required this.accentColor,
    required this.isCharging,
    required this.animationsEnabled,
  });

  final int? batteryLevel;
  final String stateLabel;
  final Color accentColor;
  final bool isCharging;
  final bool animationsEnabled;

  @override
  State<BatteryIndicator> createState() => _BatteryIndicatorState();
}

class _BatteryIndicatorState extends State<BatteryIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    _syncPulse();
  }

  @override
  void didUpdateWidget(covariant BatteryIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isCharging != widget.isCharging ||
        oldWidget.animationsEnabled != widget.animationsEnabled) {
      _syncPulse();
    }
  }

  void _syncPulse() {
    if (widget.isCharging && widget.animationsEnabled) {
      if (!_pulseController.isAnimating) {
        _pulseController.repeat(reverse: true);
      }
    } else if (_pulseController.isAnimating) {
      _pulseController
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final level = widget.batteryLevel;
    final progress = level == null ? 0.0 : level.clamp(0, 100) / 100;

    return Semantics(
      container: true,
      label: level == null ? 'Battery level unavailable' : 'Battery at $level%',
      child: SizedBox(
        width: 300,
        height: 300,
        child: AnimatedBuilder(
          animation: _pulseController,
          builder: (context, child) {
            final pulse = widget.isCharging && widget.animationsEnabled
                ? _pulseController.value
                : 0.0;

            return Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 278,
                  height: 278,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        widget.accentColor.withValues(
                          alpha: 0.12 + pulse * 0.08,
                        ),
                        const Color(0xFF597BFF).withValues(alpha: 0.04),
                        Colors.transparent,
                      ],
                      stops: const [0.42, 0.72, 1],
                    ),
                  ),
                ),
                TweenAnimationBuilder<double>(
                  tween: Tween<double>(end: progress),
                  duration: widget.animationsEnabled
                      ? const Duration(milliseconds: 1000)
                      : Duration.zero,
                  curve: Curves.easeOutCubic,
                  builder: (context, animatedProgress, child) {
                    return CustomPaint(
                      size: const Size.square(258),
                      painter: BatteryRingPainter(
                        progress: animatedProgress,
                        pulse: pulse,
                        accentColor: widget.accentColor,
                        trackColor: colors.outlineVariant,
                      ),
                    );
                  },
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedSwitcher(
                      duration: widget.animationsEnabled
                          ? const Duration(milliseconds: 260)
                          : Duration.zero,
                      child: Icon(
                        widget.isCharging
                            ? Icons.bolt_rounded
                            : Icons.battery_full_rounded,
                        key: ValueKey<bool>(widget.isCharging),
                        color: widget.accentColor,
                        size: 30,
                      ),
                    ),
                    const SizedBox(height: 4),
                    TweenAnimationBuilder<double>(
                      tween: Tween<double>(end: level?.toDouble() ?? 0),
                      duration: widget.animationsEnabled
                          ? const Duration(milliseconds: 850)
                          : Duration.zero,
                      curve: Curves.easeOutCubic,
                      builder: (context, animatedLevel, child) {
                        return Text(
                          level == null ? '—' : '${animatedLevel.round()}%',
                          style: Theme.of(context).textTheme.displayMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w700,
                                letterSpacing: -2.2,
                                height: 1.05,
                              ),
                        );
                      },
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'BATTERY LEVEL',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: colors.onSurfaceVariant,
                        letterSpacing: 2,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 14),
                    AnimatedSwitcher(
                      duration: widget.animationsEnabled
                          ? const Duration(milliseconds: 220)
                          : Duration.zero,
                      child: Container(
                        key: ValueKey<String>(widget.stateLabel),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 13,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: widget.accentColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(
                            color: widget.accentColor.withValues(alpha: 0.24),
                          ),
                        ),
                        child: Text(
                          widget.stateLabel,
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(
                                color: widget.accentColor,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class BatteryRingPainter extends CustomPainter {
  const BatteryRingPainter({
    required this.progress,
    required this.pulse,
    required this.accentColor,
    required this.trackColor,
  });

  final double progress;
  final double pulse;
  final Color accentColor;
  final Color trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 18;
    final rect = Rect.fromCircle(center: center, radius: radius);
    const startAngle = -math.pi / 2;
    final sweepAngle = 2 * math.pi * progress.clamp(0.0, 1.0);

    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..color = trackColor.withValues(alpha: 0.24);
    canvas.drawArc(rect, 0, 2 * math.pi, false, trackPaint);

    if (sweepAngle <= 0) return;

    final shader = const SweepGradient(
      startAngle: -math.pi / 2,
      endAngle: 3 * math.pi / 2,
      colors: [
        Color(0xFF5BE7FF),
        Color(0xFF478DFF),
        Color(0xFFAA7BFF),
        Color(0xFF5BE7FF),
      ],
    ).createShader(rect);

    final glowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 22
      ..strokeCap = StrokeCap.round
      ..color = accentColor.withValues(alpha: 0.13 + pulse * 0.08);
    canvas.drawArc(rect, startAngle, sweepAngle, false, glowPaint);

    final progressPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round
      ..shader = shader;
    canvas.drawArc(rect, startAngle, sweepAngle, false, progressPaint);

    final endAngle = startAngle + sweepAngle;
    final endPoint = Offset(
      center.dx + radius * math.cos(endAngle),
      center.dy + radius * math.sin(endAngle),
    );
    canvas.drawCircle(
      endPoint,
      7 + pulse,
      Paint()..color = accentColor.withValues(alpha: 0.18 + pulse * 0.08),
    );
    canvas.drawCircle(endPoint, 3.5, Paint()..color = accentColor);
  }

  @override
  bool shouldRepaint(covariant BatteryRingPainter oldDelegate) {
    return progress != oldDelegate.progress ||
        pulse != oldDelegate.pulse ||
        accentColor != oldDelegate.accentColor ||
        trackColor != oldDelegate.trackColor;
  }
}
