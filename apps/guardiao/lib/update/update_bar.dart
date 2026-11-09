import 'package:flutter/material.dart';

import 'update_controller.dart';

/// Faixa no topo do app que avisa da versão nova e conduz a atualização.
class UpdateBar extends StatelessWidget {
  const UpdateBar({super.key, required this.controller});

  final UpdateController controller;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final update = controller.update;
    final version = update == null ? '' : ' (versão ${update.build})';

    final (String text, List<Widget> actions) = switch (controller.status) {
      UpdateStatus.idle => ('', const <Widget>[]),
      UpdateStatus.available => (
        'Tem uma versão nova do Guardião Gamer$version.',
        [
          TextButton(
            key: const Key('updateDismiss'),
            onPressed: controller.dismiss,
            child: const Text('Depois'),
          ),
          FilledButton(
            key: const Key('updateStart'),
            onPressed: controller.start,
            child: const Text('Atualizar'),
          ),
        ],
      ),
      UpdateStatus.downloading => ('Baixando a versão nova…', const <Widget>[]),
      UpdateStatus.needsPermission => (
        'Libere “Instalar apps desconhecidos” para o Guardião Gamer e volte aqui.',
        [
          FilledButton(
            key: const Key('updateContinue'),
            onPressed: controller.continueInstall,
            child: const Text('Continuar'),
          ),
        ],
      ),
      UpdateStatus.readyToInstall => (
        'Confirme a instalação na tela do Android.',
        [
          FilledButton(
            key: const Key('updateContinue'),
            onPressed: controller.continueInstall,
            child: const Text('Abrir de novo'),
          ),
        ],
      ),
      UpdateStatus.error => (
        controller.error ?? 'Não deu para atualizar.',
        [
          TextButton(
            key: const Key('updateDismiss'),
            onPressed: controller.dismiss,
            child: const Text('Fechar'),
          ),
          FilledButton(
            key: const Key('updateStart'),
            onPressed: controller.start,
            child: const Text('Tentar de novo'),
          ),
        ],
      ),
    };

    return Material(
      key: const Key('updateBar'),
      color: scheme.primaryContainer,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.system_update,
                    size: 20,
                    color: scheme.onPrimaryContainer,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      text,
                      style: TextStyle(
                        color: scheme.onPrimaryContainer,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
              if (controller.status == UpdateStatus.downloading) ...[
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  key: const Key('updateProgress'),
                  value: controller.progress,
                ),
              ],
              if (actions.isNotEmpty) ...[
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: actions,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Coloca [UpdateBar] acima de todas as telas, só quando há o que mostrar.
class UpdateHost extends StatelessWidget {
  const UpdateHost({super.key, required this.controller, required this.child});

  final UpdateController? controller;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    if (c == null) return child;
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        if (!c.visible) return child;
        return Column(
          children: [
            UpdateBar(controller: c),
            Expanded(
              child: MediaQuery.removePadding(
                context: context,
                removeTop: true,
                child: child,
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Texto "Versão 1.0.3 (3)" para mostrar nos menus.
String versionLabel(UpdateController? c) {
  if (c == null || c.currentName.isEmpty) return '';
  return 'Versão ${c.currentName}';
}
