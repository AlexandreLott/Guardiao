import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:guardiao_core/guardiao_core.dart';

import '../platform/installed_apps_source.dart';

class PairingScreen extends StatefulWidget {
  const PairingScreen({
    super.key,
    required this.backend,
    required this.source,
    this.isDemo = false,
  });

  final GuardianBackend backend;
  final InstalledAppsSource source;
  final bool isDemo;

  @override
  State<PairingScreen> createState() => _PairingScreenState();
}

class _PairingScreenState extends State<PairingScreen> {
  final _code = TextEditingController();
  final _name = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    widget.source.deviceName().then((n) {
      if (mounted && _name.text.isEmpty) _name.text = n;
    });
  }

  @override
  void dispose() {
    _code.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!isValidPairingCode(_code.text)) {
      setState(() => _error = 'O código tem 8 letras e números, como K7M2-9QXA.');
      return;
    }
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Dê um nome para este aparelho.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.backend.claimPairing(
        code: _code.text,
        deviceName: name,
        platform: widget.source.platform,
      );
      // A tela muda sozinha: o portão observa o documento do aparelho.
    } on PairingException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = 'Algo deu errado: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(Icons.shield_moon_outlined,
                      size: 56, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(height: 16),
                  Text('Vincular este aparelho', style: text.headlineSmall),
                  const SizedBox(height: 8),
                  Text(
                    'Peça para o responsável abrir o app dele, tocar em '
                    '"Adicionar aparelho" e digitar aqui o código que aparecer.',
                    style: text.bodyMedium,
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    key: const Key('codeField'),
                    controller: _code,
                    enabled: !_busy,
                    textCapitalization: TextCapitalization.characters,
                    autocorrect: false,
                    enableSuggestions: false,
                    maxLength: 9,
                    style: text.headlineSmall?.copyWith(letterSpacing: 4),
                    textAlign: TextAlign.center,
                    inputFormatters: [_CodeFormatter()],
                    decoration: const InputDecoration(
                      labelText: 'Código do responsável',
                      hintText: 'XXXX-XXXX',
                      counterText: '',
                    ),
                    onSubmitted: (_) => _submit(),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    key: const Key('nameField'),
                    controller: _name,
                    enabled: !_busy,
                    maxLength: 80,
                    decoration: const InputDecoration(
                      labelText: 'Nome deste aparelho',
                      counterText: '',
                    ),
                  ),
                  if (widget.isDemo) ...[
                    const SizedBox(height: 12),
                    Notice(
                      'Modo demonstração, sem internet. Use o código '
                      '${formatPairingCode(demoPairingCode)}.',
                    ),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Notice(_error!, isError: true),
                  ],
                  const SizedBox(height: 20),
                  FilledButton(
                    key: const Key('claimButton'),
                    onPressed: _busy ? null : _submit,
                    child: _busy
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Vincular'),
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

/// Deixa o texto em maiúsculas, remove o que não é do código e põe o traço
/// no meio ("k7m29qxa" vira "K7M2-9QXA").
class _CodeFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    var raw = normalizePairingCode(newValue.text);
    if (raw.length > pairingCodeLength) raw = raw.substring(0, pairingCodeLength);
    final shown = raw.length > 4 ? '${raw.substring(0, 4)}-${raw.substring(4)}' : raw;
    return TextEditingValue(
      text: shown,
      selection: TextSelection.collapsed(offset: shown.length),
    );
  }
}
