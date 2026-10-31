import 'package:flutter/material.dart';

import '../theme.dart';
import '../core/vpn_controller.dart';

class LogsScreen extends StatelessWidget {
  const LogsScreen({super.key, required this.controller});
  final VpnController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            title: const Text('گزارش‌های هسته', style: TextStyle(fontWeight: FontWeight.w800)),
            actions: [
              IconButton(onPressed: controller.clearLogs, tooltip: 'پاک‌کردن گزارش‌ها', icon: const Icon(Icons.delete_sweep_outlined)),
            ],
          ),
          body: controller.logs.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.terminal_rounded, color: neonCyan, size: 46),
                      SizedBox(height: 12),
                      Text('هنوز گزارشی ثبت نشده است', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                      SizedBox(height: 6),
                      Text('پس از اجرای هسته، پیام‌ها اینجا نمایش داده می‌شوند.', style: TextStyle(color: mutedText, fontSize: 11)),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 20),
                  itemCount: controller.logs.length,
                  separatorBuilder: (_, __) => const Divider(color: Colors.white10, height: 1),
                  itemBuilder: (context, index) {
                    final log = controller.logs[controller.logs.length - 1 - index];
                    final color = _levelColor(log.level);
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 7,
                            height: 7,
                            margin: const EdgeInsets.only(top: 5),
                            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 10),
                          SizedBox(width: 48, child: Text(_levelName(log.level), style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w900))),
                          Expanded(child: SelectableText(log.message, textDirection: TextDirection.ltr, style: const TextStyle(color: Colors.white70, fontSize: 10, height: 1.5))),
                        ],
                      ),
                    );
                  },
                ),
        );
      },
    );
  }

  Color _levelColor(int level) {
    if (level <= 2) return const Color(0xFFFF7185);
    if (level == 3) return const Color(0xFFFFC36E);
    if (level == 4) return neonCyan;
    return mutedText;
  }

  String _levelName(int level) {
    if (level <= 2) return 'ERROR';
    if (level == 3) return 'WARN';
    if (level == 4) return 'INFO';
    if (level == 5) return 'DEBUG';
    return 'TRACE';
  }
}
