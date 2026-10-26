import 'package:flutter/material.dart';
import 'package:guardiao_core/guardiao_core.dart';

import 'app.dart';
import 'platform/installed_apps_source.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final setup = await createBackend(seedParentDevice: false);
  runApp(ChildApp(
    backend: setup.backend,
    source: InstalledAppsSource.detect(),
    isDemo: setup.isDemo,
  ));
}
