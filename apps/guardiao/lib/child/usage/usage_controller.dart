import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:guardiao_core/guardiao_core.dart';

import 'usage_monitor.dart';

/// Liga o medidor do aparelho às regras da nuvem e devolve o uso medido ao
/// responsável. Quem desenha a tela só escuta este objeto.
class UsageController extends ChangeNotifier {
  UsageController({
    required this.backend,
    required this.monitor,
    required this.platform,
    this.pollEvery = const Duration(seconds: 30),
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final GuardianBackend backend;
  final UsageMonitor monitor;
  final DevicePlatform platform;
  final Duration pollEvery;
  final DateTime Function() _clock;

  Timer? _timer;
  bool _disposed = false;
  List<InstalledApp> _apps = const [];
  Map<String, AppRule> _rules = const {};
  List<MonitoredApp>? _pushed;
  bool _pushedWithAccess = false;
  bool _busy = false;

  bool get supported => monitor.supported;

  /// Permissões que faltam (vazio quando está tudo liberado).
  Set<MonitorPermission> missing = const {};

  /// Minutos usados hoje, por `appId`.
  Map<String, int> usedByAppId = const {};

  /// Último problema ao enviar o uso ao responsável, se houve.
  String? reportError;

  int usedMinutes(String appId) => usedByAppId[appId] ?? 0;

  void begin() {
    unawaited(refresh());
    _timer = Timer.periodic(pollEvery, (_) => unawaited(refresh()));
  }

  /// Chamado sempre que a lista de apps ou as regras mudam.
  void update(List<InstalledApp> apps, Map<String, AppRule> rules) {
    _apps = apps;
    _rules = rules;
    unawaited(refresh());
  }

  Future<void> request(MonitorPermission permission) async {
    await monitor.request(permission);
    await refresh();
  }

  /// Confere permissões, aplica as regras, lê o uso e envia ao responsável.
  Future<void> refresh() async {
    if (_busy || _disposed || !supported) return;
    _busy = true;
    try {
      missing = await monitor.missingPermissions();
      final hasAccess = !missing.contains(MonitorPermission.usageAccess);
      final wanted = buildMonitored(_apps, _rules, platform);
      if (_pushed == null ||
          !listEquals(_pushed, wanted) ||
          (hasAccess && !_pushedWithAccess)) {
        await monitor.start(wanted);
        _pushed = wanted;
        _pushedWithAccess = hasAccess;
      }
      final byKey = await monitor.usageByKey();
      final used = <String, int>{};
      for (final app in _apps) {
        final key = monitorKey(app, platform);
        final minutes = key == null ? null : byKey[key];
        if (minutes != null && minutes > 0) used[app.id] = minutes;
      }
      usedByAppId = used;
      if (!_disposed) notifyListeners();
      await _report(used);
    } catch (e) {
      reportError = 'Não foi possível medir o tempo de uso: $e';
      if (!_disposed) notifyListeners();
    } finally {
      _busy = false;
    }
  }

  Future<void> _report(Map<String, int> used) async {
    if (used.isEmpty) return;
    try {
      await backend.reportUsage(dayKey(_clock()), used);
      if (reportError != null) {
        reportError = null;
        if (!_disposed) notifyListeners();
      }
    } catch (e) {
      reportError = 'Não foi possível enviar o tempo de uso ao responsável: $e';
      if (!_disposed) notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    super.dispose();
  }
}
