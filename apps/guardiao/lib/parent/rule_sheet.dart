import 'package:flutter/material.dart';
import 'package:guardiao_core/guardiao_core.dart';

/// Folha para definir o limite diário, bloquear ou liberar sempre um app.
/// Devolve a regra nova (uma regra "padrão" significa remover).
class RuleSheet extends StatefulWidget {
  const RuleSheet({super.key, required this.app, required this.rule});

  final InstalledApp app;
  final AppRule rule;

  @override
  State<RuleSheet> createState() => _RuleSheetState();
}

class _RuleSheetState extends State<RuleSheet> {
  static const _step = 15;
  static const _min = 15;
  static const _max = 480;

  late bool _blocked = widget.rule.blocked;
  late bool _allowed = widget.rule.alwaysAllowed;
  late bool _limited = widget.rule.dailyLimitMinutes != null;
  late double _minutes = (widget.rule.dailyLimitMinutes ?? 60)
      .clamp(_min, _max)
      .toDouble();

  AppRule get _result => AppRule(
    appId: widget.app.id,
    dailyLimitMinutes: _limited ? _minutes.round() : null,
    blocked: _blocked,
    alwaysAllowed: _allowed && !_blocked,
  );

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          20,
          0,
          20,
          16 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                AppAvatar(widget.app, size: 48),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.app.name, style: text.titleLarge),
                      Text(categoryOf(widget.app).label, style: text.bodySmall),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            GCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  SwitchListTile(
                    key: const Key('blockSwitch'),
                    title: const Text('Bloquear o dia todo'),
                    subtitle: const Text(
                      'O aplicativo não abre até você liberar.',
                    ),
                    value: _blocked,
                    onChanged: (v) => setState(() => _blocked = v),
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    key: const Key('limitSwitch'),
                    title: const Text('Limitar o tempo por dia'),
                    value: _limited,
                    onChanged: _blocked
                        ? null
                        : (v) => setState(() => _limited = v),
                  ),
                  if (_limited && !_blocked) ...[
                    Text(
                      formatMinutes(_minutes.round()),
                      key: const Key('limitLabel'),
                      style: text.headlineSmall,
                    ),
                    Slider(
                      key: const Key('limitSlider'),
                      value: _minutes,
                      min: _min.toDouble(),
                      max: _max.toDouble(),
                      divisions: (_max - _min) ~/ _step,
                      label: formatMinutes(_minutes.round()),
                      onChanged: (v) => setState(() => _minutes = v),
                    ),
                  ],
                  const Divider(height: 1),
                  SwitchListTile(
                    key: const Key('allowedSwitch'),
                    title: const Text('Sempre liberado'),
                    subtitle: const Text(
                      'Abre mesmo no bloqueio geral e nas rotinas que pausam tudo.',
                    ),
                    value: _allowed && !_blocked,
                    onChanged: _blocked
                        ? null
                        : (v) => setState(() => _allowed = v),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            FilledButton(
              key: const Key('saveRuleButton'),
              onPressed: () => Navigator.of(context).pop(_result),
              child: Text(_result.isDefault ? 'Remover regra' : 'Salvar'),
            ),
          ],
        ),
      ),
    );
  }
}
