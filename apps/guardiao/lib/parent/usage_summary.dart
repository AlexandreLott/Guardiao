import 'package:flutter/material.dart';
import 'package:guardiao_core/guardiao_core.dart';

/// Total de minutos de um dia, somando todos os aplicativos.
class DayTotal {
  const DayTotal(this.day, this.minutes);
  final String day;
  final int minutes;

  @override
  bool operator ==(Object other) =>
      other is DayTotal && other.day == day && other.minutes == minutes;

  @override
  int get hashCode => Object.hash(day, minutes);
}

/// Os últimos [days] dias (do mais antigo ao de hoje), incluindo os sem uso.
List<DayTotal> summarizeDays(List<UsageEntry> entries, DateTime today, {int days = 7}) {
  final totals = <String, int>{};
  for (final e in entries) {
    totals[e.day] = (totals[e.day] ?? 0) + e.minutes;
  }
  return [
    for (var i = days - 1; i >= 0; i--)
      () {
        final d = DateTime(today.year, today.month, today.day - i);
        final key = dayKey(d);
        return DayTotal(key, totals[key] ?? 0);
      }(),
  ];
}

/// Minutos de hoje por aplicativo.
Map<String, int> usageOfDay(List<UsageEntry> entries, String day) => {
      for (final e in entries)
        if (e.day == day) e.appId: e.minutes,
    };

const _weekdays = ['seg', 'ter', 'qua', 'qui', 'sex', 'sáb', 'dom'];

/// Barras simples: um dia por coluna, o de hoje em destaque.
class UsageSummary extends StatelessWidget {
  const UsageSummary({super.key, required this.totals, required this.today});

  final List<DayTotal> totals;
  final String today;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final peak = totals.fold<int>(0, (m, t) => t.minutes > m ? t.minutes : m);
    final todayMinutes = totals.isEmpty ? 0 : totals.last.minutes;
    final sum = totals.fold<int>(0, (s, t) => s + t.minutes);
    final average = totals.isEmpty ? 0 : (sum / totals.length).round();
    const barArea = 64.0;
    return Card(
      key: const Key('usageSummary'),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Hoje: ${formatMinutes(todayMinutes)} de jogo e apps',
                key: const Key('usageToday'), style: text.titleMedium),
            const SizedBox(height: 2),
            Text('Média dos últimos ${totals.length} dias: ${formatMinutes(average)} por dia',
                style: text.bodySmall),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final t in totals)
                  Expanded(
                    child: Semantics(
                      label: '${t.day}: ${formatMinutes(t.minutes)}',
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            height: barArea,
                            child: Align(
                              alignment: Alignment.bottomCenter,
                              child: Container(
                                width: 18,
                                height: peak == 0
                                    ? 2
                                    : (barArea * t.minutes / peak).clamp(2.0, barArea),
                                decoration: BoxDecoration(
                                  color: t.day == today
                                      ? scheme.primary
                                      : scheme.primary.withValues(alpha: 0.35),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _weekdays[DateTime.parse(t.day).weekday - 1],
                            style: text.labelSmall,
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
    );
  }
}
