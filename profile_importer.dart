import 'dart:convert';
import 'dart:io';

import 'package:flutter_sing_box/flutter_sing_box.dart';

import 'wireguard_parser.dart';

/// Imports share links, subscriptions, sing-box JSON and WireGuard .conf files.
class ProfileImporter {
  Future<Profile> importText(String source, {String? name}) async {
    final text = source.trim();
    if (text.isEmpty) throw const FormatException('متن کانفیگ خالی است.');

    if (_looksLikeWireGuard(text)) {
      final config = await WireGuardParser().toSingBoxConfig(text);
      return _saveLocal(config, name: name ?? WireGuardParser().suggestName(text));
    }

    final firstLine = text.split(RegExp(r'\r?\n')).first.trim();
    final uri = Uri.tryParse(firstLine);
    final isHttpSubscription = uri != null &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.userInfo.isEmpty &&
        (uri.path.isNotEmpty || uri.port == 80 || uri.port == 443);

    if (isHttpSubscription) {
      final response = await NetworkService().fetchSubscription(uri);
      final config = await _parseConfigContent(response.data);
      final profileName = name?.trim().isNotEmpty == true ? name!.trim() : uri.host;
      return _saveLocal(
        config,
        name: profileName,
        type: ProfileType.remote,
        subscribeUrl: uri.toString(),
      );
    }

    final config = await _parseConfigContent(text);

    final profileName = name?.trim().isNotEmpty == true
        ? name!.trim()
        : _guessName(text);
    return _saveLocal(config, name: profileName);
  }

  Future<Profile> importFile(File file, {String? name}) async {
    final content = await file.readAsString();
    final extension = file.path.split('.').last.toLowerCase();
    if (extension == 'conf' || _looksLikeWireGuard(content)) {
      final config = await WireGuardParser().toSingBoxConfig(content);
      return _saveLocal(
        config,
        name: name ?? file.uri.pathSegments.last.replaceAll('.conf', ''),
      );
    }
    return importText(content, name: name ?? file.uri.pathSegments.last);
  }


  Future<String> createBackup() async {
    final profiles = ProfileStorage().getProfiles();
    final items = <Map<String, dynamic>>[];
    for (final profile in profiles) {
      final file = File(profile.typed.path);
      if (!await file.exists()) continue;
      final config = jsonDecode(await file.readAsString());
      items.add({'name': profile.name, 'config': config});
    }
    return jsonEncode({
      'vpnsopr_backup': 1,
      'created_at': DateTime.now().toUtc().toIso8601String(),
      'profiles': items,
    });
  }

  Future<int> restoreBackup(String source) async {
    final decoded = jsonDecode(source);
    if (decoded is! Map<String, dynamic> || decoded['vpnsopr_backup'] != 1 || decoded['profiles'] is! List) {
      throw const FormatException('فایل پشتیبان VPNSOPR معتبر نیست.');
    }
    final items = decoded['profiles'] as List<dynamic>;
    if (items.isEmpty) throw const FormatException('فایل پشتیبان هیچ کانفیگی ندارد.');
    var restored = 0;
    for (final item in items) {
      if (item is! Map<String, dynamic> || item['config'] is! Map<String, dynamic>) continue;
      final config = await SingBoxConfigProvider.provide(item['config']);
      final name = item['name'] is String && (item['name'] as String).trim().isNotEmpty
          ? (item['name'] as String).trim()
          : 'کانفیگ بازیابی‌شده';
      await _saveLocal(config, name: name);
      restored++;
    }
    if (restored == 0) throw const FormatException('هیچ کانفیگ قابل بازیابی در فایل پیدا نشد.');
    return restored;
  }

  Future<SingBox> _parseConfigContent(dynamic data) async {
    if (data is Map<String, dynamic>) {
      return SingBoxConfigProvider.provide(data);
    }
    if (data is List<int>) {
      data = utf8.decode(data);
    }
    if (data is! String) {
      throw const FormatException('فرمت محتوای کانفیگ پشتیبانی نمی‌شود.');
    }
    final content = data.trim();
    if (_looksLikeShareLinks(content)) {
      return SingBoxConfigProvider.provide(base64Encode(utf8.encode(content)));
    }
    if (content.startsWith('{')) {
      final decoded = jsonDecode(content);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('ساختار JSON معتبر نیست.');
      }
      return SingBoxConfigProvider.provide(decoded);
    }
    return SingBoxConfigProvider.provide(content);
  }

  Future<Profile> _saveLocal(
    SingBox config, {
    required String name,
    ProfileType type = ProfileType.local,
    String? subscribeUrl,
  }) async {
    final storage = ProfileStorage();
    final id = storage.generateProfileId;
    final path = await storage.getProfilePath(id);
    final endpoints = config.unknownSections['endpoints'];
    final endpointCount = endpoints is List ? endpoints.length : 0;
    final outboundCount = config.outbounds
        .where((outbound) => outbound.type != OutboundType.direct)
        .length;

    final profile = Profile(
      id: id,
      order: id,
      name: name,
      outboundsCount: outboundCount + endpointCount,
      typed: TypedProfile(
        type: type,
        path: path,
        lastUpdated: DateTime.now().millisecondsSinceEpoch,
        subscribeUrl: subscribeUrl,
        webPageUrl: subscribeUrl == null ? null : Uri.parse(subscribeUrl).host,
      ),
    );

    await storage.addProfile(profile, config);
    storage.setSelectedProfile(id);
    return profile;
  }

  bool _looksLikeWireGuard(String text) {
    return RegExp(r'^\s*\[Interface\]\s*$', multiLine: true).hasMatch(text) &&
        RegExp(r'^\s*\[Peer\]\s*$', multiLine: true).hasMatch(text);
  }

  bool _looksLikeShareLinks(String text) {
    final lines = text.split(RegExp(r'\r?\n')).map((line) => line.trim());
    const schemes = <String>{
      'vless', 'vmess', 'trojan', 'ss', 'hysteria', 'hysteria2', 'hy2',
      'anytls',
    };
    return lines.any((line) {
      final uri = Uri.tryParse(line);
      return uri != null && schemes.contains(uri.scheme.toLowerCase());
    });
  }

  String _guessName(String text) {
    final first = text.split(RegExp(r'\r?\n')).first.trim();
    final uri = Uri.tryParse(first);
    if (uri != null && uri.host.isNotEmpty) {
      return '${uri.scheme.toUpperCase()} • ${uri.host}';
    }
    if (first.startsWith('{')) return 'کانفیگ JSON';
    return 'سرور جدید VPNSOPR';
  }
}
