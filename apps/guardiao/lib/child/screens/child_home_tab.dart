import 'package:flutter/material.dart';
import 'package:guardiao_core/guardiao_core.dart';

import '../../common/names.dart';
import '../usage/usage_controller.dart';
import '../usage/usage_monitor.dart';
import 'home_screen.dart';

/// "Início": quanto tempo de tela hoje e como está cada jogo monitorado.
class ChildHomeTab extends StatelessWidget {
  const ChildHomeTab({
    super.key,
    required this.data,
    required this.usage,
    this.syncError,
    this.lastSync,
  });

  final ChildData data;
  final UsageController usage;
  final String? syncError;
  final DateTime? lastSync;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final name = childName(data.device.name);
    final watched = [
      for (final a in data.apps)
        if (data.rules[a.id] != null &&
            (data.rules[a.id]!.blocked ||
                data.rules[a.id]!.dailyLimitMinutes != null))
          a,
    ];
    final free = [
      for (final a in data.apps)
        if (!watched.contains(a)) a,
    ];
    final totalUsed = data.usedToday.values.fold(0, (a, b) => a + b);
    final combined = [
      for (final a in watched)
        if (data.rules[a.id]!.dailyLimitMinutes != null &&
            !data.rules[a.id]!.blocked)
          data.rules[a.id]!.dailyLimitMinutes! + data.bonus,
    ].fold(0, (a, b) => a + b);
    final verdicts = {for (final a in watched) a.id: data.verdict(a)};
    final released = verdicts.values.where((v) => v.allowed).length;
    final stopped = verdicts.values.length - released;
    final untilMidnight = DateTime(
      data.now.year,
      data.now.month,
      data.now.day + 1,
    ).difference(data.now);
    final renew =
        '${untilMidnight.inHours.toString().padLeft(2, '0')}:${(untilMidnight.inMinutes % 60).toString().padLeft(2, '0')}';

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 4, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('Olá, $name', style: text.headlineMedium),
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.waving_hand,
                    color: GColors.orange,
                    size: 26,
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(todayLabel(data.now), style: text.bodyMedium),
            ],
          ),
        ),
        GHero(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Tempo de tela hoje',
                style: text.titleSmall?.copyWith(
                  color: Colors.white.withValues(alpha: 0.85),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                formatDur(totalUsed),
                key: const Key('heroTotal'),
                style: text.headlineMedium?.copyWith(
                  color: Colors.white,
                  fontSize: 36,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                combined > 0
                    ? 'de até ${formatDur(combined)} combinados para hoje'
                    : 'sem limite combinado para hoje',
                style: text.titleSmall?.copyWith(
                  color: Colors.white,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        GCard(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Row(
            children: [
              _Stat(
                '$released',
                'jogos liberados',
                key: const Key('statReleased'),
              ),
              const _Divider(),
              _Stat('$stopped', 'parados hoje', key: const Key('statStopped')),
              const _Divider(),
              _Stat(renew, 'tempo renova'),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (!usage.supported)
          const Notice(
            'Este aparelho ainda não mede o tempo de uso. Os limites aparecem, '
            'mas o tempo restante não diminui.',
            icon: Icons.hourglass_empty,
          )
        else if (usage.missing.isNotEmpty)
          _PermissionsCard(missing: usage.missing, onRequest: usage.request),
        if (usage.supported && usage.adminActive == false) ...[
          const SizedBox(height: 12),
          _AdminCard(onActivate: usage.requestAdmin),
        ],
        if (syncError != null) ...[
          const SizedBox(height: 12),
          Notice(syncError!, isError: true),
        ],
        if (usage.reportError != null) ...[
          const SizedBox(height: 12),
          Notice(usage.reportError!, isError: true),
        ],
        const GSectionLabel('Jogos monitorados'),
        if (watched.isEmpty)
          const GCard(
            child: Text(
              'O responsável ainda não definiu limites. '
              'Quando definir, eles aparecem aqui.',
            ),
          )
        else
          for (final app in watched) ...[
            _AppCard(
              app: app,
              rule: data.rules[app.id]!,
              used: data.usedToday[app.id] ?? 0,
              verdict: verdicts[app.id]!,
              bonus: data.bonus,
            ),
            const SizedBox(height: 10),
          ],
        if (free.isNotEmpty) ...[
          GSectionLabel('Sem limite (${free.length})'),
          GCard(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
            child: Column(
              children: [
                for (final app in free)
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: AppAvatar(app, size: 32),
                    title: Text(app.name, style: text.titleSmall),
                    subtitle: (data.usedToday[app.id] ?? 0) > 0
                        ? Text('Hoje: ${formatDur(data.usedToday[app.id])}')
                        : null,
                    trailing: data.verdict(app).state == AppState.paused
                        ? GTag.warn(data.verdict(app).reason ?? 'Em pausa')
                        : null,
                  ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 20),
        Text(
          lastSync == null
              ? 'Enviando a lista de apps para o responsável...'
              : 'Lista de apps enviada ao responsável.',
          style: text.bodySmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          'Aparelho: ${data.device.name} (${data.device.platform.label})',
          style: text.bodySmall,
          textAlign: TextAlign.center,
        ),
        if (data.device.parentLabel != null) ...[
          const SizedBox(height: 4),
          Text(
            'Responsável: ${data.device.parentLabel}',
            key: const Key('parentLabel'),
            style: text.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) =>
      Container(width: 1, height: 32, color: GColors.line);
}

class _Stat extends StatelessWidget {
  const _Stat(this.value, this.label, {super.key});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      children: [
        Text(value, style: Theme.of(context).textTheme.titleLarge),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    ),
  );
}

class _AppCard extends StatelessWidget {
  const _AppCard({
    required this.app,
    required this.rule,
    required this.used,
    required this.verdict,
    required this.bonus,
  });

  final InstalledApp app;
  final AppRule rule;
  final int used;
  final AppVerdict verdict;
  final int bonus;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final limit = rule.dailyLimitMinutes == null
        ? null
        : rule.dailyLimitMinutes! + bonus;
    final tag = switch (verdict.state) {
      AppState.blocked => GTag.bad('Bloqueado'),
      AppState.exhausted => GTag.bad('Esgotado'),
      AppState.paused => GTag.warn(verdict.reason ?? 'Em pausa'),
      _ => GTag.ok('Dentro do limite'),
    };
    final subtitle = rule.blocked
        ? 'Bloqueado pelo responsável'
        : (limit == null
              ? 'Usou ${formatDur(used)} hoje'
              : '${formatDur(used)} de ${formatDur(limit)} hoje');
    final ratio = (limit == null || limit == 0) ? 0.0 : used / limit;
    final barColor = verdict.state == AppState.exhausted
        ? GColors.red
        : (ratio >= 0.8 ? GColors.orange : GColors.green);
    return GCard(
      key: Key('app_${app.id}'),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppAvatar(app, size: 54),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        app.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.titleMedium,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Flexible(child: tag),
                  ],
                ),
                const SizedBox(height: 2),
                Text(subtitle, style: text.bodyMedium),
                if (!rule.blocked && limit != null) ...[
                  const SizedBox(height: 8),
                  GProgress(ratio, color: barColor),
                ],
              ],
            ),
          ),
        ],
      ),
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
      'Mostra que o Guardian está ativo.',
    ),
  };

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return GCard(
      key: const Key('permissionsCard'),
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
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.tonal(
                  key: Key('permission_${p.name}'),
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
                  onPressed: () => onRequest(p),
                  child: Text(_info[p]!.$1),
                ),
              ),
            ],
        ],
      ),
    );
  }
}

/// Proteção contra desinstalação: o Android passa a exigir desativar o
/// "administrador do dispositivo" antes de remover o app, e o responsável é
/// avisado quando isso acontece.
class _AdminCard extends StatelessWidget {
  const _AdminCard({required this.onActivate});

  final Future<void> Function() onActivate;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return GCard(
      key: const Key('adminCard'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Proteção contra desinstalação', style: text.titleMedium),
          const SizedBox(height: 4),
          Text(
            'Ativada, o Android exige desativar esta proteção antes de remover '
            'o Guardian, e o responsável é avisado. Também é avisado quando '
            'uma permissão é retirada.',
            style: text.bodySmall,
          ),
          const SizedBox(height: 12),
          FilledButton.tonal(
            key: const Key('adminButton'),
            style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
            onPressed: onActivate,
            child: const Text('Ativar proteção'),
          ),
        ],
      ),
    );
  }
}
