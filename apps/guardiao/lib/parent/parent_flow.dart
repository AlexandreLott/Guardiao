import 'package:flutter/material.dart';
import 'package:guardiao_core/guardiao_core.dart';

import '../nearby/nearby.dart';
import 'devices_screen.dart';
import 'login_screen.dart';

/// Lado do responsável: entrar na conta e, depois, a lista de aparelhos.
class ParentFlow extends StatelessWidget {
  const ParentFlow({
    super.key,
    required this.backend,
    required this.onChangeRole,
    required this.nearby,
    this.isDemo = false,
  });

  final GuardianBackend backend;
  final NearbyPairing nearby;
  final VoidCallback onChangeRole;
  final bool isDemo;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<String?>(
      stream: backend.authStateChanges(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snap.data == null) {
          return LoginScreen(
            backend: backend,
            isDemo: isDemo,
            onChangeRole: onChangeRole,
          );
        }
        return DevicesScreen(
          key: ValueKey(snap.data),
          backend: backend,
          nearby: nearby,
          isDemo: isDemo,
          onChangeRole: onChangeRole,
        );
      },
    );
  }
}
