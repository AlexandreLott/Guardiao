import 'dart:async';

import 'package:guardiao_core/guardiao_core.dart';

import '../../watch/child_watch.dart';
import '../platform/installed_apps_source.dart';

/// Mantém a nuvem em dia com o que há no aparelho: lista de apps e
/// "estou ativo". Roda enquanto o app do filho está aberto.
class DeviceSync {
  DeviceSync(
    this.backend,
    this.source, {
    this.health,
    this.appsEvery = const Duration(hours: 6),
    this.heartbeatEvery = const Duration(minutes: 10),
    this.healthEvery = const Duration(minutes: 2),
  });

  /// Confere as proteções e avisa o responsável do que foi retirado.
  final HealthReporter? health;
  final Duration healthEvery;

  final GuardianBackend backend;
  final InstalledAppsSource source;
  final Duration appsEvery;
  final Duration heartbeatEvery;

  Timer? _apps;
  Timer? _beat;
  Timer? _health;

  final lastSync = StreamController<DateTime>.broadcast();
  final errors = StreamController<String>.broadcast();

  void start() {
    unawaited(syncNow());
    _apps = Timer.periodic(appsEvery, (_) => unawaited(syncNow()));
    _beat = Timer.periodic(heartbeatEvery, (_) => unawaited(_touch()));
    if (health != null) {
      unawaited(_checkHealth());
      _health = Timer.periodic(healthEvery, (_) => unawaited(_checkHealth()));
    }
  }

  Future<void> _checkHealth() async {
    try {
      await health!.run();
    } catch (_) {
      // Sem internet agora; a próxima rodada tenta de novo.
    }
  }

  Future<void> syncNow() async {
    var step = 'lendo os apps do aparelho';
    try {
      final apps = await source.list();
      step = 'enviando ${apps.length} apps para a nuvem';
      await backend
          .syncInstalledApps(apps)
          .timeout(const Duration(seconds: 60));
      step = 'registrando o sinal de vida';
      await backend.touch().timeout(const Duration(seconds: 30));
      lastSync.add(DateTime.now());
    } catch (e) {
      errors.add('Não foi possível atualizar a lista de apps ($step): $e');
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
    _health?.cancel();
    lastSync.close();
    errors.close();
  }
}
