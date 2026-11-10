import 'package:flutter/material.dart';
import 'package:guardiao_core/guardiao_core.dart';

/// "Minha conta": quem é o responsável, sair e trocar a função do aparelho.
class AccountScreen extends StatelessWidget {
  const AccountScreen({
    super.key,
    required this.backend,
    required this.device,
    this.onChangeRole,
  });

  final GuardianBackend backend;
  final PairedDevice device;
  final VoidCallback? onChangeRole;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          children: [
            Row(
              children: [
                IconButton(
                  tooltip: 'Voltar',
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: const Icon(Icons.chevron_left, size: 28),
                ),
              ],
            ),
            const GTitle(
              'Minha conta',
              subtitle: 'Configurações do responsável',
            ),
            GCard(
              child: Row(
                children: [
                  const GAvatar(
                    'R',
                    size: 56,
                    color: GColors.blue,
                    foreground: Colors.white,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Responsável', style: text.titleMedium),
                        const SizedBox(height: 4),
                        GTag.info('Conta com e-mail e senha'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const GSectionLabel('Notificações'),
            const GCard(
              child: Text(
                'Você recebe um aviso neste celular quando o aparelho do filho '
                'perde uma proteção (permissão retirada, serviço parado) ou '
                'fica sem sinal por muito tempo.',
              ),
            ),
            const GSectionLabel('Conta'),
            GCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  GSettingRow(
                    key: const Key('signOutRow'),
                    icon: Icons.logout,
                    title: 'Sair da conta',
                    subtitle: 'Volta para a tela de entrada',
                    onTap: () async {
                      Navigator.of(context).popUntil((r) => r.isFirst);
                      await backend.signOut();
                    },
                  ),
                  if (onChangeRole != null) ...[
                    const Divider(height: 1),
                    GSettingRow(
                      key: const Key('changeRoleRow'),
                      icon: Icons.swap_horiz,
                      title: 'Trocar a função deste aparelho',
                      subtitle: 'Escolher entre responsável e filho',
                      onTap: () {
                        Navigator.of(context).popUntil((r) => r.isFirst);
                        onChangeRole!();
                      },
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
