import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_sing_box/flutter_sing_box.dart';

import 'profile_importer.dart';

class VpnController extends ChangeNotifier {
  VpnController({this.startupError});

  final FlutterSingBox _engine = FlutterSingBox();
  final String? startupError;
  final ProfileImporter _importer = ProfileImporter();

  ProxyState state = const ProxyStopped();
  ClientStatus? stats;
  List<Profile> profiles = <Profile>[];
  Profile? selectedProfile;
  List<ClientGroup> groups = <ClientGroup>[];
  List<ClientLog> logs = <ClientLog>[];
  String? lastError;
  bool busy = false;
  String? coreVersion;

  StreamSubscription<ProxyState>? _stateSubscription;
  StreamSubscription<ClientStatus>? _statusSubscription;
  StreamSubscription<List<ClientGroup>>? _groupSubscription;
  StreamSubscription<List<ClientLog>>? _logSubscription;

  bool get isConnected => state is ProxyStarted;
  bool get isTransitioning => state is ProxyStarting || state is ProxyStopping;

  Future<void> initialize() async {
    lastError = startupError;
    _refreshProfiles(notify: false);

    try {
      _stateSubscription = _engine.proxyStateStream.listen((nextState) {
        state = nextState;
        if (nextState is ProxyStopped && nextState.errMessage != null) {
          lastError = nextState.errMessage;
        }
        notifyListeners();
      }, onError: (Object error) {
        lastError = error.toString();
        notifyListeners();
      });

      _statusSubscription = _engine.connectedStatusStream.listen((nextStats) {
        stats = nextStats;
        notifyListeners();
      });

      _groupSubscription = _engine.groupStream.listen((nextGroups) {
        groups = nextGroups;
        notifyListeners();
      });

      _logSubscription = _engine.logStream.listen((batch) {
        logs = <ClientLog>[...logs, ...batch];
        if (logs.length > 250) logs = logs.sublist(logs.length - 250);
        notifyListeners();
      });

      coreVersion = await _engine.getSingBoxVersion();
    } catch (error) {
      lastError ??= error.toString();
    }
    notifyListeners();
  }

  void _refreshProfiles({bool notify = true}) {
    try {
      profiles = ProfileStorage().getProfiles();
      selectedProfile = ProfileStorage().getSelectedProfile();
    } catch (error) {
      lastError = 'خواندن فهرست سرورها ناموفق بود: $error';
    }
    if (notify) notifyListeners();
  }

  Future<void> refreshProfiles() async => _refreshProfiles();

  Future<void> toggleConnection() async {
    if (busy || isTransitioning) return;
    if (isConnected) {
      await disconnect();
    } else {
      await connect();
    }
  }

  Future<void> connect() async {
    if (selectedProfile == null) {
      lastError = 'ابتدا یک کانفیگ وارد و انتخاب کن.';
      notifyListeners();
      return;
    }
    busy = true;
    lastError = null;
    notifyListeners();
    try {
      await _engine.startVpn();
    } catch (error) {
      lastError = error.toString();
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> disconnect() async {
    busy = true;
    notifyListeners();
    try {
      await _engine.stopVpn();
    } catch (error) {
      lastError = error.toString();
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> importText(String source, {String? name}) async {
    busy = true;
    lastError = null;
    notifyListeners();
    try {
      final profile = await _importer.importText(source, name: name);
      ProfileStorage().setSelectedProfile(profile.id);
      _refreshProfiles(notify: false);
      selectedProfile = profile;
    } catch (error) {
      lastError = error.toString();
      rethrow;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> selectProfile(Profile profile) async {
    if (selectedProfile?.id == profile.id) return;
    try {
      ProfileStorage().setSelectedProfile(profile.id);
      selectedProfile = profile;
      lastError = null;
      notifyListeners();
      if (isConnected) {
        await disconnect();
        await _waitUntilStopped();
        await connect();
      }
    } catch (error) {
      lastError = 'تغییر سرور انجام نشد: $error';
      notifyListeners();
    }
  }

  Future<void> deleteProfile(Profile profile) async {
    if (isConnected && selectedProfile?.id == profile.id) {
      await disconnect();
      await _waitUntilStopped();
    }
    try {
      ProfileStorage().deleteProfile(profile.id);
      _refreshProfiles(notify: false);
      if (selectedProfile == null && profiles.isNotEmpty) {
        ProfileStorage().setSelectedProfile(profiles.first.id);
        selectedProfile = profiles.first;
      }
      notifyListeners();
    } catch (error) {
      lastError = 'حذف کانفیگ ناموفق بود: $error';
      notifyListeners();
    }
  }

  Future<void> _waitUntilStopped() async {
    if (state is ProxyStopped) return;
    try {
      await _engine.proxyStateStream
          .firstWhere((next) => next is ProxyStopped)
          .timeout(const Duration(seconds: 8));
    } on TimeoutException {
      throw Exception('هسته در زمان تعیین‌شده متوقف نشد.');
    }
  }

  Future<String> createBackup() => _importer.createBackup();

  Future<int> restoreBackup(String source) async {
    busy = true;
    lastError = null;
    notifyListeners();
    try {
      final restored = await _importer.restoreBackup(source);
      _refreshProfiles(notify: false);
      notifyListeners();
      return restored;
    } catch (error) {
      lastError = error.toString();
      notifyListeners();
      rethrow;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> testLatency() async {
    if (!isConnected) {
      lastError = 'برای تست تأخیر ابتدا متصل شو.';
      notifyListeners();
      return;
    }
    try {
      final autoGroup = groups.where((group) => group.type.toLowerCase() == 'urltest').toList();
      final target = autoGroup.isNotEmpty ? autoGroup.first.tag : FlutterSingBoxConstants.defaultGroup;
      await _engine.urlTest(groupTag: target);
    } catch (error) {
      lastError = 'تست تأخیر ناموفق بود: $error';
      notifyListeners();
    }
  }

  Future<void> selectOutbound({required String groupTag, required String outboundTag}) async {
    try {
      await _engine.selectOutbound(groupTag: groupTag, outboundTag: outboundTag);
    } catch (error) {
      lastError = 'انتخاب مسیر انجام نشد: $error';
      notifyListeners();
    }
  }

  void clearError() {
    lastError = null;
    notifyListeners();
  }

  void clearLogs() {
    logs = <ClientLog>[];
    notifyListeners();
  }

  @override
  void dispose() {
    _stateSubscription?.cancel();
    _statusSubscription?.cancel();
    _groupSubscription?.cancel();
    _logSubscription?.cancel();
    super.dispose();
  }
}

String formatBytes(num? bytes) {
  if (bytes == null || bytes <= 0) return '۰ بایت';
  const units = <String>['B', 'KB', 'MB', 'GB', 'TB'];
  var value = bytes.toDouble();
  var unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  final digits = value >= 100 ? 0 : (value >= 10 ? 1 : 2);
  return '${value.toStringAsFixed(digits)} ${units[unit]}';
}

String formatSpeed(num? bytesPerSecond) {
  if (bytesPerSecond == null || bytesPerSecond <= 0) return '۰ B/s';
  const units = <String>['B/s', 'KB/s', 'MB/s', 'GB/s'];
  var value = bytesPerSecond.toDouble();
  var unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  return '${value.toStringAsFixed(value >= 100 ? 0 : 1)} ${units[unit]}';
}
