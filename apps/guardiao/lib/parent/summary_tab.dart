import 'package:flutter/material.dart';
import 'package:guardiao_core/guardiao_core.dart';

import '../common/names.dart';
import '../common/report_view.dart';
import 'alerts_panel.dart';
import 'block_preview.dart';
import 'device_screen.dart';

/// "Resumo": números do dia, bloqueio geral, atalhos e ações.
class SummaryTab extends StatelessWidget {
  const SummaryTab({
    super.key,
    required this.data,
    required this.onLockAll,
    required this.onGoTab,
    required this.onMarkSeen,
    required this.onRemove,
    required this.onAccount,
  });

  final PanelData data;
  final ValueChanged<bool> onLockAll;
  final ValueChanged<int> onGoTab;
  final Future<void> Function() onMarkSeen;
  final VoidCallback onRemove;
  final VoidCallback onAccount;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final used = data.usedToday.values.fold(0, (a, b) => a + b);
    final withLimit = data.rules.values
        .where((r) => r.dailyLimitMinutes != null && !r.blocked)
        .length;
    final blocked = data.rules.values.where((r) => r.blocked).length;
    final activeRoutines = data.config.routines.where((r) => r.enabled).length;
    final device = data.device;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        alertsFor(data, onMarkSeen),
        if (data.alerts.any((a) => !a.seen) ||
            device.hasNoSignal(data.now) ||
            AlertsPanel.offNow(device.health).isNotEmpty)
          const SizedBox(height: 12),
        GCard(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Row(
            children: [
              _Stat(formatDur(used), 'usado hoje', key: const Key('statUsed')),
              const _VDivider(),
              _Stat('$withLimit', 'com limite', key: const Key('statLimited')),
              const _VDivider(),
              _Stat('$blocked', 'bloqueados', key: const Key('statBlocked')),
            ],
          ),
        ),
        const SizedBox(height: 12),
        GCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const GIconBox(Icons.lock_outline, size: 44),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Bloqueio geral', style: text.titleSmall),
                        Text(
                          'Pausa todos os apps agora, menos os sempre liberados',
                          style: text.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    key: const Key('lockAllSwitch'),
                    value: data.config.lockAll,
                    onChanged: onLockAll,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              TextButton(
                key: const Key('previewButton'),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 32),
                ),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => BlockPreview(data: data),
                  ),
                ),
                child: const Text('Ver o que a criança vê ›'),
              ),
            ],
          ),
        ),
        const GSectionLabel('Atalhos'),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _Shortcut(
                key: const Key('shortcutApps'),
                icon: Icons.smartphone,
                color: GColors.blue,
                background: GColors.blueSoft,
                title: 'Limites dos apps',
                detail: '$withLimit com limite · $blocked bloqueados',
                onTap: () => onGoTab(1),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _Shortcut(
                key: const Key('shortcutRoutines'),
                icon: Icons.schedule,
                color: GColors.green,
                background: GColors.greenSoft,
                title: 'Rotinas',
                detail:
                    '$activeRoutines ${activeRoutines == 1 ? 'ativa' : 'ativas'}',
                onTap: () => onGoTab(2),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _Shortcut(
                key: const Key('shortcutCredits'),
                icon: Icons.star_border_rounded,
                color: GColors.orange,
                background: GColors.orangeSoft,
                title: 'Créditos',
                detail: data.pendingClaims == 0
                    ? 'nada para aprovar'
                    : '${data.pendingClaims} para aprovar',
                onTap: () => onGoTab(3),
              ),
            ),
          ],
        ),
        const GSectionLabel('Dispositivo'),
        GCard(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${childName(device.name)} · ${device.platform.label}',
                      style: text.titleSmall,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      lastSeen(device.lastSeen, data.now),
                      style: text.bodySmall?.copyWith(
                        color: device.hasNoSignal(data.now)
                            ? GColors.redText
                            : null,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                device.platform == DevicePlatform.windows
                    ? Icons.computer
                    : Icons.smartphone,
                color: GColors.muted,
              ),
            ],
          ),
        ),
        const GSectionLabel('Ações'),
        GCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              GSettingRow(
                key: const Key('reportRow'),
                icon: Icons.bar_chart_rounded,
                iconColor: GColors.blue,
                iconBackground: GColors.blueSoft,
                title: 'Relatório de uso',
                subtitle: 'Hoje, 7 dias e 30 dias',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => _ReportPage(data: data),
                  ),
                ),
              ),
              const Divider(height: 1),
              GSettingRow(
                key: const Key('accountRow'),
                icon: Icons.settings_outlined,
                iconColor: GColors.blue,
                iconBackground: GColors.blueSoft,
                title: 'Minha conta e configurações',
                subtitle: 'Família, segurança, notificações',
                onTap: onAccount,
              ),
              const Divider(height: 1),
              GSettingRow(
                key: const Key('removeDevice'),
                icon: Icons.delete_outline,
                iconColor: GColors.redText,
                iconBackground: GColors.redSoft,
                title: 'Remover aparelho',
                subtitle: 'Deixa de monitorar e apaga os limites',
                onTap: onRemove,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// "Online agora", "Visto há 3 h", "Nunca conectou".
String lastSeen(DateTime? lastSeen, DateTime now) {
  if (lastSeen == null) return 'Nunca conectou';
  final diff = now.difference(lastSeen);
  if (diff < const Duration(minutes: 30)) return 'Online agora';
  if (diff < const Duration(hours: 1)) return 'Visto há ${diff.inMinutes} min';
  if (diff < const Duration(days: 1)) return 'Visto há ${diff.inHours} h';
  return 'Visto há ${diff.inDays} d';
}

class _ReportPage extends StatelessWidget {
  const _ReportPage({required this.data});

  final PanelData data;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          Row(
            children: [
              IconButton(
                tooltip: 'Voltar',
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(Icons.chevron_left, size: 28),
              ),
            ],
          ),
          GTitle(
            'Relatório',
            subtitle: 'Uso de ${childName(data.device.name)}',
          ),
          ReportView(
            entries: data.usage,
            apps: data.apps,
            rules: data.rules,
            now: data.now,
          ),
        ],
      ),
    ),
  );
}

class _VDivider extends StatelessWidget {
  const _VDivider();

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

class _Shortcut extends StatelessWidget {
  const _Shortcut({
    super.key,
    required this.icon,
    required this.color,
    required this.background,
    required this.title,
    required this.detail,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final Color background;
  final String title;
  final String detail;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return GCard(
      onTap: onTap,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GIconBox(icon, color: color, background: background, size: 36),
          const SizedBox(height: 14),
          Text(title, style: text.titleSmall),
          const SizedBox(height: 2),
          Text(detail, style: text.bodySmall?.copyWith(fontSize: 11.5)),
        ],
      ),
    );
  }
}
