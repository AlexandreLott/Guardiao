import 'dart:async';

import 'package:flutter/material.dart';
import 'package:guardiao_core/guardiao_core.dart';

import '../../nearby/nearby.dart';

/// Fica visível por Bluetooth esperando o código do responsável. Quando ele
/// chega, mostra quem enviou e só devolve o código depois do "Vincular".
class NearbyReceiveSheet extends StatefulWidget {
  const NearbyReceiveSheet({super.key, required this.backend, required this.nearby});

  final GuardianBackend backend;
  final NearbyPairing nearby;

  @override
  State<NearbyReceiveSheet> createState() => _NearbyReceiveSheetState();
}

class _NearbyReceiveSheetState extends State<NearbyReceiveSheet> {
  StreamSubscription<String>? _sub;
  String? _error;
  bool _waiting = false;
  bool _asking = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _start() async {
    final status = await widget.nearby.prepare(asChild: true);
    if (!mounted) return;
    if (status != NearbyStatus.ready) {
      setState(() => _error = nearbyStatusMessage(status));
      return;
    }
    setState(() => _waiting = true);
    _sub = widget.nearby.receiveCodes().listen(
      _onCode,
      onError: (Object e) {
        if (mounted) {
          setState(() {
            _waiting = false;
            _error = '$e';
          });
        }
      },
    );
  }

  Future<void> _onCode(String code) async {
    if (_asking || !mounted) return;
    _asking = true;
    try {
      final preview = await widget.backend.previewPairing(code);
      if (!mounted) return;
      final accepted = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Vincular a este responsável?'),
          content: Text(
            'O responsável ${preview.parentLabel} quer acompanhar este aparelho. '
            'Só confirme se for você ou alguém da sua família.',
          ),
          actions: [
            TextButton(
              key: const Key('nearbyReject'),
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Recusar'),
            ),
            FilledButton(
              key: const Key('nearbyConfirm'),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Vincular'),
            ),
          ],
        ),
      );
      if (!mounted) return;
      if (accepted == true) {
        Navigator.of(context).pop(code);
      } else {
        setState(() => _error = null);
      }
    } on PairingException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = 'Algo deu errado: $e');
    } finally {
      _asking = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(Icons.bluetooth_searching,
                size: 48, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 12),
            Text('Receber código por Bluetooth',
                style: text.titleLarge, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(
              'No aparelho do responsável, abra "Adicionar aparelho", toque em '
              '"Procurar aparelhos por perto" e escolha este celular.',
              style: text.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            if (_error != null)
              Notice(_error!, isError: true)
            else if (_waiting)
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(height: 18, width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2)),
                  SizedBox(width: 12),
                  Text('Esperando o responsável…'),
                ],
              )
            else
              const Center(child: CircularProgressIndicator()),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
          ],
        ),
      ),
    );
  }
}
