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
                    'Guardião Gamer',
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
                    'Você escolhe uma vez. No celular do responsável e no '
                    'aparelho do filho, o app é o mesmo.',
                    style: text.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  _RoleCard(
                    key: const Key('roleParent'),
                    icon: Icons.family_restroom,
                    title: 'Sou o responsável',
                    description:
                        'Vejo os apps instalados no aparelho do filho, o tempo '
                        'de uso de cada um e defino limites ou bloqueios.',
                    onTap: () => onPick(DeviceRole.parent),
                  ),
                  const SizedBox(height: 12),
                  _RoleCard(
                    key: const Key('roleChild'),
                    icon: Icons.sports_esports_outlined,
                    title: 'Este aparelho é do filho',
                    description:
                        'Vincular este celular ou computador ao responsável '
                        'e ver quanto tempo ainda dá para usar cada app.',
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
