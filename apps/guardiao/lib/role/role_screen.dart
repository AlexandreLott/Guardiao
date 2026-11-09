import 'package:flutter/material.dart';

import 'role.dart';

/// Primeira tela do app: define se este aparelho é do responsável ou do filho.
class RoleScreen extends StatelessWidget {
  const RoleScreen({super.key, required this.onPick});

  final ValueChanged<DeviceRole> onPick;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(
                    Icons.shield_moon_outlined,
                    size: 56,
                    color: scheme.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Guardião',
                    style: text.headlineMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Este aparelho é de quem?',
                    style: text.titleMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'A escolha é feita uma única vez. O aplicativo é o mesmo no '
                    'aparelho do responsável e no do filho.',
                    style: text.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  _RoleCard(
                    key: const Key('roleParent'),
                    icon: Icons.family_restroom,
                    title: 'Sou o responsável',
                    description:
                        'Acompanhe os aplicativos instalados no aparelho do filho, o '
                        'tempo de uso de cada um e defina limites ou bloqueios.',
                    onTap: () => onPick(DeviceRole.parent),
                  ),
                  const SizedBox(height: 12),
                  _RoleCard(
                    key: const Key('roleChild'),
                    icon: Icons.sports_esports_outlined,
                    title: 'Este aparelho é do filho',
                    description:
                        'Vincule este celular ou computador ao responsável e '
                        'consulte o tempo restante de uso de cada aplicativo.',
                    onTap: () => onPick(DeviceRole.child),
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

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: scheme.primaryContainer,
                child: Icon(icon, color: scheme.onPrimaryContainer),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: text.titleMedium),
                    const SizedBox(height: 4),
                    Text(description, style: text.bodySmall),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}
