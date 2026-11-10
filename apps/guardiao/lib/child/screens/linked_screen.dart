import 'package:flutter/material.dart';
import 'package:guardiao_core/guardiao_core.dart';

/// "Tudo pronto!": aparece uma vez, logo depois de o responsável aprovar.
class LinkedScreen extends StatelessWidget {
  const LinkedScreen({super.key, required this.onContinue});

  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return OnboardScaffold(
      title: 'Tudo pronto!',
      showLogo: false,
      bottom: FilledButton(
        key: const Key('linkedContinue'),
        onPressed: onContinue,
        child: const Text('Ver meu tempo de hoje'),
      ),
      child: Column(
        children: [
          const SizedBox(height: 40),
          Container(
            width: 84,
            height: 84,
            decoration: const BoxDecoration(
              color: GColors.green,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check, color: Colors.white, size: 44),
          ),
          const SizedBox(height: 24),
          Text(
            'Seu aparelho foi vinculado ao responsável. O tempo combinado '
            'de cada jogo aparece na sua tela inicial.',
            textAlign: TextAlign.center,
            style: text.bodyLarge,
          ),
        ],
      ),
    );
  }
}
