import 'package:flutter/material.dart';
import 'package:guardiao_core/guardiao_core.dart';

import '../watch/parent_watch.dart';

/// Situação das proteções do aparelho do filho: avisos de tentativa de burla,
/// falta de sinal e permissões que estão desligadas agora.
class AlertsPanel extends StatelessWidget {
  const AlertsPanel({
    super.key,
    required this.device,
    required this.alerts,
    required this.onMarkSeen,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final PairedDevice device;
  final List<TamperAlert> alerts;
  final Future<void> Function() onMarkSeen;
  final DateTime Function() _clock;

  /// O que está desligado agora no aparelho (segundo a última leitura).
  static List<String> offNow(DeviceHealth? h) => [
    if (h != null && !h.usageAccess) 'acesso ao uso',
    if (h != null && !h.overlay) 'sobreposição a outros aplicativos',
    if (h != null && !h.notifications) 'notificações',
    if (h != null && !h.monitorRunning) 'serviço de acompanhamento',
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final now = _clock();
    final unseen = alerts.where((a) => !a.seen).toList();
    final off = offNow(device.health);
    final silent = device.hasNoSignal(now);
    final quiet = unseen.isEmpty && off.isEmpty && !silent;

    return quiet
        ? const SizedBox.shrink()
        : Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: ConstrainedBox(
              // Com muitos avisos o painel rola, sem empurrar a lista para fora.
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.3,
              ),
              child: Card(
                key: const Key('alertsPanel'),
                color: scheme.errorContainer,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.warning_amber_rounded,
                            color: scheme.error,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Atenção a este aparelho',
                              style: text.titleMedium?.copyWith(
                                color: scheme.onErrorContainer,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (silent) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Sem comunicação há ${sinceText(now.difference(device.lastSeen!))}. '
                          'O Guardian pode ter sido desinstalado ou parado à força, ou o '
                          'aparelho está desligado ou sem internet.',
                          key: const Key('noSignalText'),
                          style: text.bodyMedium?.copyWith(
                            color: scheme.onErrorContainer,
                          ),
                        ),
                      ],
                      if (off.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Desligado agora: ${off.join(', ')}.',
                          key: const Key('offNowText'),
                          style: text.bodyMedium?.copyWith(
                            color: scheme.onErrorContainer,
                          ),
                        ),
                      ],
                      for (final alert in unseen) ...[
                        const SizedBox(height: 8),
                        Text(
                          alert.kind.title,
                          key: Key('alert_${alert.id}'),
                          style: text.titleSmall?.copyWith(
                            color: scheme.onErrorContainer,
                          ),
                        ),
                        Text(
                          '${alert.kind.description} (${_when(alert.at, now)})',
                          style: text.bodySmall?.copyWith(
                            color: scheme.onErrorContainer,
                          ),
                        ),
                      ],
                      if (unseen.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            key: const Key('alertsSeen'),
                            onPressed: onMarkSeen,
                            child: const Text('Marcar como visto'),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          );
  }

  static String _when(DateTime at, DateTime now) {
    final diff = now.difference(at);
    if (diff.inMinutes < 1) return 'agora';
    return 'há ${sinceText(diff)}';
  }
}
