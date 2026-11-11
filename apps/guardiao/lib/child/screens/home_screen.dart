import 'dart:async';

import 'package:flutter/material.dart';
import 'package:guardiao_core/guardiao_core.dart';

import '../../common/names.dart';
import '../../common/pin.dart';
import '../../watch/child_watch.dart';
import '../../watch/health_source.dart';
import '../platform/installed_apps_source.dart';
import '../sync/device_sync.dart';
import '../usage/usage_controller.dart';
import '../usage/usage_monitor.dart';
import 'child_account_tab.dart';
import 'child_credits_tab.dart';
import 'child_home_tab.dart';
import 'child_report_tab.dart';

/// Tudo que as abas do filho mostram, num só lugar.
class ChildData {
  const ChildData({
    required this.device,
    required this.apps,
    required this.rules,
    required this.config,
    required this.claims,
    required this.usage,
    required this.usedToday,
    required this.now,
  });

  final PairedDevice device;
  final List<InstalledApp> apps;
  final Map<String, AppRule> rules;
  final DeviceConfig config;
  final List<Claim> claims;

  /// Uso dos últimos 60 dias.
  final List<UsageEntry> usage;

  /// Minutos usados hoje por app (medidos no aparelho, ou da nuvem).
  final Map<String, int> usedToday;
  final DateTime now;

  String get today => dayKey(now);
  int get bonus => bonusMinutesOf(claims, today);

  AppVerdict verdict(InstalledApp app) => verdictFor(
    app: app,
    rule: rules[app.id],
    usedMinutes: usedToday[app.id] ?? 0,
    config: config,
    now: now,
    bonusMinutes: bonus,
  );
}

/// Lado do filho depois do vínculo: Início, Relatório, Créditos e Responsável.
class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.backend,
    required this.source,
    required this.monitor,
    required this.device,
    this.healthSource,
    this.healthStore,
    this.pinStore,
    this.isDemo = false,
  });

  final HealthSource? healthSource;
  final HealthStore? healthStore;
  final PinStore? pinStore;
  final bool isDemo;

  final GuardianBackend backend;
  final InstalledAppsSource source;
  final UsageMonitor monitor;
  final PairedDevice device;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  late final DeviceSync _sync;
  late final UsageController _usage;
  late final PinStore _pin = widget.pinStore ?? MemoryPinStore();
  final _subs = <StreamSubscription<Object?>>[];
  Timer? _clock;
  List<InstalledApp> _apps = const [];
  Map<String, AppRule> _rules = const {};
  DeviceConfig _config = const DeviceConfig();
  List<Claim> _claims = const [];
  List<UsageEntry> _history = const [];
  String? _syncError;
  DateTime? _lastSync;
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final healthSource = widget.healthSource;
    _sync = DeviceSync(
      widget.backend,
      widget.source,
      health: healthSource == null
          ? null
          : HealthReporter(
              backend: widget.backend,
              source: healthSource,
              store: widget.healthStore ?? MemoryHealthStore(),
            ),
    )..start();
    _subs.add(
      _sync.errors.stream.listen((e) {
        if (mounted) setState(() => _syncError = e);
      }),
    );
    _subs.add(
      _sync.lastSync.stream.listen((t) {
        if (mounted) {
          setState(() {
            _lastSync = t;
            _syncError = null;
          });
        }
      }),
    );
    _usage =
        UsageController(
          backend: widget.backend,
          monitor: widget.monitor,
          platform: widget.source.platform,
        )..addListener(() {
          if (mounted) setState(() {});
        });
    _subs.add(
      widget.backend.watchOwnApps().listen((v) {
        _apps = v;
        _push();
      }),
    );
    _subs.add(
      widget.backend.watchOwnRules().listen((v) {
        _rules = v;
        _push();
      }),
    );
    _subs.add(
      widget.backend.watchOwnConfig().listen((v) {
        _config = v;
        _push();
      }),
    );
    _subs.add(
      widget.backend.watchOwnClaims().listen((v) {
        _claims = v;
        _push();
      }),
    );
    final since = dayKey(DateTime.now().subtract(const Duration(days: 60)));
    _subs.add(
      widget.backend.watchOwnUsage(sinceDay: since).listen((v) {
        if (mounted) setState(() => _history = v);
      }),
    );
    _usage.begin();
    // Mantém contagens regressivas e rotinas em dia.
    _clock = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
    unawaited(_checkLaunchTab());
    if (widget.isDemo) unawaited(_seedDemoPin());
  }

  Future<void> _seedDemoPin() async {
    if (!await _pin.hasPin()) await _pin.set('1234');
  }

  void _push() {
    _usage.update(
      _apps,
      _rules,
      config: _config,
      bonusMinutes: bonusMinutesOf(_claims, dayKey(DateTime.now())),
    );
    if (mounted) setState(() {});
  }

  /// A tela de bloqueio pode pedir a aba de créditos ("Fiz a tarefa!").
  Future<void> _checkLaunchTab() async {
    final tab = await widget.monitor.takeLaunchTab();
    if (tab == 'credits' && mounted) setState(() => _tab = 2);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_checkLaunchTab());
      // Ao voltar para o app, reenvia a lista de apps e o sinal de vida.
      unawaited(_sync.syncNow());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _clock?.cancel();
    for (final s in _subs) {
      s.cancel();
    }
    _usage.dispose();
    _sync.dispose();
    super.dispose();
  }

  ChildData _data() {
    // O uso medido no aparelho vale mais que o da nuvem (que chega com atraso).
    final now = DateTime.now();
    final today = dayKey(now);
    final cloud = {
      for (final e in _history)
        if (e.day == today) e.appId: e.minutes,
    };
    return ChildData(
      device: widget.device,
      apps: _apps,
      rules: _rules,
      config: _config,
      claims: _claims,
      usage: _history,
      usedToday: {...cloud, ..._usage.usedByAppId},
      now: now,
    );
  }

  static const _items = [
    GNavItem('Início', Icons.home_rounded, Key('nav_home')),
    GNavItem('Relatório', Icons.bar_chart_rounded, Key('nav_report')),
    GNavItem('Créditos', Icons.star_border_rounded, Key('nav_credits')),
    GNavItem('Responsável', Icons.lock_outline, Key('nav_guardian')),
  ];

  @override
  Widget build(BuildContext context) {
    final data = _data();
    final name = childName(widget.device.name);
    final online = widget.device.isOnline(data.now);
    final tabs = <Widget>[
      ChildHomeTab(
        data: data,
        usage: _usage,
        syncError: _syncError,
        lastSync: _lastSync,
      ),
      ChildReportTab(data: data),
      ChildCreditsTab(
        data: data,
        onClaim: (title, minutes) =>
            widget.backend.createClaim(title: title, minutes: minutes),
        onUse: (claims) async {
          for (final c in claims) {
            await widget.backend.useClaim(c.id, data.today);
          }
        },
      ),
      ChildAccountTab(
        data: data,
        usage: _usage,
        pinStore: _pin,
        isDemo: widget.isDemo,
      ),
    ];
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            GHeader(userName: name, online: online),
            Expanded(child: tabs[_tab]),
          ],
        ),
      ),
      bottomNavigationBar: GNavBar(
        items: _items,
        index: _tab,
        onChanged: (i) => setState(() => _tab = i),
      ),
    );
  }
}
