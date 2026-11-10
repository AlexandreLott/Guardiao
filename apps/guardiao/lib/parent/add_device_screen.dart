import 'package:flutter/material.dart';
import 'package:guardiao_core/guardiao_core.dart';

import '../qr/qr_scanner.dart';
import 'devices_screen.dart' show lastSeenLabel;

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
            ? 'Esse QR não é de um aparelho do Guardian.'
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
  Widget build(BuildContext context) => switch (_step) {
    _Step.start => _start(context),
    _Step.scanning => _scanning(context),
    _Step.confirm => _confirm(context),
    _Step.done => _done(context),
  };

  Widget _start(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return OnboardScaffold(
      title: 'Vincular aparelho',
      subtitle:
          'No aparelho do filho aparece um QR e um código de 8 letras e '
          'números.',
      showLogo: false,
      onBack: () => Navigator.of(context).maybePop(),
      bottom: FilledButton(
        key: const Key('codeContinueButton'),
        onPressed: _busy ? null : () => _lookup(_code.text),
        child: _busy
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Text('Continuar'),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.scanner.supported) ...[
            _ScanBox(
              key: const Key('scanButton'),
              onTap: _busy
                  ? null
                  : () => setState(() {
                      _error = null;
                      _step = _Step.scanning;
                    }),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                const Expanded(child: Divider()),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text('ou digite o código', style: text.bodySmall),
                ),
                const Expanded(child: Divider()),
              ],
            ),
            const SizedBox(height: 18),
          ],
          GField(
            fieldKey: const Key('codeField'),
            label: 'Código do aparelho do filho',
            controller: _code,
            enabled: !_busy,
            capitalization: TextCapitalization.characters,
            maxLength: 9,
            hint: 'XXXX-XXXX',
            textAlign: TextAlign.center,
            style: text.headlineSmall?.copyWith(letterSpacing: 4),
            formatters: [PairingCodeFormatter()],
            onSubmitted: _lookup,
          ),
          if (widget.isDemo) ...[
            const SizedBox(height: 16),
            Notice(
              'Modo demonstração, sem internet. Use o código '
              '${formatPairingCode(demoPairingCode)} para vincular um '
              'notebook de exemplo.',
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 16),
            Notice(_error!, isError: true),
          ],
        ],
      ),
    );
  }

  Widget _scanning(BuildContext context) {
    return OnboardScaffold(
      title: 'Aponte a câmera para o QR',
      subtitle: 'O QR aparece na tela do aparelho do seu filho.',
      showLogo: false,
      onBack: () => setState(() => _step = _Step.start),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: widget.scanner.build(
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
          ),
          const SizedBox(height: 16),
          TextButton(
            key: const Key('cancelScanButton'),
            onPressed: () => setState(() => _step = _Step.start),
            child: const Text('Digitar o código'),
          ),
        ],
      ),
    );
  }

  Widget _confirm(BuildContext context) {
    final preview = _preview!;
    return OnboardScaffold(
      title: 'Vincular este aparelho?',
      onBack: _busy ? null : _reset,
      backKey: const Key('backButton'),
      bottom: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FilledButton(
            key: const Key('approveButton'),
            onPressed: _busy ? null : _approve,
            child: _busy
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Aprovar e vincular'),
          ),
          TextButton(
            key: const Key('notThisButton'),
            onPressed: _busy ? null : _reset,
            child: const Text('Não é este'),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '${preview.platform.label} · confira se é o aparelho do seu filho',
            key: const Key('previewPlatform'),
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 20),
          GCard(
            child: Row(
              children: [
                GIconBox(
                  preview.platform == DevicePlatform.windows
                      ? Icons.computer
                      : Icons.smartphone,
                  color: GColors.orange,
                  background: GColors.orangeSoft,
                  size: 46,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        preview.deviceName,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        'Código ${formatPairingCode(preview.code)}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          GField(
            fieldKey: const Key('nameField'),
            label: 'Como chamar este aparelho',
            controller: _name,
            enabled: !_busy,
            maxLength: 80,
          ),
          if (_error != null) ...[
            const SizedBox(height: 16),
            Notice(_error!, isError: true),
          ],
        ],
      ),
    );
  }

  Widget _done(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final device = _paired!;
    return OnboardScaffold(
      title: '${device.name} foi vinculado!',
      showLogo: false,
      bottom: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FilledButton(
            key: const Key('doneButton'),
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Ir para o painel'),
          ),
          TextButton.icon(
            key: const Key('addAnotherButton'),
            onPressed: _reset,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Adicionar outro aparelho'),
          ),
        ],
      ),
      child: Column(
        children: [
          const SizedBox(height: 32),
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
            '${device.platform.label} · ${lastSeenLabel(device.lastSeen, DateTime.now()).toLowerCase()}. Agora você '
            'pode definir limites, rotinas e missões.',
            textAlign: TextAlign.center,
            style: text.bodyLarge,
          ),
        ],
      ),
    );
  }
}

/// Área escura com os cantos verde-limão do leitor ("Ler QR code").
class _ScanBox extends StatelessWidget {
  const _ScanBox({super.key, required this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: 'Escanear QR',
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        height: 230,
        decoration: BoxDecoration(
          color: GColors.ink,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 96,
              height: 96,
              child: CustomPaint(painter: _CornersPainter()),
            ),
            const SizedBox(height: 18),
            const Text(
              'Ler QR code',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 2),
            const Text(
              'Aponte a câmera para o aparelho do filho',
              style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 12.5),
            ),
          ],
        ),
      ),
    ),
  );
}

class _CornersPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = GColors.lime
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    const len = 26.0;
    final w = size.width;
    final h = size.height;
    for (final c in [
      [Offset(0, len), const Offset(0, 0), Offset(len, 0)],
      [Offset(w - len, 0), Offset(w, 0), Offset(w, len)],
      [Offset(0, h - len), Offset(0, h), Offset(len, h)],
      [Offset(w - len, h), Offset(w, h), Offset(w, h - len)],
    ]) {
      canvas.drawPath(
        Path()
          ..moveTo(c[0].dx, c[0].dy)
          ..lineTo(c[1].dx, c[1].dy)
          ..lineTo(c[2].dx, c[2].dy),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
