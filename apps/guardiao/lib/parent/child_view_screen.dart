import 'dart:async';

import 'package:flutter/material.dart';
import 'package:guardiao_core/guardiao_core.dart';

import '../child/screens/child_credits_tab.dart';
import '../child/screens/child_home_tab.dart';
import '../child/screens/child_report_tab.dart';
import '../child/screens/home_screen.dart' show ChildData;
import '../common/names.dart';
import '../common/pin.dart';
import 'device_screen.dart';

/// O aparelho de um filho visto pelo responsável: as mesmas telas que a
/// criança vê (Início, Relatório e Créditos) e, na aba Responsável, o painel
/// de limites, rotinas e créditos, que só abre com o PIN.
class ChildViewScreen extends StatefulWidget {
  const ChildViewScreen({
    super.key,
    required this.backend,
    required this.device,
    required this.pinStore,
    this.onChangeRole,
    this.isDemo = false,
  });

  final GuardianBackend backend;
  final PairedDevice device;
  final PinStore pinStore;
  final VoidCallback? onChangeRole;
  final bool isDemo;

  @override
  State<ChildViewScreen> createState() => _ChildViewScreenState();
}

class _ChildViewScreenState extends State<ChildViewScreen> {
  final _subs = <StreamSubscription<Object?>>[];
  late PairedDevice _device = widget.device;
  List<InstalledApp> _apps = const [];
  Map<String, AppRule> _rules = const {};
  DeviceConfig _config = const DeviceConfig();
  List<Claim> _claims = const [];
  List<UsageEntry> _usage = const [];
  int _tab = 0;
  bool _unlocked = false;

  String get _id => widget.device.id;

  @override
  void initState() {
    super.initState();
    final b = widget.backend;
    void listen<T>(Stream<T> stream, void Function(T) onData) {
      _subs.add(
        stream.listen((v) {
          if (mounted) setState(() => onData(v));
        }, onError: (Object _) {}),
      );
    }

    listen<List<PairedDevice>>(b.watchDevices(), (list) {
      _device = list.firstWhere((d) => d.id == _id, orElse: () => _device);
    });
    listen<List<InstalledApp>>(b.watchApps(_id), (v) => _apps = v);
    listen<Map<String, AppRule>>(b.watchRules(_id), (v) => _rules = v);
    listen<DeviceConfig>(b.watchConfig(_id), (v) => _config = v);
    listen<List<Claim>>(b.watchClaims(_id), (v) => _claims = v);
    listen<List<UsageEntry>>(
      b.watchUsage(
        _id,
        sinceDay: dayKey(DateTime.now().subtract(const Duration(days: 60))),
      ),
      (v) => _usage = v,
    );
    if (widget.isDemo) unawaited(_demoPin());
  }

  /// No modo demonstração o PIN já vem pronto (1234), como no lado do filho.
  Future<void> _demoPin() async {
    if (!await widget.pinStore.hasPin()) await widget.pinStore.set('1234');
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    for (final s in _subs) {
      unawaited(s.cancel());
    }
    super.dispose();
  }

  static const _items = [
    GNavItem('Início', Icons.home_rounded, Key('nav_home')),
    GNavItem('Relatório', Icons.bar_chart_rounded, Key('nav_report')),
    GNavItem('Créditos', Icons.star_border_rounded, Key('nav_credits')),
    GNavItem('Responsável', Icons.lock_outline, Key('nav_guardian')),
  ];

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = dayKey(now);
    final data = ChildData(
      device: _device,
      apps: _apps,
      rules: _rules,
      config: _config,
      claims: _claims,
      usage: _usage,
      usedToday: {
        for (final e in _usage)
          if (e.day == today) e.appId: e.minutes,
      },
      now: now,
    );
    final tabs = <Widget>[
      ChildHomeTab(data: data),
      ChildReportTab(data: data),
      ChildCreditsTab(data: data),
      _unlocked
          ? DeviceScreen(
              backend: widget.backend,
              device: _device,
              onChangeRole: widget.onChangeRole,
              embedded: true,
            )
          : _PinGate(
              store: widget.pinStore,
              isDemo: widget.isDemo,
              onUnlocked: () => setState(() => _unlocked = true),
            ),
    ];
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Row(
              children: [
                IconButton(
                  key: const Key('panelBack'),
                  tooltip: 'Voltar',
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: const Icon(Icons.chevron_left, size: 28),
                ),
                Expanded(
                  child: GHeader(
                    userName: childName(_device.name),
                    online: _device.isOnline(now),
                  ),
                ),
              ],
            ),
            Expanded(
              child: GSwitch(
                child: KeyedSubtree(
                  key: ValueKey('$_tab$_unlocked'),
                  child: tabs[_tab],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: GNavBar(
        items: _items,
        index: _tab,
        onChanged: (i) => setState(() {
          // Sair da aba Responsável tranca o painel de novo.
          if (_tab == 3 && i != 3) _unlocked = false;
          _tab = i;
        }),
      ),
    );
  }
}

/// Pede o PIN (ou cria um, na primeira vez) antes de abrir o painel.
class _PinGate extends StatefulWidget {
  const _PinGate({
    required this.store,
    required this.onUnlocked,
    this.isDemo = false,
  });

  final PinStore store;
  final VoidCallback onUnlocked;
  final bool isDemo;

  @override
  State<_PinGate> createState() => _PinGateState();
}

class _PinGateState extends State<_PinGate> {
  bool? _hasPin;

  @override
  void initState() {
    super.initState();
    _check();
  }

  @override
  void didUpdateWidget(covariant _PinGate old) {
    super.didUpdateWidget(old);
    if (_hasPin != true) _check();
  }

  void _check() {
    widget.store.hasPin().then((v) {
      if (mounted && v != _hasPin) setState(() => _hasPin = v);
    });
  }

  @override
  Widget build(BuildContext context) {
    final hasPin = _hasPin;
    if (hasPin == null) return const SizedBox.shrink();
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: hasPin
            ? PinPad(
                key: const Key('enterPin'),
                title: 'Painel do responsável',
                subtitle: 'Digite o PIN para acessar',
                hint: widget.isDemo ? 'PIN de demonstração: 1234' : null,
                onSubmit: (pin) async {
                  if (await widget.store.verify(pin)) {
                    widget.onUnlocked();
                    return null;
                  }
                  return 'PIN incorreto.';
                },
              )
            : PinPad(
                key: const Key('createPin'),
                title: 'Crie um PIN',
                subtitle: 'Só o responsável deve saber. São 4 números.',
                onSubmit: (pin) async {
                  await widget.store.set(pin);
                  widget.onUnlocked();
                  return null;
                },
              ),
      ),
    );
  }
}
