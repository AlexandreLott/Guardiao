import 'package:flutter/material.dart';
import 'package:guardiao_core/guardiao_core.dart';

import 'role.dart';

/// Primeiras telas do app: a abertura (uma vez por abertura do app) e a
/// escolha de quem usa este aparelho.
class RoleScreen extends StatefulWidget {
  const RoleScreen({
    super.key,
    required this.onPick,
    this.showWelcome = false,
    this.isDemo = false,
  });

  final ValueChanged<DeviceRole> onPick;

  /// Mostra a abertura antes da escolha.
  final bool showWelcome;
  final bool isDemo;

  @override
  State<RoleScreen> createState() => _RoleScreenState();
}

class _RoleScreenState extends State<RoleScreen> {
  late bool _welcome = widget.showWelcome;

  @override
  Widget build(BuildContext context) {
    if (_welcome) {
      return _Welcome(
        isDemo: widget.isDemo,
        onStart: () => setState(() => _welcome = false),
      );
    }
    return OnboardScaffold(
      title: 'Este aparelho é de quem?',
      subtitle:
          'A escolha é feita uma única vez. O aplicativo é o mesmo no '
          'aparelho do responsável e no do filho.',
      onBack: widget.showWelcome ? () => setState(() => _welcome = true) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GChoiceTile(
            key: const Key('roleParent'),
            title: 'Sou o responsável',
            subtitle: 'Acompanhar e definir limites',
            onTap: () => widget.onPick(DeviceRole.parent),
          ),
          const SizedBox(height: 12),
          GChoiceTile(
            key: const Key('roleChild'),
            title: 'É do meu filho ou filha',
            subtitle: 'Este aparelho será acompanhado',
            onTap: () => widget.onPick(DeviceRole.child),
          ),
        ],
      ),
    );
  }
}

class _Welcome extends StatelessWidget {
  const _Welcome({required this.onStart, required this.isDemo});

  final VoidCallback onStart;
  final bool isDemo;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Spacer(),
                  const Center(child: GuardianLogo(size: 108)),
                  const SizedBox(height: 28),
                  Text(
                    guardianName,
                    textAlign: TextAlign.center,
                    style: text.headlineMedium?.copyWith(fontSize: 34),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Controle parental para jogos e apps, feito para a '
                    'família toda.',
                    textAlign: TextAlign.center,
                    style: text.bodyLarge,
                  ),
                  const Spacer(),
                  if (isDemo) ...[
                    const Notice(
                      'Modo demonstração, sem internet: os dados são de exemplo.',
                    ),
                    const SizedBox(height: 12),
                  ],
                  FilledButton(
                    key: const Key('startButton'),
                    onPressed: onStart,
                    child: const Text('Começar'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
