import 'dart:async';
import 'dart:convert';

import 'package:guardiao_core/guardiao_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'usage_monitor.dart';
import 'windows_probe.dart';

/// Onde o tempo do dia fica guardado, para sobreviver a reinício do app.
abstract class UsageLedgerStore {
  Future<String?> read();
  Future<void> write(String json);
}

class SharedPrefsLedgerStore implements UsageLedgerStore {
  static const _key = 'usage_ledger';

  @override
  Future<String?> read() async => (await SharedPreferences.getInstance()).getString(_key);

  @override
  Future<void> write(String json) async =>
      (await SharedPreferences.getInstance()).setString(_key, json);
}

class MemoryLedgerStore implements UsageLedgerStore {
  String? value;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String json) async => value = json;
}

/// Mede o tempo no Windows olhando, a cada poucos segundos, qual programa está
/// na frente, e encerra o que passou do limite. Quando o aparelho fica parado
/// (sem teclado nem mouse) o tempo não conta.
class WindowsUsageMonitor implements UsageMonitor {
  WindowsUsageMonitor({
    required this.probe,
    UsageLedgerStore? store,
    DateTime Function()? clock,
    this.tick = const Duration(seconds: 2),
    this.idleAfter = const Duration(minutes: 2),
    this.ownExe = 'guardiao.exe',
  })  : _store = store ?? MemoryLedgerStore(),
        _clock = clock ?? DateTime.now;

  factory WindowsUsageMonitor.system() =>
      WindowsUsageMonitor(probe: WindowsProbe(), store: SharedPrefsLedgerStore());

  final SystemProbe probe;
  final UsageLedgerStore _store;
  final DateTime Function() _clock;
  final Duration tick;
  final Duration idleAfter;
  final String ownExe;

  Timer? _timer;
  bool _loaded = false;
  String _day = '';
  final Map<String, int> _millis = {};
  Map<String, MonitoredApp> _rules = {};
  DateTime? _last;
  int _ticksSinceSave = 0;

  @override
  bool get supported => true;

  @override
  Future<Set<MonitorPermission>> missingPermissions() async => const {};

  @override
  Future<void> request(MonitorPermission permission) async {}

  Future<void> _load() async {
    if (_loaded) return;
    _loaded = true;
    final raw = await _store.read();
    if (raw == null) return;
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      if (data['day'] == dayKey(_clock())) {
        _day = data['day'] as String;
        (data['millis'] as Map<String, dynamic>? ?? const {})
            .forEach((k, v) => _millis[k] = (v as num).toInt());
      }
    } catch (_) {
      // Arquivo estragado: começa do zero.
    }
  }

  @override
  Future<void> start(List<MonitoredApp> apps) async {
    await _load();
    _rules = {for (final a in apps) a.key.toLowerCase(): a};
    _last ??= _clock();
    _timer ??= Timer.periodic(tick, (_) => unawaited(poll()));
  }

  /// Uma passada de medição. Pública para os testes.
  Future<void> poll() async {
    final now = _clock();
    final today = dayKey(now);
    if (_day != today) {
      _day = today;
      _millis.clear();
    }
    final previous = _last ?? now;
    _last = now;
    // Se o app ficou parado (suspensão), não conta o buraco como uso.
    var elapsed = now.difference(previous).inMilliseconds;
    final maxStep = tick.inMilliseconds * 3;
    if (elapsed < 0) elapsed = 0;
    if (elapsed > maxStep) elapsed = maxStep;

    final exe = probe.foregroundExe()?.toLowerCase();
    if (exe == null || exe == ownExe) return;
    final idle = probe.idleSeconds();
    if (idle < idleAfter.inSeconds) {
      _millis[exe] = (_millis[exe] ?? 0) + elapsed;
      if (++_ticksSinceSave >= 15) {
        _ticksSinceSave = 0;
        unawaited(_save());
      }
    }
    final rule = _rules[exe];
    if (rule != null) {
      final minutes = (_millis[exe] ?? 0) ~/ 60000;
      if (rule.blocked ||
          (rule.limitMinutes != null && minutes >= rule.limitMinutes!)) {
        await probe.kill(exe);
      }
    }
  }

  Future<void> _save() => _store.write(jsonEncode({'day': _day, 'millis': _millis}));

  @override
  Future<Map<String, int>> usageByKey() async {
    await _load();
    return {
      for (final e in _millis.entries)
        if (e.value >= 60000) e.key: e.value ~/ 60000,
    };
  }

  @override
  Future<void> stop() async {
    _timer?.cancel();
    _timer = null;
    await _save();
  }
}
