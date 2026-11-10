import 'package:flutter/material.dart';
import 'package:guardiao_core/guardiao_core.dart';

import '../../common/report_view.dart';
import 'home_screen.dart';

/// "Relatório": o mesmo painel de uso que o responsável vê.
class ChildReportTab extends StatelessWidget {
  const ChildReportTab({super.key, required this.data});

  final ChildData data;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
    children: [
      GTitle(
        'Relatório',
        subtitle: 'Últimos dias · ${data.device.name.toLowerCase()}',
      ),
      ReportView(
        entries: [
          // O que o aparelho mediu hoje entra na hora, antes de chegar à nuvem.
          for (final e in data.usage)
            if (e.day != data.today) e,
          for (final entry in data.usedToday.entries)
            UsageEntry(day: data.today, appId: entry.key, minutes: entry.value),
        ],
        apps: data.apps,
        rules: data.rules,
        now: data.now,
      ),
    ],
  );
}
