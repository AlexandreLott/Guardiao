import 'package:flutter/material.dart';
import 'package:guardiao_core/guardiao_core.dart';

import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final setup = await createBackend(seedParentDevice: true);
  runApp(ParentApp(backend: setup.backend, isDemo: setup.isDemo));
}
