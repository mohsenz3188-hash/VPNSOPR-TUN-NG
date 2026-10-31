import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_sing_box/flutter_sing_box.dart';

/// Converts standard WireGuard .conf text into a sing-box 1.14 endpoint config.
/// The current sing-box WireGuard implementation is an endpoint, not the
/// deprecated WireGuard outbound type.
class WireGuardParser {
  Future<SingBox> toSingBoxConfig(String source) async {
    final sections = _parseSections(source);
    final interface = sections['interface'];
    final peerSections = sections.entries
        .where((entry) => entry.key.startsWith('peer'))
        .map((entry) => entry.value)
        .toList();

    if (interface == null || peerSections.isEmpty) {
      throw const FormatException('فایل WireGuard باید یک [Interface] و حداقل یک [Peer] داشته باشد.');
    }

    final privateKey = interface['privatekey'];
    final addresses = _csv(interface['address']);
    if (privateKey == null || privateKey.isEmpty || addresses.isEmpty) {
      throw const FormatException('در بخش Interface، مقدار PrivateKey یا Address وجود ندارد.');
    }

    final peers = <Map<String, dynamic>>[];
    for (final peer in peerSections) {
      final publicKey = peer['publickey'];
      final endpoint = peer['endpoint'];
      if (publicKey == null || publicKey.isEmpty || endpoint == null || endpoint.isEmpty) {
        throw const FormatException('هر Peer باید PublicKey و Endpoint معتبر داشته باشد.');
      }
      final parsedEndpoint = _parseEndpoint(endpoint);
      final allowedIps = _csv(peer['allowedips']);
      if (allowedIps.isEmpty) {
        throw const FormatException('برای هر Peer باید AllowedIPs مشخص شود.');
      }

      final keepalive = int.tryParse(peer['persistentkeepalive'] ?? '0') ?? 0;
      final reserved = _parseReserved(peer['reserved']);
      peers.add({
        'address': parsedEndpoint.host,
        'port': parsedEndpoint.port,
        'public_key': publicKey,
        'allowed_ips': allowedIps,
        if ((peer['presharedkey'] ?? '').isNotEmpty)
          'pre_shared_key': peer['presharedkey'],
        if (keepalive > 0) 'persistent_keepalive_interval': keepalive,
        if (reserved != null) 'reserved': reserved,
      });
    }

    final template = await rootBundle.loadString(
      'packages/flutter_sing_box/assets/configs/singbox_config_template.json',
    );
    final config = jsonDecode(template) as Map<String, dynamic>;
    final mtu = int.tryParse(interface['mtu'] ?? '') ?? 1408;

    config['inbounds'] = [
      {
        'type': 'tun',
        'tag': 'tun-in',
        'address': ['172.19.0.1/30', 'fdfe:dcba:9876::1/126'],
        'mtu': mtu,
        'auto_route': true,
        'strict_route': true,
      },
    ];
    config['outbounds'] = [
      {'type': 'direct', 'tag': 'direct'},
    ];
    config['endpoints'] = [
      {
        'type': 'wireguard',
        'tag': 'wg-ep',
        'system': false,
        'mtu': mtu,
        'address': addresses,
        'private_key': privateKey,
        'peers': peers,
      },
    ];

    final dnsAddresses = _csv(interface['dns']);
    if (dnsAddresses.isNotEmpty) {
      config['dns'] = {
        'servers': [
          for (var i = 0; i < dnsAddresses.length; i++)
            {
              'tag': 'wg-dns-$i',
              'type': 'udp',
              'server': dnsAddresses[i],
            },
        ],
        'final': 'wg-dns-0',
      };
    }

    config['route'] = {
      'rules': [
        {'protocol': 'dns', 'action': 'hijack-dns'},
        {'action': 'route', 'outbound': 'wg-ep'},
      ],
      'final': 'direct',
      'auto_detect_interface': true,
    };

    return SingBoxConfigProvider.provide(config);
  }

  String suggestName(String source) {
    final sections = _parseSections(source);
    final peers = sections.entries.where((entry) => entry.key.startsWith('peer'));
    for (final peer in peers) {
      final endpoint = peer.value['endpoint'];
      if (endpoint != null && endpoint.isNotEmpty) return 'WireGuard • $endpoint';
    }
    return 'WireGuard';
  }

  Map<String, Map<String, String>> _parseSections(String source) {
    final result = <String, Map<String, String>>{};
    String? current;
    var peerIndex = 0;

    for (final rawLine in const LineSplitter().convert(source)) {
      final line = rawLine.trim();
      if (line.isEmpty || line.startsWith('#') || line.startsWith(';')) continue;

      final sectionMatch = RegExp(r'^\[([^\]]+)\]$').firstMatch(line);
      if (sectionMatch != null) {
        final sectionName = sectionMatch.group(1)!.trim().toLowerCase();
        if (sectionName == 'interface') {
          current = 'interface';
        } else if (sectionName == 'peer') {
          current = 'peer-${peerIndex++}';
        } else {
          current = null;
        }
        if (current != null) result.putIfAbsent(current, () => <String, String>{});
        continue;
      }

      if (current == null) continue;
      final separator = line.indexOf('=');
      if (separator <= 0) continue;
      final key = line.substring(0, separator).trim().toLowerCase();
      final value = line.substring(separator + 1).split('#').first.trim();
      result[current]![key] = value;
    }
    return result;
  }

  List<String> _csv(String? value) {
    if (value == null || value.trim().isEmpty) return <String>[];
    return value
        .split(',')
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList();
  }

  ({String host, int port}) _parseEndpoint(String value) {
    final endpoint = value.trim();
    if (endpoint.startsWith('[')) {
      final close = endpoint.indexOf(']');
      if (close < 0 || close + 2 > endpoint.length || endpoint[close + 1] != ':') {
        throw const FormatException('Endpoint در فایل WireGuard معتبر نیست.');
      }
      final host = endpoint.substring(1, close);
      final port = int.tryParse(endpoint.substring(close + 2));
      if (host.isEmpty || port == null || port < 1 || port > 65535) {
        throw const FormatException('آدرس یا پورت Endpoint معتبر نیست.');
      }
      return (host: host, port: port);
    }

    final separator = endpoint.lastIndexOf(':');
    if (separator <= 0) {
      throw const FormatException('Endpoint باید به شکل host:port باشد.');
    }
    final host = endpoint.substring(0, separator).trim();
    final port = int.tryParse(endpoint.substring(separator + 1).trim());
    if (host.isEmpty || port == null || port < 1 || port > 65535) {
      throw const FormatException('آدرس یا پورت Endpoint معتبر نیست.');
    }
    return (host: host, port: port);
  }

  List<int>? _parseReserved(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final parts = value.split(',').map((part) {
      final item = part.trim().toLowerCase();
      return item.startsWith('0x')
          ? int.tryParse(item.substring(2), radix: 16)
          : int.tryParse(item);
    }).toList();
    if (parts.length != 3 || parts.any((part) => part == null || part < 0 || part > 255)) {
      return null;
    }
    return parts.cast<int>();
  }
}
