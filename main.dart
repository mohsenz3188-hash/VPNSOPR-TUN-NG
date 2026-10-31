import 'package:flutter/material.dart';
import 'package:flutter_sing_box/flutter_sing_box.dart';
import 'package:mmkv/mmkv.dart';

import 'app.dart';
import 'core/vpn_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  String? startupError;

  try {
    await MMKV.initialize();
    await FlutterSingBox().init();
  } catch (error) {
    startupError = error.toString();
  }

  final controller = VpnController(startupError: startupError);
  await controller.initialize();
  runApp(VpnSoprApp(controller: controller));
}
