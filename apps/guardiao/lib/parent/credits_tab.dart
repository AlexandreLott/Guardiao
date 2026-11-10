import 'package:flutter/material.dart';
import 'package:guardiao_core/guardiao_core.dart';

import '../common/icons.dart';
import '../common/names.dart';
import 'device_screen.dart';

/// "Créditos": aprovar o que a criança fez, escolher a mensagem da tela de
/// bloqueio e cuidar da lista de missões.
class CreditsTab extends StatefulWidget {
  const CreditsTab({
    super.key,
    required this.data,
    required this.onSave,
    required this.onDecide,
  });

  final PanelData data;
  final Future<void> Function(DeviceConfig config) onSave;
  final Future<void> Function(Claim claim, bool approved) onDecide;

  @override
  State<CreditsTab> createState() => _CreditsTabState();
}

class _CreditsTabState extends State<CreditsTab> {
  late final _message = TextEditingController(
    text: widget.data.config.blockMessage,
  );

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  DeviceConfig get _config => widget.data.config;

  Future<void> _addMission() async {
    final title = TextEditingController();
    final minutes = TextEditingController(text: '30');
    final created = await showDialog<Mission>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nova missão'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              key: const Key('missionTitle'),
              controller: title,
              maxLength: 60,
              decoration: const InputDecoration(
                labelText: 'O que a criança faz',
                hintText: 'Arrumar o quarto',
                counterText: '',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('missionMinutes'),
              controller: minutes,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Minutos de diversão',
                counterText: '',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            key: const Key('saveMission'),
            style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
            onPressed: () {
              final m = int.tryParse(minutes.text.trim());
              final t = title.text.trim();
              if (t.isEmpty || m == null || m < 1 || m > 240) return;
              Navigator.pop(
                context,
                Mission(
                  id: 'm-${DateTime.now().microsecondsSinceEpoch}',
                  title: t,
                  minutes: m,
                ),
              );
            },
            child: const Text('Adicionar'),
          ),
        ],
      ),
    );
    title.dispose();
    minutes.dispose();
    if (created != null) {
      await widget.onSave(
        _config.copyWith(missions: [..._config.missions, created]),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final text = Theme.of(context).textTheme;
    final pending = data.claims
        .where((c) => c.status == ClaimStatus.pending)
        .toList();
    final missions = _config.missions;
    final suggested = _config.suggestedMission;
    final preview = _message.text.trim().isNotEmpty
        ? _message.text.trim()
        : (suggested == null
              ? 'Sem mensagem. A tela de bloqueio não mostra missão.'
              : '${suggested.title} e ganhe mais ${suggested.minutes} minutos!');
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        GSectionLabel(
          'Créditos benéficos',
          trailing: Text(
            pending.isEmpty
                ? 'nada para aprovar'
                : '${pending.length} para aprovar',
            style: text.bodySmall,
          ),
        ),
        for (final c in pending)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: GCard(
              key: Key('claim_${c.id}'),
              borderColor: const Color(0xFFFFD2B0),
              child: Row(
                children: [
                  const GIconBox(
                    Icons.menu_book_outlined,
                    color: GColors.orange,
                    background: GColors.orangeSoft,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${childName(data.device.name)} fez: ${c.title}',
                          style: text.titleSmall,
                        ),
                        Text('Vale +${c.minutes} min', style: text.bodySmall),
                      ],
                    ),
                  ),
                  IconButton(
                    key: Key('reject_${c.id}'),
                    tooltip: 'Recusar',
                    onPressed: () => widget.onDecide(c, false),
                    icon: const Icon(Icons.close),
                  ),
                  FilledButton(
                    key: Key('approve_${c.id}'),
                    style: FilledButton.styleFrom(
                      backgroundColor: GColors.green,
                      minimumSize: const Size(0, 40),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                    ),
                    onPressed: () => widget.onDecide(c, true),
                    child: const Text('Aprovar'),
                  ),
                ],
              ),
            ),
          ),
        GCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const GIconBox(
                    Icons.card_giftcard,
                    color: GColors.orange,
                    background: GColors.orangeSoft,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'A criança pode pedir tempo',
                          style: text.titleSmall,
                        ),
                        Text(
                          'Mostra "Fiz!" nas missões e "Pedir mais tempo" '
                          'na tela de bloqueio.',
                          style: text.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    key: const Key('allowRequestsSwitch'),
                    value: _config.allowRequests,
                    onChanged: (v) =>
                        widget.onSave(_config.copyWith(allowRequests: v)),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text('Missão sugerida', style: text.titleSmall),
              const SizedBox(height: 8),
              if (missions.isEmpty)
                Text('Crie missões abaixo.', style: text.bodySmall)
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final m in missions)
                      ChoiceChip(
                        key: Key('suggest_${m.id}'),
                        avatar: Icon(missionIcon(m.icon), size: 16),
                        label: Text(m.title),
                        selected: _config.suggestedMissionId == m.id,
                        onSelected: (sel) {
                          final next = sel
                              ? _config.copyWith(suggestedMissionId: m.id)
                              : _config.copyWith(clearSuggested: true);
                          widget.onSave(next);
                        },
                      ),
                  ],
                ),
              const SizedBox(height: 16),
              GField(
                fieldKey: const Key('blockMessage'),
                label: 'Mensagem',
                controller: _message,
                hint: 'Arrume o quarto e ganhe mais 50 minutos!',
                maxLength: 140,
                onSubmitted: (v) =>
                    widget.onSave(_config.copyWith(blockMessage: v.trim())),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  key: const Key('saveMessage'),
                  onPressed: () => widget.onSave(
                    _config.copyWith(blockMessage: _message.text.trim()),
                  ),
                  child: const Text('Salvar mensagem'),
                ),
              ),
              Text('Como a criança vê', style: text.titleSmall),
              const SizedBox(height: 8),
              Container(
                key: const Key('messagePreview'),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: GColors.orangeSoft,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(preview, style: text.titleSmall),
              ),
            ],
          ),
        ),
        GSectionLabel(
          'Missões da família',
          trailing: TextButton(
            key: const Key('addMission'),
            style: TextButton.styleFrom(
              backgroundColor: GColors.blueSoft,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              minimumSize: const Size(0, 34),
            ),
            onPressed: _addMission,
            child: const Text('+ Nova missão'),
          ),
        ),
        if (missions.isEmpty)
          GCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Missões são tarefas que viram tempo extra, como "Arrumar o '
                  'quarto".',
                  style: text.bodySmall,
                ),
                const SizedBox(height: 12),
                FilledButton.tonal(
                  key: const Key('suggestedMissions'),
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
                  onPressed: () => widget.onSave(
                    _config.copyWith(
                      missions: defaultMissions,
                      suggestedMissionId: defaultMissions.first.id,
                    ),
                  ),
                  child: const Text('Usar missões sugeridas'),
                ),
              ],
            ),
          )
        else
          GCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (var i = 0; i < missions.length; i++) ...[
                  if (i > 0) const Divider(height: 1),
                  ListTile(
                    key: Key('mission_${missions[i].id}'),
                    leading: GIconBox(
                      missionIcon(missions[i].icon),
                      color: GColors.orange,
                      background: GColors.orangeSoft,
                    ),
                    title: Text(missions[i].title, style: text.titleSmall),
                    subtitle: Text('+${missions[i].minutes} min de diversão'),
                    trailing: IconButton(
                      key: Key('deleteMission_${missions[i].id}'),
                      tooltip: 'Excluir missão',
                      onPressed: () => widget.onSave(
                        _config.copyWith(
                          missions: [
                            for (final m in missions)
                              if (m.id != missions[i].id) m,
                          ],
                          clearSuggested:
                              _config.suggestedMissionId == missions[i].id,
                        ),
                      ),
                      icon: const Icon(Icons.delete_outline),
                    ),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}
