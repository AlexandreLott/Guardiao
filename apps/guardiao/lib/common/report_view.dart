import 'package:flutter/material.dart';
import 'package:guardiao_core/guardiao_core.dart';

import 'names.dart';

const _catColors = {
  AppCategory.games: GColors.orange,
  AppCategory.videos: Color(0xFF6F86FF),
  AppCategory.social: GColors.green,
  AppCategory.study: GColors.lime,
  AppCategory.other: Color(0xFFCBD5E1),
};

/// Relatório de uso: totais, destaques, gráfico por categoria e detalhe do dia.
/// Serve ao filho e ao responsável.
class ReportView extends StatefulWidget {
  const ReportView({
    super.key,
    required this.entries,
    required this.apps,
    required this.now,
    this.rules = const {},
  });

  /// Uso dos últimos 60 dias.
  final List<UsageEntry> entries;
  final List<InstalledApp> apps;
  final Map<String, AppRule> rules;
  final DateTime now;

  @override
  State<ReportView> createState() => _ReportViewState();
}

class _ReportViewState extends State<ReportView> {
  int _period = 1; // 0 = hoje, 1 = 7 dias, 2 = 30 dias
  String? _selectedDay;

  static const _days = [1, 7, 30];

  InstalledApp _app(String id) => widget.apps.firstWhere(
    (a) => a.id == id,
    orElse: () => InstalledApp(id: id, name: id),
  );

  List<String> _dayKeys(int count, {int offset = 0}) {
    final t = widget.now;
    return [
      for (var i = count - 1 + offset; i >= offset; i--)
        dayKey(DateTime(t.year, t.month, t.day - i)),
    ];
  }

  int _total(Iterable<String> days) {
    final set = days.toSet();
    return widget.entries
        .where((e) => set.contains(e.day))
        .fold(0, (s, e) => s + e.minutes);
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final count = _days[_period];
    final days = _dayKeys(count);
    final previous = _dayKeys(count, offset: count);
    final total = _total(days);
    final prevTotal = _total(previous);
    final average = (total / count).round();
    final today = dayKey(widget.now);
    final selected = (_selectedDay != null && days.contains(_selectedDay))
        ? _selectedDay!
        : today;

    // Somas por app e por categoria no período.
    final byApp = <String, int>{};
    final byCat = <AppCategory, int>{};
    final byDay = <String, Map<AppCategory, int>>{};
    final inPeriod = days.toSet();
    for (final e in widget.entries) {
      if (!inPeriod.contains(e.day)) continue;
      final cat = categoryOf(_app(e.appId));
      byApp[e.appId] = (byApp[e.appId] ?? 0) + e.minutes;
      byCat[cat] = (byCat[cat] ?? 0) + e.minutes;
      final d = byDay.putIfAbsent(e.day, () => {});
      d[cat] = (d[cat] ?? 0) + e.minutes;
    }
    String? top(bool games) {
      String? best;
      for (final e in byApp.entries) {
        final isGame = categoryOf(_app(e.key)) == AppCategory.games;
        if (isGame != games) continue;
        if (best == null || e.value > byApp[best]!) best = e.key;
      }
      return best;
    }

    final topGame = top(true);
    final topOther = top(false);
    final topCat = byCat.entries.isEmpty
        ? null
        : byCat.entries.reduce((a, b) => a.value >= b.value ? a : b);
    String? busiest;
    var busiestMinutes = 0;
    byDay.forEach((day, cats) {
      final sum = cats.values.fold(0, (a, b) => a + b);
      if (sum > busiestMinutes) {
        busiestMinutes = sum;
        busiest = day;
      }
    });
    final dailyLimit = widget.rules.values
        .where((r) => !r.blocked && r.dailyLimitMinutes != null)
        .fold<int>(0, (s, r) => s + r.dailyLimitMinutes!);

    String pct(int part) =>
        total == 0 ? '0%' : '${(part * 100 / total).round()}%';
    final change = prevTotal == 0
        ? null
        : ((total - prevTotal) * 100 / prevTotal).round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GSegmented(
          labels: const ['Hoje', '7 dias', '30 dias'],
          index: _period,
          onChanged: (i) => setState(() {
            _period = i;
            _selectedDay = null;
          }),
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _period == 0
                        ? 'Total de hoje'
                        : 'Total nos últimos $count dias',
                    style: text.bodySmall,
                  ),
                  Text(
                    formatDur(total),
                    key: const Key('reportTotal'),
                    style: text.headlineMedium?.copyWith(fontSize: 30),
                  ),
                  if (_period != 0)
                    Text(
                      'média de ${formatDur(average)} por dia',
                      style: text.bodySmall,
                    ),
                ],
              ),
            ),
            if (change != null && _period != 0)
              GTag(
                '${change <= 0 ? '▼' : '▲'} ${change.abs()}% vs. ${_period == 1 ? 'semana' : 'mês'} anterior',
                key: const Key('reportChange'),
                color: change <= 0 ? GColors.greenText : GColors.redText,
                background: change <= 0 ? GColors.greenSoft : GColors.redSoft,
              ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _Highlight(
                label: 'JOGO MAIS JOGADO',
                leading: topGame == null
                    ? null
                    : AppAvatar(_app(topGame), size: 36),
                title: topGame == null ? '—' : _app(topGame).name,
                detail: topGame == null
                    ? 'sem uso'
                    : '${formatDur(byApp[topGame])} · ${pct(byApp[topGame]!)} do uso',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _Highlight(
                label: 'APP MAIS USADO',
                leading: topOther == null
                    ? null
                    : AppAvatar(_app(topOther), size: 36),
                title: topOther == null ? '—' : _app(topOther).name,
                detail: topOther == null
                    ? 'sem uso'
                    : '${formatDur(byApp[topOther])} · ${categoryOf(_app(topOther)).label}',
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _Highlight(
                label: 'CATEGORIA CAMPEÃ',
                leading: topCat == null
                    ? null
                    : GIconBox(
                        Icons.sports_esports_outlined,
                        color: _catColors[topCat.key]!,
                        background: _catColors[topCat.key]!.withValues(
                          alpha: 0.18,
                        ),
                        size: 36,
                      ),
                title: topCat?.key.label ?? '—',
                detail: topCat == null
                    ? 'sem uso'
                    : '${pct(topCat.value)} de todo o uso',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _Highlight(
                label: 'DIA MAIS INTENSO',
                leading: const GIconBox(Icons.schedule, size: 36),
                title: busiest == null
                    ? '—'
                    : dayTitle(DateTime.parse(busiest!))
                          .split(',')
                          .first
                          .toLowerCase(),
                detail: busiest == null
                    ? 'sem uso'
                    : '${formatDur(busiestMinutes)} nesse dia',
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (_period == 0)
          _TodayBreakdown(byCat: byCat, total: total)
        else
          _StackedChart(
            days: days,
            byDay: byDay,
            today: today,
            selected: selected,
            dailyLimit: dailyLimit,
            onSelect: (d) => setState(() => _selectedDay = d),
          ),
        const SizedBox(height: 14),
        _DayDetail(
          day: selected,
          entries: widget.entries.where((e) => e.day == selected).toList(),
          appOf: _app,
        ),
      ],
    );
  }
}

class _Highlight extends StatelessWidget {
  const _Highlight({
    required this.label,
    required this.title,
    required this.detail,
    this.leading,
  });

  final String label;
  final String title;
  final String detail;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return GCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: text.bodySmall?.copyWith(
              fontSize: 10.5,
              letterSpacing: 0.8,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              if (leading != null) ...[leading!, const SizedBox(width: 10)],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.titleSmall,
                    ),
                    Text(
                      detail,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: text.bodySmall?.copyWith(fontSize: 11.5),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 12,
    runSpacing: 4,
    children: [
      for (final c in [
        AppCategory.games,
        AppCategory.videos,
        AppCategory.social,
        AppCategory.study,
      ])
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: _catColors[c],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 4),
            Text(c.label, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
    ],
  );
}

class _TodayBreakdown extends StatelessWidget {
  const _TodayBreakdown({required this.byCat, required this.total});

  final Map<AppCategory, int> byCat;
  final int total;

  @override
  Widget build(BuildContext context) => GCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Uso por categoria',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 12),
        for (final c in AppCategory.values)
          if ((byCat[c] ?? 0) > 0)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  SizedBox(
                    width: 62,
                    child: Text(
                      c.label,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  Expanded(
                    child: GProgress(
                      total == 0 ? 0 : byCat[c]! / total,
                      color: _catColors[c]!,
                      height: 10,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    formatDur(byCat[c]),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
        if (total == 0)
          Text(
            'Nenhum uso hoje.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
      ],
    ),
  );
}

class _StackedChart extends StatelessWidget {
  const _StackedChart({
    required this.days,
    required this.byDay,
    required this.today,
    required this.selected,
    required this.dailyLimit,
    required this.onSelect,
  });

  final List<String> days;
  final Map<String, Map<AppCategory, int>> byDay;
  final String today;
  final String selected;
  final int dailyLimit;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    const area = 150.0;
    int sum(String d) => (byDay[d] ?? const {}).values.fold(0, (a, b) => a + b);
    var peak = days.map(sum).fold(0, (a, b) => a > b ? a : b);
    if (dailyLimit > peak) peak = dailyLimit;
    final dense = days.length > 10;
    return GCard(
      key: const Key('reportChart'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Uso por dia',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const Spacer(),
              const Flexible(child: _Legend()),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: area + 22,
            child: Stack(
              children: [
                if (dailyLimit > 0 && peak > 0)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 22 + area * dailyLimit / peak,
                    child: Row(
                      children: [
                        Text(
                          'limite ${formatDur(dailyLimit)}',
                          style: const TextStyle(
                            color: GColors.orange,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Container(
                            height: 1,
                            color: GColors.orange.withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (final d in days)
                      Expanded(
                        child: GestureDetector(
                          key: Key('bar_$d'),
                          behavior: HitTestBehavior.opaque,
                          onTap: () => onSelect(d),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              _Bar(
                                cats: byDay[d] ?? const {},
                                height: peak == 0 ? 0 : area * sum(d) / peak,
                                full: d == today || d == selected,
                                width: dense ? 6 : 28,
                              ),
                              const SizedBox(height: 6),
                              SizedBox(
                                height: 16,
                                child: dense
                                    ? (DateTime.parse(d).day % 5 == 0
                                          ? Text(
                                              '${DateTime.parse(d).day}',
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodySmall
                                                  ?.copyWith(fontSize: 9),
                                            )
                                          : null)
                                    : Text(
                                        weekdayShort(DateTime.parse(d).weekday)
                                            .substring(0, 3),
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              fontWeight: d == selected
                                                  ? FontWeight.w700
                                                  : FontWeight.w400,
                                              color: d == selected
                                                  ? GColors.ink
                                                  : GColors.muted,
                                            ),
                                      ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({
    required this.cats,
    required this.height,
    required this.full,
    required this.width,
  });

  final Map<AppCategory, int> cats;
  final double height;
  final bool full;
  final double width;

  @override
  Widget build(BuildContext context) {
    final total = cats.values.fold(0, (a, b) => a + b);
    if (total == 0 || height <= 0) {
      return Container(
        width: width,
        height: 3,
        decoration: BoxDecoration(
          color: GColors.track,
          borderRadius: BorderRadius.circular(2),
        ),
      );
    }
    final order = [
      AppCategory.games,
      AppCategory.videos,
      AppCategory.social,
      AppCategory.study,
      AppCategory.other,
    ];
    return ClipRRect(
      borderRadius: BorderRadius.circular(width > 10 ? 6 : 2),
      child: SizedBox(
        width: width,
        height: height < 4 ? 4 : height,
        child: Column(
          children: [
            for (final c in order)
              if ((cats[c] ?? 0) > 0)
                Expanded(
                  flex: cats[c]!,
                  child: Container(
                    color: _catColors[c]!.withValues(alpha: full ? 1 : 0.5),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

class _DayDetail extends StatelessWidget {
  const _DayDetail({
    required this.day,
    required this.entries,
    required this.appOf,
  });

  final String day;
  final List<UsageEntry> entries;
  final InstalledApp Function(String) appOf;

  @override
  Widget build(BuildContext context) {
    final sorted = [...entries]..sort((a, b) => b.minutes.compareTo(a.minutes));
    final total = sorted.fold(0, (s, e) => s + e.minutes);
    final text = Theme.of(context).textTheme;
    return GCard(
      key: const Key('dayDetail'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  dayTitle(DateTime.parse(day)),
                  style: text.titleSmall,
                ),
              ),
              Text(
                formatDur(total),
                style: text.titleSmall?.copyWith(color: GColors.blue),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (sorted.isEmpty)
            Text('Sem uso nesse dia.', style: text.bodyMedium)
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final e in sorted)
                  Container(
                    padding: const EdgeInsets.fromLTRB(4, 4, 12, 4),
                    decoration: BoxDecoration(
                      color: GColors.bg,
                      borderRadius: BorderRadius.circular(99),
                      border: Border.all(color: GColors.line),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AppAvatar(appOf(e.appId), size: 26),
                        const SizedBox(width: 6),
                        Text(
                          appOf(e.appId).name,
                          style: text.titleSmall?.copyWith(fontSize: 13),
                        ),
                        const SizedBox(width: 6),
                        Text(formatDur(e.minutes), style: text.bodySmall),
                      ],
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
