import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:guardiao_core/guardiao_core.dart';

import '../nearby/nearby.dart';
import 'nearby_section.dart';

/// Gera um código e espera o aparelho do filho digitá-lo.
class AddDeviceSheet extends StatefulWidget {
  const AddDeviceSheet({
    super.key,
    required this.backend,
    required this.knownDeviceIds,
    required this.nearby,
  });

  final GuardianBackend backend;

  /// Aparelhos que já existiam, para perceber quando chega um novo.
  final Set<String> knownDeviceIds;

  final NearbyPairing nearby;

  @override
  State<AddDeviceSheet> createState() => _AddDeviceSheetState();
}

class _AddDeviceSheetState extends State<AddDeviceSheet> {
  PairingCode? _code;
  String? _error;
  PairedDevice? _paired;
  Timer? _tick;
  StreamSubscription<List<PairedDevice>>? _sub;
  Duration _left = Duration.zero;

  @override
  void initState() {
    super.initState();
    _generate();
    _sub = widget.backend.watchDevices().listen((devices) {
      final fresh = devices.where((d) => !widget.knownDeviceIds.contains(d.id));
      if (fresh.isNotEmpty && mounted) {
        setState(() => _paired = fresh.first);
      }
    });
  }

  Future<void> _generate() async {
    setState(() {
      _error = null;
      _code = null;
    });
    try {
      final code = await widget.backend.createPairingCode();
      if (!mounted) return;
      setState(() => _code = code);
      _startCountdown(code.expiresAt);
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'Não foi possível gerar o código. $e');
      }
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
      if (mounted) update();
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    _sub?.cancel();
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
    final expired = _code != null && _left == Duration.zero;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          24,
          0,
          24,
          24 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_paired != null) ...[
                Icon(Icons.check_circle, size: 56, color: scheme.secondary),
                const SizedBox(height: 12),
                Text(
                  '${_paired!.name} foi vinculado!',
                  style: text.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Pronto'),
                ),
              ] else ...[
                Text('Adicionar aparelho', style: text.titleLarge),
                const SizedBox(height: 8),
                Text(
                  'No celular ou computador do seu filho, abra o app Guardião Gamer '
                  'e digite este código:',
                  style: text.bodyMedium,
                ),
                const SizedBox(height: 16),
                if (_error != null)
                  Notice(_error!, isError: true)
                else if (_code == null)
                  const Center(child: CircularProgressIndicator())
                else
                  Semantics(
                    label:
                        'Código de pareamento ${_code!.code.split('').join(' ')}',
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      decoration: BoxDecoration(
                        color: scheme.primaryContainer,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Center(
                        child: Text(
                          formatPairingCode(_code!.code),
                          key: const Key('pairingCode'),
                          style: text.displaySmall?.copyWith(
                            letterSpacing: 6,
                            fontWeight: FontWeight.w700,
                            color: scheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                if (_code != null)
                  Text(
                    expired ? 'Código expirado.' : 'Vale por mais $_countdown',
                    textAlign: TextAlign.center,
                    style: text.bodySmall,
                  ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _code == null || expired
                            ? null
                            : () async {
                                await Clipboard.setData(
                                  ClipboardData(
                                    text: formatPairingCode(_code!.code),
                                  ),
                                );
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Código copiado'),
                                  ),
                                );
                              },
                        icon: const Icon(Icons.copy),
                        label: const Text('Copiar'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.tonalIcon(
                        key: const Key('newCodeButton'),
                        onPressed: _generate,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Novo código'),
                      ),
                    ),
                  ],
                ),
                if (widget.nearby.supported)
                  NearbySection(
                    nearby: widget.nearby,
                    currentCode: () => _code == null || _left == Duration.zero
                        ? null
                        : _code!.code,
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
