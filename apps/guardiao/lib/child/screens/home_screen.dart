import 'dart:async';

import 'package:flutter/material.dart';
import 'package:guardiao_core/guardiao_core.dart';

import '../platform/installed_apps_source.dart';
import '../sync/device_sync.dart';
import '../usage/usage_controller.dart';
import '../usage/usage_monitor.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.backend,
    required this.source,
    required this.monitor,
    required this.device,
  });

  final GuardianBackend backend;
  final InstalledAppsSource source;
  final UsageMonitor monitor;
  final PairedDevice device;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final DeviceSync _sync;
  late final UsageController _usage;
  StreamSubscription<List<InstalledApp>>? _appsSub;
  StreamSubscription<Map<String, AppRule>>? _rulesSub;
  StreamSubscription<String>? _errors;
  List<InstalledApp> _apps = const [];
  Map<String, AppRule> _rules = const {};
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
    _usage =
        UsageController(
          backend: widget.backend,
          monitor: widget.monitor,
          platform: widget.source.platform,
        )..addListener(() {
          if (mounted) setState(() {});
        });
    _appsSub = widget.backend.watchOwnApps().listen((apps) {
      _apps = apps;
      _usage.update(_apps, _rules);
      if (mounted) setState(() {});
    });
    _rulesSub = widget.backend.watchOwnRules().listen((rules) {
      _rules = rules;
      _usage.update(_apps, _rules);
      if (mounted) setState(() {});
    });
    _usage.begin();
  }

  @override
  void dispose() {
    _errors?.cancel();
    _appsSub?.cancel();
    _rulesSub?.cancel();
    _usage.dispose();
    _sync.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Guardião')),
      body: SafeArea(child: _buildList(context)),
    );
  }

  Widget _buildList(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final apps = _apps;
    final rules = _rules;
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
        if (!_usage.supported)
          const Notice(
            'Este aparelho ainda não mede o tempo de uso. Os limites aparecem, '
            'mas o tempo restante não diminui.',
            icon: Icons.hourglass_empty,
          )
        else if (_usage.missing.isNotEmpty)
          _PermissionsCard(missing: _usage.missing, onRequest: _usage.request),
        if (_syncError != null) ...[
          const SizedBox(height: 8),
          Notice(_syncError!, isError: true),
        ],
        if (_usage.reportError != null) ...[
          const SizedBox(height: 8),
          Notice(_usage.reportError!, isError: true),
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
            _LimitedTile(
              app: app,
              rule: rules[app.id]!,
              used: _usage.usedMinutes(app.id),
            ),
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
              subtitle: _usage.usedMinutes(app.id) > 0
                  ? Text('Hoje: ${formatMinutes(_usage.usedMinutes(app.id))}')
                  : null,
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
        if (widget.device.parentLabel != null) ...[
          const SizedBox(height: 4),
          Text(
            'Responsável: ${widget.device.parentLabel}',
            key: const Key('parentLabel'),
            style: text.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }
}

/// Pede, uma a uma, as permissões especiais do Android.
class _PermissionsCard extends StatelessWidget {
  const _PermissionsCard({required this.missing, required this.onRequest});

  final Set<MonitorPermission> missing;
  final Future<void> Function(MonitorPermission) onRequest;

  static const _info = {
    MonitorPermission.usageAccess: (
      'Liberar acesso ao uso',
      'Sem isso o Android não conta quanto tempo cada app foi usado.',
    ),
    MonitorPermission.overlay: (
      'Permitir aparecer sobre outros apps',
      'Para avisar e cobrir o jogo quando o tempo acabar.',
    ),
    MonitorPermission.notifications: (
      'Permitir avisos',
      'Mostra que o Guardião está ativo.',
    ),
  };

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Card(
      key: const Key('permissionsCard'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Falta liberar no Android', style: text.titleMedium),
            const SizedBox(height: 4),
            Text(
              'Para contar o tempo e bloquear, o app precisa destas permissões:',
              style: text.bodySmall,
            ),
            for (final p in MonitorPermission.values)
              if (missing.contains(p)) ...[
                const SizedBox(height: 12),
                Text(_info[p]!.$2, style: text.bodyMedium),
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton.tonal(
                    key: Key('permission_${p.name}'),
                    onPressed: () => onRequest(p),
                    child: Text(_info[p]!.$1),
                  ),
                ),
              ],
          ],
        ),
      ),
    );
  }
}

class _LimitedTile extends StatelessWidget {
  const _LimitedTile({
    required this.app,
    required this.rule,
    required this.used,
  });

  final InstalledApp app;
  final AppRule rule;
  final int used;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final left = rule.remainingMinutes(used);
    final blocked = rule.blocked || left == 0;
    final limit = rule.dailyLimitMinutes;

    final subtitle = rule.blocked
        ? 'Bloqueado pelo responsável'
        : (limit == null
              ? 'Usou ${formatMinutes(used)} hoje'
              : 'Usou ${formatMinutes(used)} de ${formatMinutes(limit)} hoje');
    final progress = (limit == null || limit == 0)
        ? 0.0
        : (used / limit).clamp(0.0, 1.0);

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
                      Text(
                        app.name,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                Chip(
                  label: Text(
                    blocked ? 'Bloqueado' : '${formatMinutes(left)} restantes',
                  ),
                  backgroundColor: blocked
                      ? scheme.errorContainer
                      : scheme.secondaryContainer,
                  side: BorderSide.none,
                ),
              ],
            ),
            if (!rule.blocked && limit != null) ...[
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: progress,
                borderRadius: BorderRadius.circular(4),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
