import 'package:flutter/material.dart';

import 'core/vpn_controller.dart';
import 'theme.dart';
import 'screens/home_screen.dart';
import 'screens/logs_screen.dart';
import 'screens/servers_screen.dart';
import 'screens/settings_screen.dart';


class VpnSoprApp extends StatelessWidget {
  const VpnSoprApp({super.key, required this.controller});

  final VpnController controller;

  @override
  Widget build(BuildContext context) {
    final base = ThemeData.dark(useMaterial3: true);
    return MaterialApp(
      title: 'TUN VPNSOPR',
      debugShowCheckedModeBanner: false,
      theme: base.copyWith(
        scaffoldBackgroundColor: navy,
        colorScheme: base.colorScheme.copyWith(
          primary: neonBlue,
          secondary: neonCyan,
          surface: panel,
          error: const Color(0xFFFF667A),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          centerTitle: false,
          elevation: 0,
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: const Color(0xFF071225),
          indicatorColor: neonBlue.withValues(alpha: 0.16),
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            return TextStyle(
              color: states.contains(WidgetState.selected) ? neonCyan : mutedText,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            );
          }),
          iconTheme: WidgetStateProperty.resolveWith((states) {
            return IconThemeData(
              color: states.contains(WidgetState.selected) ? neonCyan : mutedText,
            );
          }),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF0C1B31),
          hintStyle: const TextStyle(color: mutedText),
          labelStyle: const TextStyle(color: mutedText),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: neonBlue.withValues(alpha: 0.20)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: neonBlue.withValues(alpha: 0.16)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: neonBlue, width: 1.4),
          ),
        ),
        snackBarTheme: const SnackBarThemeData(
          backgroundColor: Color(0xFF102541),
          contentTextStyle: TextStyle(color: Colors.white),
        ),
      ),
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: MainShell(controller: controller),
      ),
    );
  }
}

class MainShell extends StatefulWidget {
  const MainShell({super.key, required this.controller});
  final VpnController controller;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      HomeScreen(controller: widget.controller),
      ServersScreen(controller: widget.controller),
      LogsScreen(controller: widget.controller),
      SettingsScreen(controller: widget.controller),
    ];

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: IndexedStack(index: _selectedIndex, children: pages),
      ),
      bottomNavigationBar: NavigationBar(
        height: 68,
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) => setState(() => _selectedIndex = index),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.shield_outlined), selectedIcon: Icon(Icons.shield), label: 'خانه'),
          NavigationDestination(icon: Icon(Icons.dns_outlined), selectedIcon: Icon(Icons.dns), label: 'سرورها'),
          NavigationDestination(icon: Icon(Icons.terminal_outlined), selectedIcon: Icon(Icons.terminal), label: 'گزارش‌ها'),
          NavigationDestination(icon: Icon(Icons.tune_outlined), selectedIcon: Icon(Icons.tune), label: 'تنظیمات'),
        ],
      ),
    );
  }
}
