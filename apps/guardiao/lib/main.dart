import 'package:flutter/material.dart';
import 'package:guardiao_core/guardiao_core.dart';

import 'app.dart';
import 'child/platform/installed_apps_source.dart';
import 'child/usage/usage_monitor.dart';
import 'common/pin.dart';
import 'qr/qr_scanner.dart';
import 'role/role.dart';
import 'update/update_controller.dart';
import 'update/update_installer.dart';
import 'update/update_source.dart';
import 'watch/background_tasks.dart';
import 'watch/health_source.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final setup = await createBackend();
  final roleStore = SharedPrefsRoleStore();
  final updates = UpdateController(
    source: GithubUpdateSource(),
    installer: UpdateInstaller.detect(),
  )..begin();
  runApp(
    GuardiaoApp(
      backend: setup.backend,
      roleStore: roleStore,
      source: InstalledAppsSource.detect(),
      monitor: UsageMonitor.detect(),
      scanner: QrScanner.detect(),
      initialRole: await roleStore.read(),
      isDemo: setup.isDemo,
      showWelcome: true,
      updates: updates,
      background: BackgroundTasks.detect(),
      healthSource: HealthSource.detect(),
      healthStore: const PrefsHealthStore(),
      pinStore: const PrefsPinStore(),
    ),
  );
}
