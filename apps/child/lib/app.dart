import 'package:flutter/material.dart';
import 'package:guardiao_core/guardiao_core.dart';

import 'platform/installed_apps_source.dart';
import 'screens/home_screen.dart';
import 'screens/pairing_screen.dart';

class ChildApp extends StatelessWidget {
  const ChildApp({
    super.key,
    required this.backend,
    required this.source,
    this.isDemo = false,
  });

  final GuardianBackend backend;
  final InstalledAppsSource source;
  final bool isDemo;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Guardião Gamer',
      debugShowCheckedModeBanner: false,
      theme: guardiaoTheme(Brightness.light),
      darkTheme: guardiaoTheme(Brightness.dark),
      home: ChildGate(backend: backend, source: source, isDemo: isDemo),
    );
  }
}

/// Decide a tela: entrando na conta, pedindo o código ou mostrando o tempo.
class ChildGate extends StatefulWidget {
  const ChildGate({
    super.key,
    required this.backend,
    required this.source,
    required this.isDemo,
  });

  final GuardianBackend backend;
  final InstalledAppsSource source;
  final bool isDemo;

  @override
  State<ChildGate> createState() => _ChildGateState();
}

class _ChildGateState extends State<ChildGate> {
  late Future<void> _signIn;
  Stream<PairedDevice?>? _device;

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
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
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
            if (!snap.hasData && snap.connectionState != ConnectionState.active) {
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }
            final device = snap.data;
            if (device == null) {
              return PairingScreen(
                backend: widget.backend,
                source: widget.source,
                isDemo: widget.isDemo,
              );
            }
            return HomeScreen(
              key: ValueKey(device.id),
              backend: widget.backend,
              source: widget.source,
              device: device,
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
                FilledButton(onPressed: onRetry, child: const Text('Tentar de novo')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
