import 'package:flutter/material.dart';

class BatterySettingsSheet extends StatefulWidget {
  const BatterySettingsSheet({
    super.key,
    required this.themeMode,
    required this.animationsEnabled,
    required this.useFahrenheit,
    required this.onThemeModeChanged,
    required this.onAnimationsChanged,
    required this.onTemperatureUnitChanged,
  });

  final ThemeMode themeMode;
  final bool animationsEnabled;
  final bool useFahrenheit;
  final ValueChanged<ThemeMode> onThemeModeChanged;
  final ValueChanged<bool> onAnimationsChanged;
  final ValueChanged<bool> onTemperatureUnitChanged;

  @override
  State<BatterySettingsSheet> createState() => _BatterySettingsSheetState();
}

class _BatterySettingsSheetState extends State<BatterySettingsSheet> {
  late ThemeMode _themeMode;
  late bool _animationsEnabled;
  late bool _useFahrenheit;

  @override
  void initState() {
    super.initState();
    _themeMode = widget.themeMode;
    _animationsEnabled = widget.animationsEnabled;
    _useFahrenheit = widget.useFahrenheit;
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          border: Border.all(
            color: colors.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(22, 12, 22, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.onSurfaceVariant.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 22),
            Text(
              'Personalize BatteryGuard',
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 24),
            _sectionTitle(context, 'APPEARANCE'),
            const SizedBox(height: 10),
            SegmentedButton<ThemeMode>(
              segments: const [
                ButtonSegment(
                  value: ThemeMode.dark,
                  label: Text('Dark'),
                  icon: Icon(Icons.dark_mode_outlined),
                ),
                ButtonSegment(
                  value: ThemeMode.light,
                  label: Text('Light'),
                  icon: Icon(Icons.light_mode_outlined),
                ),
              ],
              selected: {_themeMode},
              onSelectionChanged: (selection) {
                final mode = selection.first;
                setState(() => _themeMode = mode);
                widget.onThemeModeChanged(mode);
              },
            ),
            const SizedBox(height: 24),
            _sectionTitle(context, 'EXPERIENCE'),
            Material(
              color: colors.surface,
              child: SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Subtle animations'),
                subtitle: const Text('Ring motion and card entrances'),
                value: _animationsEnabled,
                onChanged: (enabled) {
                  setState(() => _animationsEnabled = enabled);
                  widget.onAnimationsChanged(enabled);
                },
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Temperature unit',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ),
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: false, label: Text('°C')),
                    ButtonSegment(value: true, label: Text('°F')),
                  ],
                  selected: {_useFahrenheit},
                  onSelectionChanged: (selection) {
                    final useFahrenheit = selection.first;
                    setState(() => _useFahrenheit = useFahrenheit);
                    widget.onTemperatureUnitChanged(useFahrenheit);
                  },
                ),
              ],
            ),
            const SizedBox(height: 22),
            Text(
              'Battery measurements come from Android. Battery capacity is not estimated when the device does not report it.',
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: colors.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        letterSpacing: 1.5,
        fontWeight: FontWeight.w700,
        color: Theme.of(context).colorScheme.primary,
      ),
    );
  }
}
