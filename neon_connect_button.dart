import 'package:flutter/material.dart';

import '../theme.dart';

class NeonConnectButton extends StatelessWidget {
  const NeonConnectButton({
    super.key,
    required this.connected,
    required this.loading,
    required this.onPressed,
  });

  final bool connected;
  final bool loading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final glow = connected ? neonCyan : neonBlue;
    return Semantics(
      button: true,
      label: connected ? 'قطع اتصال VPN' : 'اتصال VPN',
      child: GestureDetector(
        onTap: loading ? null : onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 350),
          width: 194,
          height: 194,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [glow.withValues(alpha: 0.22), const Color(0xFF0B1D35), const Color(0xFF071225)],
              stops: const [0, 0.58, 1],
            ),
            border: Border.all(color: glow.withValues(alpha: 0.9), width: 2),
            boxShadow: [
              BoxShadow(color: glow.withValues(alpha: 0.24), blurRadius: 35, spreadRadius: 5),
              BoxShadow(color: glow.withValues(alpha: 0.10), blurRadius: 70, spreadRadius: 16),
            ],
          ),
          child: Container(
            margin: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (loading)
                  const SizedBox(
                    width: 42,
                    height: 42,
                    child: CircularProgressIndicator(strokeWidth: 3, color: neonCyan),
                  )
                else
                  Icon(
                    connected ? Icons.power_settings_new_rounded : Icons.shield_rounded,
                    color: glow,
                    size: 49,
                  ),
                const SizedBox(height: 11),
                Text(
                  loading ? 'لطفاً صبر کن' : (connected ? 'قطع اتصال' : 'اتصال امن'),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 17),
                ),
                const SizedBox(height: 3),
                Text(
                  connected ? 'TUNNEL ACTIVE' : 'TAP TO CONNECT',
                  style: TextStyle(color: glow, fontSize: 9, letterSpacing: 1.7, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
