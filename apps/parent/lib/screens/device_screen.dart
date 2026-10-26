import 'package:flutter/material.dart';
import 'package:guardiao_core/guardiao_core.dart';

import 'rule_sheet.dart';

/// Apps instalados no aparelho do filho e as regras de cada um.
class DeviceScreen extends StatefulWidget {
  const DeviceScreen({super.key, required this.backend, required this.device});

  final GuardianBackend backend;
  final PairedDevice device;

  @override
  State<DeviceScreen> createState() => _DeviceScreenState();
}

class _DeviceScreenState extends State<DeviceScreen> {
  late final Stream<List<InstalledApp>> _apps = widget.backend.watchApps(widget.device.id);
  late final Stream<Map<String, AppRule>> _rules = widget.backend.watchRules(widget.device.id);
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _remove() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remover aparelho?'),
        content: Text(
          '"${widget.device.name}" deixa de ser monitorado e perde os limites '
          'definidos. Para voltar, será preciso vincular de novo.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Remover')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await widget.backend.removeDevice(widget.device.id);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Não foi possível remover: $e')));
      }
    }
  }

  Future<void> _edit(InstalledApp app, AppRule? rule) async {
    final result = await showModalBottomSheet<AppRule>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => RuleSheet(app: app, rule: rule ?? AppRule(appId: app.id)),
    );
    if (result == null) return;
    try {
      await widget.backend.setRule(widget.device.id, result);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Não foi possível salvar: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.device.name),
        actions: [
          PopupMenuButton<String>(
            onSelected: (_) => _remove(),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'remove', child: Text('Remover aparelho')),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: StreamBuilder<List<InstalledApp>>(
          stream: _apps,
          builder: (context, appsSnap) => StreamBuilder<Map<String, AppRule>>(
            stream: _rules,
            builder: (context, rulesSnap) {
              if (appsSnap.hasError || rulesSnap.hasError) {
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Notice(
                      'Não foi possível carregar os aplicativos. '
                      '${appsSnap.error ?? rulesSnap.error}',
                      isError: true),
                );
              }
              if (!appsSnap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final rules = rulesSnap.data ?? const <String, AppRule>{};
              final all = appsSnap.data!;
              final q = _query.trim().toLowerCase();
              final apps = q.isEmpty
                  ? all
                  : all.where((a) => a.name.toLowerCase().contains(q)).toList();
              // Apps com regra primeiro.
              final sorted = [
                ...apps.where((a) => rules.containsKey(a.id)),
                ...apps.where((a) => !rules.containsKey(a.id)),
              ];

              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${all.length} aplicativos instalados', style: text.titleMedium),
                        const SizedBox(height: 4),
                        const Notice(
                          'O tempo de uso de cada aplicativo ainda não é medido '
                          'nesta versão. Os limites e bloqueios já são enviados '
                          'ao aparelho.',
                          icon: Icons.hourglass_empty,
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          key: const Key('searchField'),
                          controller: _search,
                          onChanged: (v) => setState(() => _query = v),
                          decoration: const InputDecoration(
                            prefixIcon: Icon(Icons.search),
                            hintText: 'Buscar aplicativo',
                            isDense: true,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: all.isEmpty
                        ? const Padding(
                            padding: EdgeInsets.all(24),
                            child: Text(
                              'Ainda não chegou a lista de aplicativos. '
                              'Ela é enviada quando o app do filho é aberto.',
                              textAlign: TextAlign.center,
                            ),
                          )
                        : sorted.isEmpty
                            ? const Center(child: Text('Nenhum aplicativo encontrado.'))
                            : ListView.builder(
                                itemCount: sorted.length,
                                itemBuilder: (context, i) {
                                  final app = sorted[i];
                                  final rule = rules[app.id];
                                  return ListTile(
                                    key: ValueKey(app.id),
                                    leading: AppAvatar(app),
                                    title: Text(app.name),
                                    subtitle: Text(_ruleLabel(rule)),
                                    trailing: _RuleChip(rule: rule),
                                    onTap: () => _edit(app, rule),
                                  );
                                },
                              ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  static String _ruleLabel(AppRule? rule) {
    if (rule == null) return 'Sem limite';
    if (rule.blocked) return 'Bloqueado o dia todo';
    return 'Limite de ${formatMinutes(rule.dailyLimitMinutes)} por dia';
  }
}

class _RuleChip extends StatelessWidget {
  const _RuleChip({required this.rule});

  final AppRule? rule;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (rule == null) return const Icon(Icons.chevron_right);
    return Chip(
      label: Text(rule!.blocked ? 'Bloqueado' : formatMinutes(rule!.dailyLimitMinutes)),
      avatar: Icon(rule!.blocked ? Icons.block : Icons.timer_outlined, size: 18),
      backgroundColor: rule!.blocked ? scheme.errorContainer : scheme.secondaryContainer,
      side: BorderSide.none,
    );
  }
}
