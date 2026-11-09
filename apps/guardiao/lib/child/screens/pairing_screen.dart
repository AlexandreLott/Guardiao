import 'dart:async';

import 'package:flutter/material.dart';
import 'package:guardiao_core/guardiao_core.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../platform/installed_apps_source.dart';

/// Tela do aparelho do filho antes de ser vinculado: mostra o QR (e o código
/// escrito) para o responsável ler no aparelho dele. Vale para celular e PC.
class PairingScreen extends StatefulWidget {
  const PairingScreen({
    super.key,
    required this.backend,
    required this.source,
    required this.onChangeRole,
    this.isDemo = false,
  });

  final GuardianBackend backend;
  final InstalledAppsSource source;
  final VoidCallback onChangeRole;
  final bool isDemo;

  @override
  State<PairingScreen> createState() => _PairingScreenState();
}

class _PairingScreenState extends State<PairingScreen> {
  final _name = TextEditingController();
  PairRequest? _request;
  String? _error;
  bool _busy = false;
  Timer? _tick;
  Duration _left = Duration.zero;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    final detected = await widget.source.deviceName();
    if (!mounted) return;
    if (_name.text.isEmpty) _name.text = detected;
    await _generate();
  }

  /// Gera um código novo (o anterior é cancelado pelo backend).
  Future<void> _generate() async {
    if (_busy) return;
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
      final request = await widget.backend.createPairRequest(
        deviceName: name,
        platform: widget.source.platform,
      );
      if (!mounted) {
        unawaited(widget.backend.cancelPairRequest(request.code));
        return;
      }
      setState(() => _request = request);
      _startCountdown(request.expiresAt);
    } on PairingException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = 'Algo deu errado: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _startCountdown(DateTime expiresAt) {
    _tick?.cancel();
    void update() {
      final left = expiresAt.difference(DateTime.now());
      setState(() => _left = left.isNegative ? Duration.zero : left);
    }

    update();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      update();
      // O código venceu: troca por um novo, sem o usuário precisar fazer nada.
      if (_left == Duration.zero && !_busy) _generate();
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    final request = _request;
    // Depois do vínculo (ou ao sair), o código não serve mais para nada.
    if (request != null) {
      unawaited(widget.backend.cancelPairRequest(request.code));
    }
    _name.dispose();
    super.dispose();
  }

  String get _countdown {
    final m = _left.inMinutes;
    final s = (_left.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final request = _request;
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
                  Icon(
                    Icons.shield_moon_outlined,
                    size: 56,
                    color: scheme.primary,
                  ),
                  const SizedBox(height: 16),
                  Text('Vincular este aparelho', style: text.headlineSmall),
                  const SizedBox(height: 8),
                  Text(
                    'No aparelho do responsável, abra o Guardião, toque em '
                    '"Adicionar aparelho" e escaneie este QR. Caso não seja '
                    'possível, informe o código exibido abaixo dele.',
                    style: text.bodyMedium,
                  ),
                  const SizedBox(height: 20),
                  if (request == null)
                    const SizedBox(
                      height: 240,
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else ...[
                    Center(
                      child: Semantics(
                        label:
                            'QR de vínculo. Código '
                            '${request.code.split('').join(' ')}',
                        child: Container(
                          key: const Key('pairingQr'),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: QrImageView(
                            // A chave leva o texto do QR, para os testes conferirem.
                            key: ValueKey(pairingQrPayload(request.code)),
                            data: pairingQrPayload(request.code),
                            size: 216,
                            backgroundColor: Colors.white,
                            errorCorrectionLevel: QrErrorCorrectLevel.M,
                            eyeStyle: const QrEyeStyle(
                              eyeShape: QrEyeShape.square,
                              color: Colors.black,
                            ),
                            dataModuleStyle: const QrDataModuleStyle(
                              dataModuleShape: QrDataModuleShape.square,
                              color: Colors.black,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: Text(
                        formatPairingCode(request.code),
                        key: const Key('pairingCode'),
                        style: text.headlineMedium?.copyWith(
                          letterSpacing: 6,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Vale por mais $_countdown',
                      key: const Key('countdown'),
                      textAlign: TextAlign.center,
                      style: text.bodySmall,
                    ),
                  ],
                  const SizedBox(height: 20),
                  TextField(
                    key: const Key('nameField'),
                    controller: _name,
                    enabled: !_busy,
                    maxLength: 80,
                    decoration: const InputDecoration(
                      labelText: 'Nome deste aparelho',
                      helperText: 'Aparece na lista do responsável.',
                      counterText: '',
                    ),
                    onSubmitted: (_) => _generate(),
                  ),
                  if (widget.isDemo) ...[
                    const SizedBox(height: 12),
                    Notice(
                      'Modo demonstração, sem internet. Para ver o vínculo, '
                      'entre como responsável e digite o código '
                      '${formatPairingCode(demoPairingCode)}.',
                    ),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Notice(_error!, isError: true),
                  ],
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    key: const Key('newCodeButton'),
                    onPressed: _busy ? null : _generate,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Gerar novo código'),
                  ),
                  TextButton(
                    key: const Key('changeRoleButton'),
                    onPressed: widget.onChangeRole,
                    child: const Text('Este aparelho é do responsável? Voltar'),
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
