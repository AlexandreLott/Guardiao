import 'dart:io';

import 'package:guardiao_core/guardiao_core.dart';

import 'android_usage_monitor.dart';
import 'windows_usage_monitor.dart';

/// Um aplicativo com regra, no formato que o medidor do aparelho entende.
class MonitoredApp {
  const MonitoredApp({
    required this.appId,
    required this.key,
    required this.name,
    this.limitMinutes,
    this.blocked = false,
    this.allowed = false,
    this.category = 'other',
  });

  /// Identificador na nuvem (o mesmo de [InstalledApp.id] e [AppRule.appId]).
  final String appId;

  /// Como o sistema chama o app: pacote no Android, nome do .exe no Windows.
  final String key;
  final String name;
  final int? limitMinutes;
  final bool blocked;

  /// "Sempre liberado": ignora o bloqueio geral e as rotinas.
  final bool allowed;

  /// `games`, `videos`, `social`, `study` ou `other` (veja [AppCategory]).
  final String category;

  Map<String, Object?> toJson() => {
    'pkg': key,
    'name': name,
    'limit': limitMinutes,
    'blocked': blocked,
    'allowed': allowed,
    'cat': category,
  };

  @override
  bool operator ==(Object other) =>
      other is MonitoredApp &&
      other.appId == appId &&
      other.key == key &&
      other.name == name &&
      other.limitMinutes == limitMinutes &&
      other.blocked == blocked &&
      other.allowed == allowed &&
      other.category == category;

  @override
  int get hashCode =>
      Object.hash(appId, key, name, limitMinutes, blocked, allowed, category);
}

/// Permissões especiais que o Android exige para medir e bloquear.
enum MonitorPermission {
  /// "Acesso ao uso": sem ele o Android não conta quem usou o quê.
  usageAccess,

  /// "Sobrepor a outros apps": necessário para cobrir o jogo bloqueado.
  overlay,

  /// Aviso fixo do serviço (Android 13+).
  notifications,
}

/// A chave com que o medidor reconhece [app] neste sistema, ou `null` se não
/// há como medir (por exemplo, programa do Windows sem .exe conhecido).
String? monitorKey(InstalledApp app, DevicePlatform platform) {
  switch (platform) {
    case DevicePlatform.android:
      return app.packageName ?? app.id;
    case DevicePlatform.windows:
      final exe = app.packageName?.trim().toLowerCase();
      return (exe == null || exe.isEmpty) ? null : exe;
    case DevicePlatform.other:
      return app.id;
  }
}

/// Junta a lista de apps com as regras e devolve só o que precisa de vigilância
/// (ou todos, se [includeAll]: com bloqueio geral ou rotinas, qualquer app pode
/// ser pausado).
List<MonitoredApp> buildMonitored(
  List<InstalledApp> apps,
  Map<String, AppRule> rules,
  DevicePlatform platform, {
  bool includeAll = false,
}) {
  final out = <MonitoredApp>[];
  for (final app in apps) {
    final rule = rules[app.id];
    if (!includeAll && (rule == null || rule.isDefault)) continue;
    final key = monitorKey(app, platform);
    if (key == null) continue;
    out.add(
      MonitoredApp(
        appId: app.id,
        key: key,
        name: app.name,
        limitMinutes: rule?.dailyLimitMinutes,
        blocked: rule?.blocked ?? false,
        allowed: rule?.alwaysAllowed ?? false,
        category: categoryOf(app).name,
      ),
    );
  }
  return out;
}

/// O que o medidor precisa além da lista de apps: bloqueio geral, rotinas e o
/// tempo extra ganho com créditos.
class MonitorExtras {
  const MonitorExtras({
    this.lockAll = false,
    this.routines = const [],
    this.bonusDay,
    this.bonusMinutes = 0,
    this.message = '',
  });

  final bool lockAll;
  final List<Routine> routines;

  /// Dia (`2026-11-10`) a que vale o [bonusMinutes].
  final String? bonusDay;
  final int bonusMinutes;

  /// Texto da tela de bloqueio escolhido pelo responsável.
  final String message;

  bool get needsEveryApp => lockAll || routines.any((r) => r.enabled);

  Map<String, Object?> toJson() => {
    'lockAll': lockAll,
    'routines': [for (final r in routines) r.toMap()],
    'bonusDay': bonusDay,
    'bonusMinutes': bonusMinutes,
    'message': message,
  };
}

/// Mede o tempo de uso de hoje e bloqueia o que passou do limite.
abstract class UsageMonitor {
  /// Falso onde não há como medir (o app mostra só os limites).
  bool get supported;

  /// Permissões que ainda faltam.
  Future<Set<MonitorPermission>> missingPermissions();

  /// Abre a tela do sistema (ou o pedido) para liberar [permission].
  Future<void> request(MonitorPermission permission);

  /// Passa as regras atuais e começa a vigiar. Pode ser chamado de novo a
  /// cada mudança de regra.
  Future<void> start(
    List<MonitoredApp> apps, {
    MonitorExtras extras = const MonitorExtras(),
  });

  /// Minutos usados hoje, por chave (veja [monitorKey]).
  Future<Map<String, int>> usageByKey();

  Future<void> stop();

  /// O Guardião é administrador do dispositivo (o Android exige desativar isso
  /// antes de desinstalar)? `null` onde o recurso não existe.
  Future<bool?> adminActive();

  /// Abre o pedido do sistema para ativar a proteção contra desinstalação.
  Future<void> requestAdmin();

  /// Aba que a tela de bloqueio pediu para abrir ("credits"), uma única vez.
  Future<String?> takeLaunchTab();

  factory UsageMonitor.detect() {
    if (Platform.isAndroid) return AndroidUsageMonitor();
    if (Platform.isWindows) return WindowsUsageMonitor.system();
    return UnsupportedUsageMonitor();
  }
}

class UnsupportedUsageMonitor implements UsageMonitor {
  @override
  bool get supported => false;

  @override
  Future<Set<MonitorPermission>> missingPermissions() async => const {};

  @override
  Future<void> request(MonitorPermission permission) async {}

  @override
  Future<void> start(
    List<MonitoredApp> apps, {
    MonitorExtras extras = const MonitorExtras(),
  }) async {}

  @override
  Future<Map<String, int>> usageByKey() async => const {};

  @override
  Future<void> stop() async {}

  @override
  Future<bool?> adminActive() async => null;

  @override
  Future<void> requestAdmin() async {}

  @override
  Future<String?> takeLaunchTab() async => null;
}

/// Medidor de mentira para a demonstração e para testes: o uso só muda
/// quando alguém chama [simulate].
class DemoUsageMonitor implements UsageMonitor {
  DemoUsageMonitor({
    Set<MonitorPermission> missing = const {},
    bool? adminActive,
  }) : _missing = {...missing},
       _admin = adminActive;

  bool? _admin;

  final Set<MonitorPermission> _missing;
  final Map<String, int> _usage = {};

  /// Última lista recebida em [start].
  List<MonitoredApp> started = const [];
  MonitorExtras startedExtras = const MonitorExtras();
  int startCalls = 0;
  bool stopped = false;

  void simulate(String key, int minutes) =>
      _usage[key] = (_usage[key] ?? 0) + minutes;

  void grant(MonitorPermission p) => _missing.remove(p);

  /// Simula o Android retirando uma permissão.
  void revoke(MonitorPermission p) => _missing.add(p);

  @override
  bool get supported => true;

  @override
  Future<Set<MonitorPermission>> missingPermissions() async => {..._missing};

  /// No teste, "abrir a tela do sistema" já libera.
  @override
  Future<void> request(MonitorPermission permission) async =>
      _missing.remove(permission);

  @override
  Future<void> start(
    List<MonitoredApp> apps, {
    MonitorExtras extras = const MonitorExtras(),
  }) async {
    startCalls++;
    started = apps;
    startedExtras = extras;
    stopped = false;
  }

  @override
  Future<Map<String, int>> usageByKey() async => {..._usage};

  @override
  Future<void> stop() async => stopped = true;

  @override
  Future<bool?> adminActive() async => _admin;

  /// No teste, "abrir o pedido do sistema" já ativa.
  @override
  Future<void> requestAdmin() async => _admin = true;

  /// Aba pedida pela tela de bloqueio (nos testes, defina antes de abrir).
  String? launchTab;

  @override
  Future<String?> takeLaunchTab() async {
    final tab = launchTab;
    launchTab = null;
    return tab;
  }
}
