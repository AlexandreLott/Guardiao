import 'package:flutter/material.dart';
import 'package:guardiao_core/guardiao_core.dart';

import '../common/pin.dart';
import '../watch/health_source.dart';
import 'platform/installed_apps_source.dart';
import 'usage/usage_monitor.dart';
import 'screens/home_screen.dart';
import 'screens/linked_screen.dart';
import 'screens/pairing_screen.dart';

/// Lado do filho. Decide a tela: entrando na conta, mostrando o QR de
/// vínculo ou mostrando o tempo.
class ChildGate extends StatefulWidget {
  const ChildGate({
    super.key,
    required this.backend,
    required this.source,
    required this.onChangeRole,
    required this.monitor,
    this.isDemo = false,
    this.healthSource,
    this.healthStore,
    this.pinStore,
  });

  /// Se informado, o aparelho confere as proteções e avisa o responsável.
  final HealthSource? healthSource;
  final HealthStore? healthStore;
  final PinStore? pinStore;

  final GuardianBackend backend;
  final UsageMonitor monitor;
  final InstalledAppsSource source;
  final VoidCallback onChangeRole;
  final bool isDemo;

  @override
  State<ChildGate> createState() => _ChildGateState();
}

class _ChildGateState extends State<ChildGate> {
  late Future<void> _signIn;
  Stream<PairedDevice?>? _device;

  /// A tela de vínculo foi mostrada: ao ser vinculado, comemora antes da home.
  bool _sawPairing = false;
  bool _linkedAck = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  void _start() {
    _signIn = widget.backend.signInChild().then((_) {
      _device = widget.backend.watchOwnDevice();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _signIn,
      builder: (context, signIn) {
        if (signIn.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (signIn.hasError) {
          return _ConnectionError(
            message: '${signIn.error}',
            onRetry: () => setState(_start),
          );
        }
        return StreamBuilder<PairedDevice?>(
          stream: _device,
          builder: (context, snap) {
            if (snap.hasError) {
              return _ConnectionError(
                message: 'Sem conexão com o servidor. ${snap.error}',
                onRetry: () => setState(_start),
              );
            }
            if (!snap.hasData &&
                snap.connectionState != ConnectionState.active) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }
            final device = snap.data;
            if (device == null) {
              _sawPairing = true;
              _linkedAck = false;
              return PairingScreen(
                backend: widget.backend,
                source: widget.source,
                isDemo: widget.isDemo,
                monitor: widget.monitor,
                onChangeRole: widget.onChangeRole,
              );
            }
            if (_sawPairing && !_linkedAck) {
              return LinkedScreen(
                onContinue: () => setState(() => _linkedAck = true),
              );
            }
            return HomeScreen(
              key: ValueKey(device.id),
              backend: widget.backend,
              source: widget.source,
              monitor: widget.monitor,
              device: device,
              healthSource: widget.healthSource,
              healthStore: widget.healthStore,
              pinStore: widget.pinStore,
              isDemo: widget.isDemo,
            );
          },
        );
      },
    );
  }
}

class _ConnectionError extends StatelessWidget {
  const _ConnectionError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Notice(message, isError: true),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: onRetry,
                  child: const Text('Tentar de novo'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
