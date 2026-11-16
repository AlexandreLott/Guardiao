import 'dart:async';

import 'package:guardiao_core/guardiao_core.dart';

import '../child/usage/usage_controller.dart';
import '../child/usage/usage_monitor.dart';

/// Sincronização do aparelho do filho sem tela: ouve as regras, o bloqueio
/// geral, as rotinas e os créditos na nuvem e repassa ao serviço de bloqueio,
/// além de enviar o uso do dia ao responsável.
///
/// Antes isso só acontecia com a tela do app aberta; com o app fechado, uma
/// mudança feita pelo responsável (ligar o bloqueio geral, por exemplo) não
/// chegava ao aparelho.
class HeadlessSync {
  HeadlessSync({
    required this.backend,
    required UsageMonitor monitor,
    required DevicePlatform platform,
    Duration pollEvery = const Duration(seconds: 30),
  }) : _usage = UsageController(
         backend: backend,
         monitor: monitor,
         platform: platform,
         pollEvery: pollEvery,
       );

  final GuardianBackend backend;
  final UsageController _usage;
  final _subs = <StreamSubscription<Object?>>[];

  List<InstalledApp> _apps = const [];
  Map<String, AppRule> _rules = const {};
  DeviceConfig _config = const DeviceConfig();
  List<Claim> _claims = const [];

  void start() {
    void listen<T>(Stream<T> stream, void Function(T) onData) {
      _subs.add(
        stream.listen((v) {
          onData(v);
          _push();
        }, onError: (Object _) {}),
      );
    }

    listen<List<InstalledApp>>(backend.watchOwnApps(), (v) => _apps = v);
    listen<Map<String, AppRule>>(backend.watchOwnRules(), (v) => _rules = v);
    listen<DeviceConfig>(backend.watchOwnConfig(), (v) => _config = v);
    listen<List<Claim>>(backend.watchOwnClaims(), (v) => _claims = v);
    _usage.begin();
  }

  void _push() {
    _usage.update(
      _apps,
      _rules,
      config: _config,
      bonusMinutes: bonusMinutesOf(_claims, dayKey(DateTime.now())),
      credits: availableCredit(_claims),
    );
  }

  Future<void> stop() async {
    for (final s in _subs) {
      await s.cancel();
    }
    _usage.dispose();
  }
}
