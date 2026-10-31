
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_sing_box/flutter_sing_box.dart';

import 'wireguard_parser.dart';

class ProfileImporter {
  Future<Profile> importText(String source, {String? name}) async {
    final text = source.trim();

    if (text.isEmpty) {
      throw const FormatException('متن کانفیگ خالی است.');
    }

    if (_looksLikeWireGuard(text)) {
      final parser = WireGuardParser();
      final config = await parser.toSingBoxConfig(text);
      return _saveLocal(
        config,
        name: name ?? parser.suggestName(text),
      );
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

      return _saveLocal(
        config,
        name: name?.trim().isNotEmpty == true
            ? name!.trim()
            : uri.host,
        type: ProfileType.remote,
        subscribeUrl: uri.toString(),
      );
    }

    final config = await _parseConfigContent(text);

    return _saveLocal(
      config,
      name: name?.trim().isNotEmpty == true
          ? name!.trim()
          : _guessName(text),
    );
  }

  Future<Profile> importFile(File file, {String? name}) async {
    final content = await file.readAsString();
    final extension = file.path.split('.').last.toLowerCase();

    if (extension == 'conf' || _looksLikeWireGuard(content)) {
      final parser = WireGuardParser();
      final config = await parser.toSingBoxConfig(content);

      return _saveLocal(
        config,
        name: name ?? file.uri.pathSegments.last.replaceAll('.conf', ''),
      );
    }

    return importText(
      content,
      name: name ?? file.uri.pathSegments.last,
    );
  }

  Future<SingBox> _parseConfigContent(dynamic data) async {
    if (data is Map<String, dynamic>) {
      return SingBoxConfigProvider.provide(data);
    }

    if (data is List<int>) {
      data = utf8.decode(data);
    }

    if (data is! String) {
      throw const FormatException(
        'فرمت محتوای کانفیگ پشتیبانی نمی‌شود.',
      );
    }

    final content = data.trim();

    if (content.isEmpty) {
      throw const FormatException('کانفیگ خالی است.');
    }

    // لینک‌های مستقیم VLESS و VMess و سایر پروتکل‌ها
    if (_looksLikeShareLinks(content)) {
      return _parseShareLinks(content);
    }

    // اشتراک Base64
    final decodedSubscription = _decodeBase64Subscription(content);

    if (decodedSubscription != null) {
      return _parseShareLinks(decodedSubscription);
    }

    // JSON
    if (content.startsWith('{')) {
      final decoded = jsonDecode(content);

      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('ساختار JSON معتبر نیست.');
      }

      return SingBoxConfigProvider.provide(decoded);
    }

    // YAML یا سایر فرمت‌های پشتیبانی‌شده توسط هسته
    return SingBoxConfigProvider.provide(content);
  }

  // اصلاح اصلی خطای Bad state: No element
  Future<SingBox> _parseShareLinks(String content) async {
    final encoded = base64Encode(utf8.encode(content));

    final parsed = Base64Provider.provide(encoded);

    if (parsed.isEmpty) {
      throw const FormatException(
        'هیچ سرور معتبری در لینک یا اشتراک پیدا نشد.',
      );
    }

    final templateText = await rootBundle.loadString(
      FlutterSingBoxConstants.templateConfig,
    );

    final config = Map<String, dynamic>.from(
      jsonDecode(templateText) as Map,
    );

    final nodes = <Map<String, dynamic>>[];
    final usedTags = <String>{};

    for (var i = 0; i < parsed.length; i++) {
      final node = Map<String, dynamic>.from(
        parsed[i].toJson(),
      );

      final originalTag = node['tag']?.toString().trim() ?? '';

      final baseTag = originalTag.isEmpty
          ? 'server-${i + 1}'
          : originalTag;

      var tag = baseTag;
      var suffix = 2;

      while (
        usedTags.contains(tag) ||
        tag == 'proxy' ||
        tag == 'direct'
      ) {
        tag = '$baseTag-$suffix';
        suffix++;
      }

      usedTags.add(tag);
      node['tag'] = tag;

      nodes.add(node);
    }

    if (nodes.isEmpty) {
      throw const FormatException('هیچ سرور قابل استفاده‌ای پیدا نشد.');
    }

    final nodeTags = nodes
        .map((node) => node['tag'] as String)
        .toList();

    final String finalTag;

    final outbounds = <Map<String, dynamic>>[];

    if (nodes.length == 1) {
      // یک سرور: بدون ساخت گروه تک‌عضوی
      finalTag = nodeTags.first;
    } else {
      // چند سرور: ساخت گروه انتخاب سرور
      finalTag = 'proxy';

      outbounds.add({
        'type': 'selector',
        'tag': 'proxy',
        'outbounds': nodeTags,
        'default': nodeTags.first,
      });
    }

    outbounds.addAll(nodes);

    outbounds.add({
      'type': 'direct',
      'tag': 'direct',
    });

    config['outbounds'] = outbounds;

    final route = Map<String, dynamic>.from(
      config['route'] as Map,
    );

    route['final'] = finalTag;

    final rules = route['rules'];

    if (rules is List) {
      route['rules'] = rules.map((rule) {
        if (rule is Map) {
          final item = Map<String, dynamic>.from(rule);

          if (item['outbound'] == 'proxy') {
            item['outbound'] = finalTag;
          }

          return item;
        }

        return rule;
      }).toList();
    }

    config['route'] = route;

    return SingBoxConfigProvider.provide(config);
  }

  String? _decodeBase64Subscription(String text) {
    final compact = text.replaceAll(RegExp(r'\s+'), '');

    if (compact.isEmpty || compact.length % 4 == 1) {
      return null;
    }

    final normalized = compact
        .replaceAll('-', '+')
        .replaceAll('_', '/');

    final padded = normalized +
        '=' * ((4 - normalized.length % 4) % 4);

    try {
      final decoded = utf8.decode(base64.decode(padded));

      if (_looksLikeShareLinks(decoded)) {
        return decoded;
      }
    } catch (_) {
      return null;
    }

    return null;
  }

  bool _looksLikeShareLinks(String text) {
    const schemes = {
      'vless',
      'vmess',
      'trojan',
      'ss',
      'hysteria',
      'hysteria2',
      'hy2',
      'anytls',
    };

    for (final line in text.split(RegExp(r'\r?\n'))) {
      final uri = Uri.tryParse(line.trim());

      if (uri != null &&
          schemes.contains(uri.scheme.toLowerCase())) {
        return true;
      }
    }

    return false;
  }

  bool _looksLikeWireGuard(String text) {
    return RegExp(
          r'^\s*\[Interface\]\s*$',
          multiLine: true,
        ).hasMatch(text) &&
        RegExp(
          r'^\s*\[Peer\]\s*$',
          multiLine: true,
        ).hasMatch(text);
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

    final endpointCount = endpoints is List
        ? endpoints.length
        : 0;

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
        webPageUrl: subscribeUrl == null
            ? null
            : Uri.parse(subscribeUrl).host,
      ),
    );

    await storage.addProfile(profile, config);
    storage.setSelectedProfile(id);

    return profile;
  }

  String _guessName(String text) {
    final first = text.split(RegExp(r'\r?\n')).first.trim();
    final uri = Uri.tryParse(first);

    if (uri != null && uri.host.isNotEmpty) {
      return '${uri.scheme.toUpperCase()} • ${uri.host}';
    }

    if (first.startsWith('{')) {
      return 'کانفیگ JSON';
    }

    return 'سرور جدید VPNSOPR';
  }

  Future<String> createBackup() async {
    final profiles = ProfileStorage().getProfiles();
    final items = <Map<String, dynamic>>[];

    for (final profile in profiles) {
      final file = File(profile.typed.path);

      if (!await file.exists()) continue;

      final config = jsonDecode(await file.readAsString());

      items.add({
        'name': profile.name,
        'config': config,
      });
    }

    return jsonEncode({
      'vpnsopr_backup': 1,
      'created_at': DateTime.now().toUtc().toIso8601String(),
      'profiles': items,
    });
  }

  Future<int> restoreBackup(String source) async {
    final decoded = jsonDecode(source);

    if (decoded is! Map<String, dynamic> ||
        decoded['vpnsopr_backup'] != 1 ||
        decoded['profiles'] is! List) {
      throw const FormatException(
        'فایل پشتیبان VPNSOPR معتبر نیست.',
      );
    }

    final items = decoded['profiles'] as List<dynamic>;

    if (items.isEmpty) {
      throw const FormatException(
        'فایل پشتیبان هیچ کانفیگی ندارد.',
      );
    }

    var restored = 0;

    for (final item in items) {
      if (item is! Map<String, dynamic> ||
          item['config'] is! Map<String, dynamic>) {
        continue;
      }

      final config = await SingBoxConfigProvider.provide(
        item['config'],
      );

      final name = item['name'] is String &&
              (item['name'] as String).trim().isNotEmpty
          ? (item['name'] as String).trim()
          : 'کانفیگ بازیابی‌شده';

      await _saveLocal(config, name: name);
      restored++;
    }

    if (restored == 0) {
      throw const FormatException(
        'هیچ کانفیگ قابل بازیابی پیدا نشد.',
      );
    }

    return restored;
  }
}
