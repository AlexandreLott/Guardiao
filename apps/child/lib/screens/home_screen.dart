import 'dart:async';

import 'package:flutter/material.dart';
import 'package:guardiao_core/guardiao_core.dart';

import '../platform/installed_apps_source.dart';
import '../sync/device_sync.dart';

/// Tempo de uso de hoje por aplicativo, em minutos.
///
/// A medição real (Android: estatísticas de uso; Windows: janela em primeiro
/// plano) é o próximo marco. Por enquanto nenhum uso é contado.
int usedMinutesToday(String appId) => 0;

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.backend,
    required this.source,
    required this.device,
  });

  final GuardianBackend backend;
  final InstalledAppsSource source;
  final PairedDevice device;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final DeviceSync _sync;
  late final Stream<List<InstalledApp>> _apps;
  late final Stream<Map<String, AppRule>> _rules;
  StreamSubscription<String>? _errors;
  String? _syncError;
  DateTime? _lastSync;

  @override
  void initState() {
    super.initState();
    _sync = DeviceSync(widget.backend, widget.source)..start();
    _errors = _sync.errors.stream.listen((e) => setState(() => _syncError = e));
    _sync.lastSync.stream.listen((t) {
      if (mounted) {
        setState(() {
          _lastSync = t;
          _syncError = null;
        });
      }
    });
    _apps = widget.backend.watchOwnApps();
    _rules = widget.backend.watchOwnRules();
  }

  @override
  void dispose() {
    _errors?.cancel();
    _sync.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Guardião Gamer')),
      body: SafeArea(
        child: StreamBuilder<List<InstalledApp>>(
          stream: _apps,
          builder: (context, appsSnap) {
            return StreamBuilder<Map<String, AppRule>>(
              stream: _rules,
              builder: (context, rulesSnap) {
                final apps = appsSnap.data ?? const <InstalledApp>[];
                final rules = rulesSnap.data ?? const <String, AppRule>{};
                final limited = [
                  for (final a in apps)
                    if (rules[a.id] != null) a,
                ];
                final free = [
                  for (final a in apps)
                    if (rules[a.id] == null) a,
                ];
                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text('Seu tempo de hoje', style: text.headlineSmall),
                    const SizedBox(height: 4),
                    Text(
                      'Aqui você vê quanto tempo ainda pode usar cada aplicativo.',
                      style: text.bodyMedium,
                    ),
                    const SizedBox(height: 12),
                    const Notice(
                      'A contagem do tempo de uso ainda não está ativa nesta '
                      'versão. Os limites já aparecem, mas o tempo restante '
                      'ainda não diminui.',
                      icon: Icons.hourglass_empty,
                    ),
                    if (_syncError != null) ...[
                      const SizedBox(height: 8),
                      Notice(_syncError!, isError: true),
                    ],
                    const SizedBox(height: 16),
                    if (limited.isEmpty)
                      const Card(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Text(
                            'O responsável ainda não definiu limites. '
                            'Quando definir, eles aparecem aqui.',
                          ),
                        ),
                      )
                    else
                      for (final app in limited)
                        _LimitedTile(app: app, rule: rules[app.id]!),
                    if (free.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Text('Sem limite (${free.length})', style: text.titleMedium),
                      const SizedBox(height: 8),
                      for (final app in free)
                        ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: AppAvatar(app, size: 32),
                          title: Text(app.name),
                        ),
                    ],
                    const SizedBox(height: 24),
                    Text(
                      _lastSync == null
                          ? 'Enviando a lista de apps para o responsável...'
                          : 'Lista de apps enviada ao responsável.',
                      style: text.bodySmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Aparelho: ${widget.device.name} (${widget.device.platform.label})',
                      style: text.bodySmall,
                      textAlign: TextAlign.center,
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _LimitedTile extends StatelessWidget {
  const _LimitedTile({required this.app, required this.rule});

  final InstalledApp app;
  final AppRule rule;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final used = usedMinutesToday(app.id);
    final left = rule.remainingMinutes(used);
    final blocked = rule.blocked || left == 0;
    final limit = rule.dailyLimitMinutes;

    final subtitle = rule.blocked
        ? 'Bloqueado pelo responsável'
        : 'Limite de hoje: ${formatMinutes(limit)}';
    final progress = (limit == null || limit == 0) ? 0.0 : (used / limit).clamp(0.0, 1.0);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                AppAvatar(app),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(app.name, style: Theme.of(context).textTheme.titleMedium),
                      Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
                Chip(
                  label: Text(blocked ? 'Bloqueado' : '${formatMinutes(left)} restantes'),
                  backgroundColor:
                      blocked ? scheme.errorContainer : scheme.secondaryContainer,
                  side: BorderSide.none,
                ),
              ],
            ),
            if (!rule.blocked && limit != null) ...[
              const SizedBox(height: 8),
              LinearProgressIndicator(value: progress, borderRadius: BorderRadius.circular(4)),
            ],
          ],
        ),
      ),
    );
  }
}
