import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_sing_box/flutter_sing_box.dart';

import '../theme.dart';
import '../core/vpn_controller.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.controller});
  final VpnController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(title: const Text('تنظیمات', style: TextStyle(fontWeight: FontWeight.w800))),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF10335A), Color(0xFF09172A)]),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: neonBlue.withValues(alpha: 0.25)),
                ),
                child: Row(
                  children: [
                    ClipRRect(borderRadius: BorderRadius.circular(13), child: Image.asset('assets/vpnsopr_icon.png', width: 58, height: 58, fit: BoxFit.cover)),
                    const SizedBox(width: 13),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('TUN VPNSOPR', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 17)),
                          SizedBox(height: 4),
                          Text('Multi-protocol secure tunnel client', style: TextStyle(color: mutedText, fontSize: 10)),
                          SizedBox(height: 5),
                          Text('نسخه 1.0.0', style: TextStyle(color: neonCyan, fontSize: 10, fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              _SettingTile(
                icon: Icons.memory_rounded,
                title: 'نسخه موتور اتصال',
                subtitle: controller.coreVersion ?? 'در حال دریافت...',
              ),
              _SettingTile(
                icon: Icons.security_rounded,
                title: 'مجوز VPN اندروید',
                subtitle: 'برای اتصال، اجازه ایجاد تونل VPN از خود اندروید گرفته می‌شود.',
              ),
              _SettingTile(
                icon: Icons.autorenew_rounded,
                title: 'اتصال همیشگی اندروید',
                subtitle: 'برای اتصال خودکار پس از راه‌اندازی گوشی، از تنظیمات اندروید وارد VPN شو و گزینه Always-on VPN را برای VPNSOPR فعال کن.',
              ),
              _SettingTile(
                icon: Icons.save_outlined,
                title: 'ذخیره‌سازی کانفیگ‌ها',
                subtitle: 'فایل‌های کانفیگ در فضای خصوصی برنامه روی همین دستگاه نگهداری می‌شوند.',
              ),
              _SettingTile(
                icon: Icons.layers_outlined,
                title: 'پروتکل‌ها',
                subtitle: 'VLESS، VMess، Trojan، Shadowsocks، Hysteria و WireGuard و سایر فرمت‌های پشتیبانی‌شده توسط هسته.',
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: panel, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withValues(alpha: 0.06))),
                child: const Text(
                  'نکته امنیتی: لینک اشتراک و کلید خصوصی WireGuard را فقط از ارائه‌دهنده مورداعتماد دریافت کن. کانفیگ‌ها را برای افراد ناشناس ارسال نکن.',
                  style: TextStyle(color: mutedText, fontSize: 11, height: 1.8),
                  textAlign: TextAlign.justify,
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: controller.busy ? null : () => _exportBackup(context),
                      icon: const Icon(Icons.backup_outlined),
                      label: const Text('پشتیبان‌گیری'),
                      style: OutlinedButton.styleFrom(foregroundColor: neonCyan, side: BorderSide(color: neonBlue.withValues(alpha: 0.35)), padding: const EdgeInsets.symmetric(vertical: 13)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: controller.busy ? null : () => _restoreBackup(context),
                      icon: const Icon(Icons.settings_backup_restore_rounded),
                      label: const Text('بازیابی'),
                      style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: BorderSide(color: neonBlue.withValues(alpha: 0.22)), padding: const EdgeInsets.symmetric(vertical: 13)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Center(
                child: TextButton.icon(
                  onPressed: () async {
                    final version = await FlutterSingBox().getSingBoxVersion();
                    if (context.mounted) {
                      showAboutDialog(
                        context: context,
                        applicationName: 'TUN VPNSOPR',
                        applicationVersion: '1.0.0',
                        applicationLegalese: 'Powered by sing-box. See THIRD_PARTY_NOTICES.md for licenses.',
                        children: [Text('Core: $version')],
                      );
                    }
                  },
                  icon: const Icon(Icons.info_outline_rounded, color: neonCyan),
                  label: const Text('درباره برنامه', style: TextStyle(color: neonCyan)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _exportBackup(BuildContext context) async {
    try {
      final backup = await controller.createBackup();
      final path = await FilePicker.platform.saveFile(
        dialogTitle: 'ذخیره پشتیبان VPNSOPR',
        fileName: 'vpnsopr-backup.json',
        type: FileType.custom,
        allowedExtensions: ['json'],
        bytes: Uint8List.fromList(utf8.encode(backup)),
      );
      if (context.mounted && path != null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('فایل پشتیبان ذخیره شد.')));
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('پشتیبان‌گیری ناموفق بود: $error')));
      }
    }
  }

  Future<void> _restoreBackup(BuildContext context) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;
      final file = result.files.first;
      final bytes = file.bytes ?? (file.path != null ? await File(file.path!).readAsBytes() : null);
      if (bytes == null) throw Exception('فایل قابل خواندن نیست.');
      final count = await controller.restoreBackup(utf8.decode(bytes));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$count کانفیگ بازیابی شد.')));
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('بازیابی ناموفق بود: $error')));
      }
    }
  }
}

class _SettingTile extends StatelessWidget {
  const _SettingTile({required this.icon, required this.title, required this.subtitle});
  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: panel, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withValues(alpha: 0.06))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: neonCyan, size: 21),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12)),
                const SizedBox(height: 5),
                Text(subtitle, style: const TextStyle(color: mutedText, fontSize: 10, height: 1.6)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
