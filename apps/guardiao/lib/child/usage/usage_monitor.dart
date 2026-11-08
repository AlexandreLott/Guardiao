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
  });

  /// Identificador na nuvem (o mesmo de [InstalledApp.id] e [AppRule.appId]).
  final String appId;

  /// Como o sistema chama o app: pacote no Android, nome do .exe no Windows.
  final String key;
  final String name;
  final int? limitMinutes;
  final bool blocked;

  Map<String, Object?> toJson() => {
        'pkg': key,
        'name': name,
        'limit': limitMinutes,
        'blocked': blocked,
      };

  @override
  bool operator ==(Object other) =>
      other is MonitoredApp &&
      other.appId == appId &&
      other.key == key &&
      other.name == name &&
      other.limitMinutes == limitMinutes &&
      other.blocked == blocked;

  @override
  int get hashCode => Object.hash(appId, key, name, limitMinutes, blocked);
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

/// Junta a lista de apps com as regras e devolve só o que precisa de vigilância.
List<MonitoredApp> buildMonitored(
  List<InstalledApp> apps,
  Map<String, AppRule> rules,
  DevicePlatform platform,
) {
  final out = <MonitoredApp>[];
  for (final app in apps) {
    final rule = rules[app.id];
    if (rule == null || rule.isDefault) continue;
    final key = monitorKey(app, platform);
    if (key == null) continue;
    out.add(MonitoredApp(
      appId: app.id,
      key: key,
      name: app.name,
      limitMinutes: rule.dailyLimitMinutes,
      blocked: rule.blocked,
    ));
  }
  return out;
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
  Future<void> start(List<MonitoredApp> apps);

  /// Minutos usados hoje, por chave (veja [monitorKey]).
  Future<Map<String, int>> usageByKey();

  Future<void> stop();

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
  Future<void> start(List<MonitoredApp> apps) async {}

  @override
  Future<Map<String, int>> usageByKey() async => const {};

  @override
  Future<void> stop() async {}
}

/// Medidor de mentira para a demonstração e para testes: o uso só muda
/// quando alguém chama [simulate].
class DemoUsageMonitor implements UsageMonitor {
  DemoUsageMonitor({Set<MonitorPermission> missing = const {}}) : _missing = {...missing};

  final Set<MonitorPermission> _missing;
  final Map<String, int> _usage = {};

  /// Última lista recebida em [start].
  List<MonitoredApp> started = const [];
  int startCalls = 0;
  bool stopped = false;

  void simulate(String key, int minutes) =>
      _usage[key] = (_usage[key] ?? 0) + minutes;

  void grant(MonitorPermission p) => _missing.remove(p);

  @override
  bool get supported => true;

  @override
  Future<Set<MonitorPermission>> missingPermissions() async => {..._missing};

  /// No teste, "abrir a tela do sistema" já libera.
  @override
  Future<void> request(MonitorPermission permission) async => _missing.remove(permission);

  @override
  Future<void> start(List<MonitoredApp> apps) async {
    startCalls++;
    started = apps;
    stopped = false;
  }

  @override
  Future<Map<String, int>> usageByKey() async => {..._usage};

  @override
  Future<void> stop() async => stopped = true;
}
