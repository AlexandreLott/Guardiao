import 'dart:async';

import 'package:flutter/material.dart';
import 'package:guardiao_core/guardiao_core.dart';

import '../common/names.dart';
import 'account_screen.dart';
import 'alerts_panel.dart';
import 'apps_tab.dart';
import 'credits_tab.dart';
import 'routines_tab.dart';
import 'summary_tab.dart';

/// Tudo que as abas do painel mostram sobre um aparelho de filho.
class PanelData {
  const PanelData({
    required this.device,
    required this.apps,
    required this.rules,
    required this.config,
    required this.claims,
    required this.usage,
    required this.alerts,
    required this.now,
  });

  final PairedDevice device;
  final List<InstalledApp> apps;
  final Map<String, AppRule> rules;
  final DeviceConfig config;
  final List<Claim> claims;

  /// Uso dos últimos 60 dias.
  final List<UsageEntry> usage;
  final List<TamperAlert> alerts;
  final DateTime now;

  String get today => dayKey(now);
  Map<String, int> get usedToday => {
    for (final e in usage)
      if (e.day == today) e.appId: e.minutes,
  };
  int get pendingClaims =>
      claims.where((c) => c.status == ClaimStatus.pending).length;
}

/// Painel do responsável para um aparelho: Resumo, Apps, Rotinas e Créditos.
class DeviceScreen extends StatefulWidget {
  const DeviceScreen({
    super.key,
    required this.backend,
    required this.device,
    this.onChangeRole,
  });

  final GuardianBackend backend;
  final PairedDevice device;
  final VoidCallback? onChangeRole;

  @override
  State<DeviceScreen> createState() => _DeviceScreenState();
}

class _DeviceScreenState extends State<DeviceScreen> {
  final _subs = <StreamSubscription<Object?>>[];
  late PairedDevice _device = widget.device;
  List<InstalledApp>? _apps;
  Map<String, AppRule>? _rules;
  DeviceConfig _config = const DeviceConfig();
  List<Claim> _claims = const [];
  List<UsageEntry> _usage = const [];
  List<TamperAlert> _alerts = const [];
  Object? _error;
  int _tab = 0;

  GuardianBackend get _backend => widget.backend;
  String get _id => widget.device.id;

  @override
  void initState() {
    super.initState();
    void listen<T>(Stream<T> stream, void Function(T) onData) {
      _subs.add(
        stream.listen(
          (v) {
            if (mounted) setState(() => onData(v));
          },
          onError: (Object e) {
            if (mounted) setState(() => _error = e);
          },
        ),
      );
    }

    listen<List<PairedDevice>>(_backend.watchDevices(), (list) {
      _device = list.firstWhere((d) => d.id == _id, orElse: () => _device);
    });
    listen<List<InstalledApp>>(_backend.watchApps(_id), (v) => _apps = v);
    listen<Map<String, AppRule>>(_backend.watchRules(_id), (v) => _rules = v);
    listen<DeviceConfig>(_backend.watchConfig(_id), (v) => _config = v);
    listen<List<Claim>>(_backend.watchClaims(_id), (v) => _claims = v);
    listen<List<TamperAlert>>(_backend.watchAlerts(_id), (v) => _alerts = v);
    listen<List<UsageEntry>>(
      _backend.watchUsage(
        _id,
        sinceDay: dayKey(DateTime.now().subtract(const Duration(days: 60))),
      ),
      (v) => _usage = v,
    );
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    super.dispose();
  }

  Future<void> _save(DeviceConfig config) async {
    setState(() => _config = config);
    try {
      await _backend.saveConfig(_id, config);
    } catch (e) {
      _toast('Não foi possível salvar: $e');
    }
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _saveRule(AppRule rule) async {
    try {
      await _backend.setRule(_id, rule);
    } catch (e) {
      _toast('Não foi possível salvar: $e');
    }
  }

  Future<void> _remove() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remover aparelho?'),
        content: Text(
          '"${_device.name}" deixa de ser monitorado e perde os limites '
          'definidos. Para voltar, será preciso vincular de novo.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remover'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _backend.removeDevice(_id);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      _toast('Não foi possível remover: $e');
    }
  }

  void _openAccount() => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => AccountScreen(
        backend: _backend,
        device: _device,
        onChangeRole: widget.onChangeRole,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Notice(
            'Não foi possível carregar os dados do aparelho. $_error',
            isError: true,
          ),
        ),
      );
    }
    final data = PanelData(
      device: _device,
      apps: _apps ?? const [],
      rules: _rules ?? const {},
      config: _config,
      claims: _claims,
      usage: _usage,
      alerts: _alerts,
      now: DateTime.now(),
    );
    final loading = _apps == null || _rules == null;
    final pending = data.pendingClaims;
    final tabs = <Widget>[
      SummaryTab(
        data: data,
        onLockAll: (v) => _save(_config.copyWith(lockAll: v)),
        onGoTab: (i) => setState(() => _tab = i),
        onMarkSeen: () => _backend.markAlertsSeen(_id),
        onRemove: _remove,
        onAccount: _openAccount,
      ),
      AppsTab(data: data, onRule: _saveRule),
      RoutinesTab(data: data, onSave: _save),
      CreditsTab(
        data: data,
        onSave: _save,
        onDecide: (claim, ok) => _backend.decideClaim(_id, claim.id, ok),
      ),
    ];
    return Scaffold(
      body: SafeArea(
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
                    online: _device.isOnline(data.now),
                  ),
                ),
              ],
            ),
            const GTitle(
              'Painel do responsável',
              subtitle: 'Limites, rotinas e créditos',
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: GSegmented(
                labels: const ['Resumo', 'Apps', 'Rotinas', 'Créditos'],
                icons: const [
                  Icons.groups_outlined,
                  Icons.smartphone,
                  Icons.schedule,
                  Icons.star_border_rounded,
                ],
                badges: {3: pending},
                index: _tab,
                onChanged: (i) => setState(() => _tab = i),
              ),
            ),
            Expanded(
              child: loading
                  ? const Center(child: CircularProgressIndicator())
                  : tabs[_tab],
            ),
          ],
        ),
      ),
    );
  }
}

/// Barra de alertas no topo do Resumo.
Widget alertsFor(PanelData data, Future<void> Function() onMarkSeen) =>
    AlertsPanel(
      device: data.device,
      alerts: data.alerts,
      onMarkSeen: onMarkSeen,
    );
