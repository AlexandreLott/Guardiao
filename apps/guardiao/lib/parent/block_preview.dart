import 'package:flutter/material.dart';
import 'package:guardiao_core/guardiao_core.dart';

import 'device_screen.dart';

/// "O que a criança vê": prévia da tela de bloqueio com a mensagem escolhida.
class BlockPreview extends StatelessWidget {
  const BlockPreview({super.key, required this.data});

  final PanelData data;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final config = data.config;
    final mission = config.blockMessage.trim().isNotEmpty
        ? config.blockMessage.trim()
        : (config.suggestedMission == null
              ? null
              : '${config.suggestedMission!.title} e ganhe mais '
                    '${config.suggestedMission!.minutes} minutos!');
    InstalledApp? game;
    for (final a in data.apps) {
      if (categoryOf(a) == AppCategory.games) {
        game = a;
        break;
      }
    }
    final helpers = [
      for (final a in data.apps)
        if ((data.rules[a.id]?.alwaysAllowed ?? false) ||
            categoryOf(a) == AppCategory.study)
          a,
    ].take(3).toList();
    final until = DateTime(
      data.now.year,
      data.now.month,
      data.now.day + 1,
    ).difference(data.now);
    Widget box(String v, String l) => Container(
      width: 66,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Text(
            v,
            style: const TextStyle(
              color: GColors.blue,
              fontWeight: FontWeight.w700,
              fontSize: 24,
            ),
          ),
          Text(l, style: text.bodySmall?.copyWith(fontSize: 11)),
        ],
      ),
    );
    return Scaffold(
      body: SafeArea(
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFDCE4F5), GColors.bg],
            ),
          ),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  key: const Key('previewBack'),
                  tooltip: 'Voltar',
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: const Icon(Icons.chevron_left, size: 28),
                ),
              ),
              Center(
                child: Text(
                  'Visão da criança',
                  style: text.bodySmall?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: game == null
                    ? const GuardianLogo(size: 72)
                    : AppAvatar(game, size: 72),
              ),
              const SizedBox(height: 14),
              Text(
                '${game?.name ?? 'Este app'} descansa por hoje',
                textAlign: TextAlign.center,
                style: text.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                'Você usou todo o tempo combinado com a sua família para este '
                'jogo hoje. Amanhã tem mais!',
                textAlign: TextAlign.center,
                style: text.bodyMedium,
              ),
              const SizedBox(height: 18),
              Center(
                child: Text(
                  'LIBERA DE NOVO EM',
                  style: text.bodySmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  box(until.inHours.toString().padLeft(2, '0'), 'horas'),
                  box((until.inMinutes % 60).toString().padLeft(2, '0'), 'min'),
                  box((until.inSeconds % 60).toString().padLeft(2, '0'), 'seg'),
                ],
              ),
              if (mission != null) ...[
                const SizedBox(height: 18),
                GCard(
                  borderColor: const Color(0xFFFFD2B0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'MISSÃO PARA GANHAR MAIS TEMPO',
                        style: text.bodySmall?.copyWith(
                          color: GColors.orangeDark,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.6,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(mission, style: text.titleMedium),
                      const SizedBox(height: 12),
                      FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: GColors.orange,
                          minimumSize: const Size.fromHeight(48),
                        ),
                        onPressed: null,
                        child: const Text('Fiz a tarefa!'),
                      ),
                    ],
                  ),
                ),
              ],
              if (helpers.isNotEmpty) ...[
                const GSectionLabel('Enquanto isso, que tal...'),
                for (final a in helpers)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: GCard(
                      padding: const EdgeInsets.all(10),
                      child: Row(
                        children: [
                          AppAvatar(a, size: 40),
                          const SizedBox(width: 12),
                          Expanded(child: Text(a.name, style: text.titleSmall)),
                          GTag.ok('Abrir'),
                        ],
                      ),
                    ),
                  ),
              ],
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => Navigator.of(context).maybePop(),
                child: const Text('Voltar ao painel'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
