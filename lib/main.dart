import 'package:flutter/material.dart';

import 'screens/battery_home.dart';

void main() {
  runApp(const PhonePowerMonitor());
}

class PhonePowerMonitor extends StatefulWidget {
  const PhonePowerMonitor({super.key});

  @override
  State<PhonePowerMonitor> createState() => _PhonePowerMonitorState();
}

class _PhonePowerMonitorState extends State<PhonePowerMonitor> {
  ThemeMode _themeMode = ThemeMode.dark;
  bool _animationsEnabled = true;
  bool _useFahrenheit = false;

  void _setThemeMode(ThemeMode mode) {
    setState(() => _themeMode = mode);
  }

  ThemeData _themeFor(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF5BE7FF),
      brightness: brightness,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: isDark
          ? const Color(0xFF070A12)
          : const Color(0xFFF4F7FC),
      appBarTheme: AppBarTheme(
        backgroundColor: isDark
            ? const Color(0xFF070A12)
            : const Color(0xFFF4F7FC),
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'BatteryGuard',
      theme: _themeFor(Brightness.light),
      darkTheme: _themeFor(Brightness.dark),
      themeMode: _themeMode,
      home: BatteryHomePage(
        themeMode: _themeMode,
        animationsEnabled: _animationsEnabled,
        useFahrenheit: _useFahrenheit,
        onThemeModeChanged: _setThemeMode,
        onAnimationsChanged: (enabled) {
          setState(() => _animationsEnabled = enabled);
        },
        onTemperatureUnitChanged: (useFahrenheit) {
          setState(() => _useFahrenheit = useFahrenheit);
        },
      ),
    );
  }
}
