import 'package:flutter/material.dart';
import 'package:guardiao_core/guardiao_core.dart';

import 'device_screen.dart';
import 'rule_sheet.dart';

/// "Apps": todos os apps do aparelho, com filtro por categoria e busca.
class AppsTab extends StatefulWidget {
  const AppsTab({super.key, required this.data, required this.onRule});

  final PanelData data;
  final Future<void> Function(AppRule rule) onRule;

  @override
  State<AppsTab> createState() => _AppsTabState();
}

class _AppsTabState extends State<AppsTab> {
  final _search = TextEditingController();
  String _query = '';
  AppCategory? _category;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _edit(InstalledApp app, AppRule? rule) async {
    final result = await showModalBottomSheet<AppRule>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => RuleSheet(
        app: app,
        rule: rule ?? AppRule(appId: app.id),
      ),
    );
    if (result != null) await widget.onRule(result);
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final text = Theme.of(context).textTheme;
    final all = data.apps;
    final usedToday = data.usedToday;
    final q = _query.trim().toLowerCase();
    final counts = <AppCategory, int>{for (final a in all) categoryOf(a): 0};
    for (final a in all) {
      counts[categoryOf(a)] = counts[categoryOf(a)]! + 1;
    }
    final shown = [
      for (final a in all)
        if ((_category == null || categoryOf(a) == _category) &&
            (q.isEmpty || a.name.toLowerCase().contains(q)))
          a,
    ];
    // Apps com regra primeiro; dentro de cada grupo, os mais usados hoje.
    shown.sort((a, b) {
      final ra = data.rules.containsKey(a.id) ? 0 : 1;
      final rb = data.rules.containsKey(b.id) ? 0 : 1;
      if (ra != rb) return ra.compareTo(rb);
      final byUse = (usedToday[b.id] ?? 0).compareTo(usedToday[a.id] ?? 0);
      return byUse != 0
          ? byUse
          : a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        GSectionLabel(
          'Apps no aparelho',
          trailing: Text('${all.length} apps', style: text.bodySmall),
        ),
        TextField(
          key: const Key('searchField'),
          controller: _search,
          onChanged: (v) => setState(() => _query = v),
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search),
            hintText: 'Buscar app',
            isDense: true,
          ),
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _Chip(
                'Todos ${all.length}',
                selected: _category == null,
                onTap: () => setState(() => _category = null),
              ),
              for (final c in AppCategory.values)
                if ((counts[c] ?? 0) > 0) ...[
                  const SizedBox(width: 8),
                  _Chip(
                    '${c.label} ${counts[c]}',
                    key: Key('chip_${c.name}'),
                    selected: _category == c,
                    onTap: () => setState(() => _category = c),
                  ),
                ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (all.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Ainda não chegou a lista de aplicativos. '
              'Ela é enviada quando o app do filho é aberto.',
              textAlign: TextAlign.center,
            ),
          )
        else if (shown.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: Text('Nenhum aplicativo encontrado.')),
          )
        else
          GCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (var i = 0; i < shown.length; i++) ...[
                  if (i > 0) const Divider(height: 1),
                  _AppRow(
                    key: ValueKey(shown[i].id),
                    app: shown[i],
                    rule: data.rules[shown[i].id],
                    used: usedToday[shown[i].id] ?? 0,
                    onTap: () => _edit(shown[i], data.rules[shown[i].id]),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(
    this.label, {
    super.key,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: selected ? GColors.ink : Colors.white,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: selected ? GColors.ink : GColors.line),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: selected ? Colors.white : GColors.ink,
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
      ),
    ),
  );
}

class _AppRow extends StatelessWidget {
  const _AppRow({
    super.key,
    required this.app,
    required this.rule,
    required this.used,
    required this.onTap,
  });

  final InstalledApp app;
  final AppRule? rule;
  final int used;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final limit = rule?.dailyLimitMinutes;
    final blocked = rule?.blocked ?? false;
    final subtitle = blocked
        ? 'Bloqueado o dia todo${used > 0 ? ' · Hoje: ${formatDur(used)}' : ''}'
        : limit != null
        ? '${formatDur(used)} de ${formatDur(limit)} hoje'
        : (used > 0 ? 'Hoje: ${formatDur(used)}' : 'Sem limite');
    final ratio = (limit == null || limit == 0) ? 0.0 : used / limit;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            AppAvatar(app, size: 44),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(app.name, style: text.titleSmall),
                  Text(subtitle, style: text.bodySmall),
                  if (limit != null && !blocked) ...[
                    const SizedBox(height: 6),
                    GProgress(
                      ratio,
                      color: ratio >= 1
                          ? GColors.red
                          : (ratio >= 0.8 ? GColors.orange : GColors.blue),
                      height: 5,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (blocked)
              GTag.bad('Bloqueado')
            else if (limit != null)
              GTag.info(formatDur(limit))
            else if (rule?.alwaysAllowed ?? false)
              const GTag('Sempre liberado')
            else
              const Icon(
                Icons.lock_open_outlined,
                color: GColors.muted,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }
}
