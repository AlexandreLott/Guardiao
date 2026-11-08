import 'package:flutter/material.dart';
import 'package:guardiao_core/guardiao_core.dart';

import 'app.dart';
import 'child/platform/installed_apps_source.dart';
import 'child/usage/usage_monitor.dart';
import 'nearby/nearby.dart';
import 'role/role.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final setup = await createBackend();
  final roleStore = SharedPrefsRoleStore();
  runApp(GuardiaoApp(
    backend: setup.backend,
    roleStore: roleStore,
    source: InstalledAppsSource.detect(),
    monitor: UsageMonitor.detect(),
    nearby: setup.isDemo ? UnsupportedNearby() : NearbyPairing.detect(),
    initialRole: await roleStore.read(),
    isDemo: setup.isDemo,
  ));
}
