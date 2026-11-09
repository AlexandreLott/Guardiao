import 'package:flutter/material.dart';
import 'package:guardiao_core/guardiao_core.dart';

import '../qr/qr_scanner.dart';

enum _Step { start, scanning, confirm, done }

/// Vincula um aparelho de filho: o responsável escaneia o QR que aparece na
/// tela do filho (ou digita o código escrito abaixo dele), confere o aparelho
/// e confirma. Dá para repetir quantas vezes quiser, um filho de cada vez.
class AddDeviceScreen extends StatefulWidget {
  const AddDeviceScreen({
    super.key,
    required this.backend,
    required this.scanner,
    this.isDemo = false,
  });

  final GuardianBackend backend;
  final QrScanner scanner;
  final bool isDemo;

  @override
  State<AddDeviceScreen> createState() => _AddDeviceScreenState();
}

class _AddDeviceScreenState extends State<AddDeviceScreen> {
  final _code = TextEditingController();
  final _name = TextEditingController();
  _Step _step = _Step.start;
  PairRequestPreview? _preview;
  PairedDevice? _paired;
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _code.dispose();
    _name.dispose();
    super.dispose();
  }

  void _reset() {
    _code.clear();
    _name.clear();
    setState(() {
      _step = _Step.start;
      _preview = null;
      _paired = null;
      _error = null;
    });
  }

  /// Texto lido do QR ou digitado: vira um código e abre a conferência.
  Future<void> _lookup(String raw, {bool scanned = false}) async {
    if (_busy) return;
    final code = parsePairingQr(raw);
    if (code == null) {
      setState(() {
        _step = _Step.start;
        _error = scanned
            ? 'Esse QR não é de um aparelho do Guardião Gamer.'
            : 'O código tem 8 letras e números, como K7M2-9QXA.';
      });
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final preview = await widget.backend.previewPairRequest(code);
      if (!mounted) return;
      _name.text = preview.deviceName;
      setState(() {
        _preview = preview;
        _step = _Step.confirm;
      });
    } on PairingException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
          _step = _Step.start;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Algo deu errado: $e';
          _step = _Step.start;
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _approve() async {
    final preview = _preview;
    if (preview == null || _busy) return;
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Dê um nome para o aparelho.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final device = await widget.backend.approvePairRequest(
        preview.code,
        deviceName: name,
      );
      if (mounted) {
        setState(() {
          _paired = device;
          _step = _Step.done;
        });
      }
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
    return Scaffold(
      appBar: AppBar(title: const Text('Adicionar aparelho')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: switch (_step) {
                _Step.start => _start(context),
                _Step.scanning => _scanning(context),
                _Step.confirm => _confirm(context),
                _Step.done => _done(context),
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _start(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Vincular o aparelho do seu filho', style: text.titleLarge),
        const SizedBox(height: 8),
        Text(
          'No celular ou computador dele, abra o Guardião Gamer e escolha '
          '"Este aparelho é do filho". A tela mostra um QR e um código. '
          'Você pode vincular quantos aparelhos quiser, um de cada vez.',
          style: text.bodyMedium,
        ),
        const SizedBox(height: 20),
        if (widget.scanner.supported) ...[
          FilledButton.icon(
            key: const Key('scanButton'),
            onPressed: _busy
                ? null
                : () => setState(() {
                    _error = null;
                    _step = _Step.scanning;
                  }),
            icon: const Icon(Icons.qr_code_scanner),
            label: const Text('Escanear QR'),
          ),
          const SizedBox(height: 16),
          Text(
            'Ou digite o código que aparece abaixo do QR:',
            style: text.bodyMedium,
          ),
        ] else
          Text(
            'Digite o código que aparece abaixo do QR, na tela do filho:',
            style: text.bodyMedium,
          ),
        const SizedBox(height: 12),
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
          inputFormatters: [PairingCodeFormatter()],
          decoration: const InputDecoration(
            labelText: 'Código do aparelho do filho',
            hintText: 'XXXX-XXXX',
            counterText: '',
          ),
          onSubmitted: _lookup,
        ),
        if (widget.isDemo) ...[
          const SizedBox(height: 12),
          Notice(
            'Modo demonstração, sem internet. Use o código '
            '${formatPairingCode(demoPairingCode)} para vincular um '
            'notebook de exemplo.',
          ),
        ],
        if (_error != null) ...[
          const SizedBox(height: 12),
          Notice(_error!, isError: true),
        ],
        const SizedBox(height: 16),
        FilledButton.tonal(
          key: const Key('codeContinueButton'),
          onPressed: _busy ? null : () => _lookup(_code.text),
          child: _busy
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Continuar'),
        ),
      ],
    );
  }

  Widget _scanning(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Aponte a câmera para o QR', style: text.titleLarge),
        const SizedBox(height: 8),
        Text(
          'O QR aparece na tela do aparelho do seu filho.',
          style: text.bodyMedium,
        ),
        const SizedBox(height: 16),
        widget.scanner.build(
          context,
          onCode: (text) => _lookup(text, scanned: true),
          onProblem: (message) {
            if (!mounted || _step != _Step.scanning) return;
            setState(() {
              _error = message;
              _step = _Step.start;
            });
          },
        ),
        const SizedBox(height: 16),
        TextButton(
          key: const Key('cancelScanButton'),
          onPressed: () => setState(() => _step = _Step.start),
          child: const Text('Digitar o código'),
        ),
      ],
    );
  }

  Widget _confirm(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final preview = _preview!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(
          preview.platform == DevicePlatform.windows
              ? Icons.computer
              : Icons.smartphone,
          size: 56,
          color: scheme.primary,
        ),
        const SizedBox(height: 12),
        Text(
          'Vincular este aparelho?',
          style: text.titleLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          '${preview.platform.label} · confira se é o aparelho do seu filho',
          key: const Key('previewPlatform'),
          style: text.bodyMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        TextField(
          key: const Key('nameField'),
          controller: _name,
          enabled: !_busy,
          maxLength: 80,
          decoration: const InputDecoration(
            labelText: 'Nome do aparelho',
            counterText: '',
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Notice(_error!, isError: true),
        ],
        const SizedBox(height: 16),
        FilledButton(
          key: const Key('approveButton'),
          onPressed: _busy ? null : _approve,
          child: _busy
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Vincular'),
        ),
        TextButton(
          key: const Key('backButton'),
          onPressed: _busy ? null : _reset,
          child: const Text('Não é esse, voltar'),
        ),
      ],
    );
  }

  Widget _done(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(Icons.check_circle, size: 56, color: scheme.secondary),
        const SizedBox(height: 12),
        Text(
          '${_paired!.name} foi vinculado!',
          style: text.titleLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          'Ele já aparece na sua lista de aparelhos.',
          style: text.bodyMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        FilledButton(
          key: const Key('doneButton'),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Pronto'),
        ),
        TextButton.icon(
          key: const Key('addAnotherButton'),
          onPressed: _reset,
          icon: const Icon(Icons.add),
          label: const Text('Adicionar outro aparelho'),
        ),
      ],
    );
  }
}
