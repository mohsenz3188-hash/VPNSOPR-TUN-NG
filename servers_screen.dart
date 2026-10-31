import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:flutter_sing_box/flutter_sing_box.dart';

import '../theme.dart';
import '../core/vpn_controller.dart';

class ServersScreen extends StatelessWidget {
  const ServersScreen({super.key, required this.controller});
  final VpnController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            title: const Text('مدیریت سرورها', style: TextStyle(fontWeight: FontWeight.w800)),
            actions: [
              IconButton(onPressed: controller.refreshProfiles, icon: const Icon(Icons.refresh_rounded), tooltip: 'به‌روزرسانی فهرست'),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: controller.busy ? null : () => _showImportOptions(context),
            backgroundColor: neonBlue,
            foregroundColor: navy,
            icon: const Icon(Icons.add_rounded),
            label: const Text('افزودن کانفیگ', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 100),
            children: [
              _InfoCard(count: controller.profiles.length),
              const SizedBox(height: 14),
              if (controller.profiles.isEmpty)
                const _EmptyServers()
              else
                ...controller.profiles.map((profile) => _ProfileTile(
                      profile: profile,
                      selected: controller.selectedProfile?.id == profile.id,
                      onTap: () => controller.selectProfile(profile),
                      onDelete: () => _confirmDelete(context, profile),
                    )),
              if (controller.groups.isNotEmpty) ...[
                const SizedBox(height: 20),
                const Text('مسیرهای داخل کانفیگ فعال', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800)),
                const SizedBox(height: 10),
                ...controller.groups.map((group) => _ProxyGroupCard(
                      group: group,
                      onSelect: (tag) => controller.selectOutbound(groupTag: group.tag, outboundTag: tag),
                      onTest: controller.testLatency,
                    )),
              ],
            ],
          ),
        );
      },
    );
  }

  Future<void> _showImportOptions(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: panel,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 4, 18, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Align(
                alignment: Alignment.centerRight,
                child: Text('روش افزودن کانفیگ', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800)),
              ),
              const SizedBox(height: 12),
              _ImportOption(
                icon: Icons.link_rounded,
                title: 'لینک یا متن کانفیگ',
                subtitle: 'VLESS، VMess، Trojan، Shadowsocks و اشتراک',
                onTap: () {
                  Navigator.pop(sheetContext);
                  _showTextImport(context);
                },
              ),
              _ImportOption(
                icon: Icons.qr_code_scanner_rounded,
                title: 'اسکن QR Code',
                subtitle: 'خواندن لینک یا کانفیگ از روی QR',
                onTap: () async {
                  Navigator.pop(sheetContext);
                  final result = await Navigator.push<String>(context, MaterialPageRoute(builder: (_) => const QrImportScreen()));
                  if (result != null && result.trim().isNotEmpty) {
                    await _importAndNotify(context, result);
                  }
                },
              ),
              _ImportOption(
                icon: Icons.file_open_rounded,
                title: 'انتخاب فایل',
                subtitle: 'پشتیبانی از WireGuard .conf، JSON و TXT',
                onTap: () {
                  Navigator.pop(sheetContext);
                  _pickFile(context);
                },
              ),
              _ImportOption(
                icon: Icons.content_paste_rounded,
                title: 'چسباندن از حافظه موقت',
                subtitle: 'استفاده از متنی که کپی کرده‌ای',
                onTap: () {
                  Navigator.pop(sheetContext);
                  _pasteFromClipboard(context);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showTextImport(BuildContext context) async {
    final textController = TextEditingController();
    final nameController = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: panel,
        title: const Text('واردکردن کانفیگ', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
        content: SizedBox(
          width: 460,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                textDirection: TextDirection.rtl,
                decoration: const InputDecoration(labelText: 'نام دلخواه (اختیاری)', prefixIcon: Icon(Icons.label_outline)),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: textController,
                minLines: 5,
                maxLines: 9,
                keyboardType: TextInputType.multiline,
                textDirection: TextDirection.ltr,
                decoration: const InputDecoration(
                  hintText: 'لینک، متن اشتراک یا محتوای فایل WireGuard را وارد کن...',
                  alignLabelWithHint: true,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('انصراف')),
          FilledButton.icon(
            onPressed: () async {
              final value = textController.text.trim();
              if (value.isEmpty) return;
              Navigator.pop(dialogContext);
              await _importAndNotify(context, value, name: nameController.text.trim());
            },
            icon: const Icon(Icons.download_rounded),
            label: const Text('وارد کن'),
          ),
        ],
      ),
    );
    textController.dispose();
    nameController.dispose();
  }

  Future<void> _pickFile(BuildContext context) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['conf', 'json', 'yaml', 'yml', 'txt'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;
      final file = result.files.first;
      final bytes = file.bytes ?? (file.path != null ? await File(file.path!).readAsBytes() : null);
      if (bytes == null) throw Exception('محتوای فایل قابل خواندن نیست.');
      final content = utf8.decode(bytes, allowMalformed: false);
      final name = file.name.replaceFirst(RegExp(r'\.[^.]+$'), '');
      await _importAndNotify(context, content, name: name);
    } catch (error) {
      _showMessage(context, 'خواندن فایل ناموفق بود: $error', isError: true);
    }
  }

  Future<void> _pasteFromClipboard(BuildContext context) async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim();
    if (text == null || text.isEmpty) {
      _showMessage(context, 'حافظه موقت خالی است.', isError: true);
      return;
    }
    await _importAndNotify(context, text);
  }

  Future<void> _importAndNotify(BuildContext context, String text, {String? name}) async {
    try {
      await controller.importText(text, name: name?.isNotEmpty == true ? name : null);
      if (context.mounted) _showMessage(context, 'کانفیگ با موفقیت اضافه و انتخاب شد.');
    } catch (error) {
      if (context.mounted) _showMessage(context, 'واردکردن کانفیگ ناموفق بود: $error', isError: true);
    }
  }

  Future<void> _confirmDelete(BuildContext context, Profile profile) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: panel,
        title: const Text('حذف کانفیگ', style: TextStyle(color: Colors.white)),
        content: Text('«${profile.name}» از فهرست حذف شود؟', style: const TextStyle(color: mutedText)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('انصراف')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFB63E56)),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (confirmed == true) await controller.deleteProfile(profile);
  }

  void _showMessage(BuildContext context, String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, textDirection: TextDirection.rtl),
        backgroundColor: isError ? const Color(0xFF8D2F45) : const Color(0xFF124D68),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(colors: [Color(0xFF10335A), Color(0xFF0A1A30)]),
        border: Border.all(color: neonBlue.withValues(alpha: 0.22)),
      ),
      child: Row(
        children: [
          const Icon(Icons.hub_rounded, color: neonCyan, size: 29),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('کتابخانه کانفیگ‌ها', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                SizedBox(height: 4),
                Text('لینک، اشتراک، QR و فایل WireGuard', style: TextStyle(color: mutedText, fontSize: 10)),
              ],
            ),
          ),
          Text('$count', style: const TextStyle(color: neonCyan, fontSize: 24, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}

class _ProfileTile extends StatelessWidget {
  const _ProfileTile({required this.profile, required this.selected, required this.onTap, required this.onDelete});
  final Profile profile;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: selected ? const Color(0xFF102B49) : panel,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: selected ? neonBlue.withValues(alpha: 0.65) : Colors.white.withValues(alpha: 0.06)),
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(color: neonBlue.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(13)),
          child: Icon(profile.name.toLowerCase().contains('wireguard') ? Icons.vpn_lock_rounded : Icons.dns_rounded, color: neonCyan),
        ),
        title: Text(profile.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            '${profile.outboundsCount ?? 0} مسیر  •  ${profile.typed.type.name.toUpperCase()}',
            style: const TextStyle(color: mutedText, fontSize: 10),
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selected) const Icon(Icons.check_circle_rounded, color: neonCyan, size: 20),
            IconButton(onPressed: onDelete, icon: const Icon(Icons.delete_outline_rounded, color: Colors.white54, size: 20)),
          ],
        ),
      ),
    );
  }
}

class _ProxyGroupCard extends StatelessWidget {
  const _ProxyGroupCard({required this.group, required this.onSelect, required this.onTest});
  final ClientGroup group;
  final ValueChanged<String> onSelect;
  final VoidCallback onTest;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(color: panel, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withValues(alpha: 0.06))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(group.tag, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800))),
              Text(group.selected, style: const TextStyle(color: neonCyan, fontSize: 11)),
              IconButton(onPressed: onTest, icon: const Icon(Icons.speed_rounded, color: neonCyan, size: 18), visualDensity: VisualDensity.compact),
            ],
          ),
          if (group.items != null)
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: group.items!.map((item) {
                final active = item.tag == group.selected;
                return ActionChip(
                  label: Text('${item.tag}  ${item.urlTestDelay > 0 ? '${item.urlTestDelay} ms' : ''}', style: TextStyle(color: active ? navy : Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
                  backgroundColor: active ? neonCyan : panelLight,
                  side: BorderSide(color: active ? neonCyan : Colors.white12),
                  onPressed: group.selectable ? () => onSelect(item.tag) : null,
                );
              }).toList(),
            ),
        ],
      ),
    );
  }
}

class _EmptyServers extends StatelessWidget {
  const _EmptyServers();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 42),
      decoration: BoxDecoration(color: panel.withValues(alpha: 0.75), borderRadius: BorderRadius.circular(20), border: Border.all(color: neonBlue.withValues(alpha: 0.12))),
      child: const Column(
        children: [
          Icon(Icons.cloud_download_outlined, color: neonCyan, size: 52),
          SizedBox(height: 15),
          Text('هنوز کانفیگی وارد نکرده‌ای', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
          SizedBox(height: 7),
          Text('از دکمه پایین لینک، QR یا فایل WireGuard را اضافه کن.', textAlign: TextAlign.center, style: TextStyle(color: mutedText, height: 1.7, fontSize: 11)),
        ],
      ),
    );
  }
}

class _ImportOption extends StatelessWidget {
  const _ImportOption({required this.icon, required this.title, required this.subtitle, required this.onTap});
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: EdgeInsets.zero,
      leading: Container(width: 43, height: 43, decoration: BoxDecoration(color: neonBlue.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(13)), child: Icon(icon, color: neonCyan)),
      title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
      subtitle: Text(subtitle, style: const TextStyle(color: mutedText, fontSize: 10)),
      trailing: const Icon(Icons.chevron_left_rounded, color: mutedText),
    );
  }
}

class QrImportScreen extends StatefulWidget {
  const QrImportScreen({super.key});

  @override
  State<QrImportScreen> createState() => _QrImportScreenState();
}

class _QrImportScreenState extends State<QrImportScreen> {
  bool _handled = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: navy,
      appBar: AppBar(title: const Text('اسکن کانفیگ')),
      body: Stack(
        children: [
          MobileScanner(
            onDetect: (capture) {
              if (_handled || capture.barcodes.isEmpty) return;
              final value = capture.barcodes.first.rawValue;
              if (value == null || value.trim().isEmpty) return;
              _handled = true;
              Navigator.pop(context, value);
            },
          ),
          Center(
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(border: Border.all(color: neonCyan, width: 3), borderRadius: BorderRadius.circular(24)),
            ),
          ),
          const Positioned(
            bottom: 38,
            left: 25,
            right: 25,
            child: Text('QR کانفیگ را داخل کادر قرار بده.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, shadows: [Shadow(color: Colors.black, blurRadius: 10)])),
          ),
        ],
      ),
    );
  }
}
