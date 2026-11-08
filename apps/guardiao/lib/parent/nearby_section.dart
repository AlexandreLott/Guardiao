import 'dart:async';

import 'package:flutter/material.dart';
import 'package:guardiao_core/guardiao_core.dart';

import '../nearby/nearby.dart';

/// "Enviar por Bluetooth": procura aparelhos do filho por perto e manda o
/// código atual para o que o responsável tocar.
class NearbySection extends StatefulWidget {
  const NearbySection({super.key, required this.nearby, required this.currentCode});

  final NearbyPairing nearby;

  /// Código ainda válido, ou `null` se estiver gerando ou expirado.
  final String? Function() currentCode;

  @override
  State<NearbySection> createState() => _NearbySectionState();
}

class _NearbySectionState extends State<NearbySection> {
  StreamSubscription<List<NearbyDevice>>? _sub;
  List<NearbyDevice> _devices = const [];
  bool _scanning = false;
  String? _error;
  String? _sentTo;
  String? _sendingId;

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _search() async {
    setState(() {
      _error = null;
      _sentTo = null;
      _devices = const [];
      _scanning = true;
    });
    final status = await widget.nearby.prepare(asChild: false);
    if (!mounted) return;
    if (status != NearbyStatus.ready) {
      setState(() {
        _scanning = false;
        _error = nearbyStatusMessage(status);
      });
      return;
    }
    await _sub?.cancel();
    _sub = widget.nearby.scan().listen(
      (list) {
        if (mounted) setState(() => _devices = list);
      },
      onError: (Object e) {
        if (mounted) {
          setState(() {
            _scanning = false;
            _error = '$e';
          });
        }
      },
    );
  }

  Future<void> _stop() async {
    await _sub?.cancel();
    _sub = null;
    if (mounted) setState(() => _scanning = false);
  }

  Future<void> _send(NearbyDevice device) async {
    final code = widget.currentCode();
    if (code == null) {
      setState(() => _error = 'O código expirou. Toque em "Novo código" e envie de novo.');
      return;
    }
    setState(() {
      _error = null;
      _sendingId = device.id;
    });
    try {
      await widget.nearby.sendCode(device, code);
      if (mounted) setState(() => _sentTo = device.label);
    } on NearbyException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = 'Não foi possível enviar: $e');
    } finally {
      if (mounted) setState(() => _sendingId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Divider(height: 32),
        Text('Ou envie por Bluetooth', style: text.titleSmall),
        const SizedBox(height: 4),
        Text(
          'No aparelho do filho, escolha "Receber código por Bluetooth". '
          'Depois toque nele aqui.',
          style: text.bodySmall,
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          key: const Key('nearbyButton'),
          onPressed: _scanning ? _stop : _search,
          icon: Icon(_scanning ? Icons.stop : Icons.bluetooth_searching),
          label: Text(_scanning ? 'Parar busca' : 'Procurar aparelhos por perto'),
        ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Notice(_error!, isError: true),
        ],
        if (_sentTo != null) ...[
          const SizedBox(height: 8),
          Notice('Código enviado para $_sentTo. Confirme no aparelho do filho.'),
        ],
        if (_scanning && _devices.isEmpty && _error == null) ...[
          const SizedBox(height: 12),
          const Center(child: SizedBox(
              height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))),
        ],
        for (final d in _devices)
          ListTile(
            key: Key('nearbyDevice_${d.id}'),
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.smartphone),
            title: Text(d.label),
            trailing: _sendingId == d.id
                ? const SizedBox(
                    height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.send),
            onTap: _sendingId == null ? () => _send(d) : null,
          ),
      ],
    );
  }
}
