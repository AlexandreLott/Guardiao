import 'dart:async';

import 'package:guardiao_core/guardiao_core.dart';

import '../platform/installed_apps_source.dart';

/// Mantém a nuvem em dia com o que há no aparelho: lista de apps e
/// "estou ativo". Roda enquanto o app do filho está aberto.
class DeviceSync {
  DeviceSync(this.backend, this.source,
      {this.appsEvery = const Duration(hours: 6),
      this.heartbeatEvery = const Duration(minutes: 10)});

  final GuardianBackend backend;
  final InstalledAppsSource source;
  final Duration appsEvery;
  final Duration heartbeatEvery;

  Timer? _apps;
  Timer? _beat;

  final lastSync = StreamController<DateTime>.broadcast();
  final errors = StreamController<String>.broadcast();

  void start() {
    unawaited(syncNow());
    _apps = Timer.periodic(appsEvery, (_) => unawaited(syncNow()));
    _beat = Timer.periodic(heartbeatEvery, (_) => unawaited(_touch()));
  }

  Future<void> syncNow() async {
    try {
      final apps = await source.list();
      await backend.syncInstalledApps(apps);
      await backend.touch();
      lastSync.add(DateTime.now());
    } catch (e) {
      errors.add('Não foi possível atualizar a lista de apps: $e');
    }
  }

  Future<void> _touch() async {
    try {
      await backend.touch();
    } catch (_) {
      // Sem internet agora; a próxima tentativa acontece no próximo ciclo.
    }
  }

  void dispose() {
    _apps?.cancel();
    _beat?.cancel();
    lastSync.close();
    errors.close();
  }
}
