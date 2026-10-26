import 'package:flutter/material.dart';
import 'package:guardiao_core/guardiao_core.dart';

import 'screens/devices_screen.dart';
import 'screens/login_screen.dart';

class ParentApp extends StatelessWidget {
  const ParentApp({super.key, required this.backend, this.isDemo = false});

  final GuardianBackend backend;
  final bool isDemo;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Guardião Gamer — Responsável',
      debugShowCheckedModeBanner: false,
      theme: guardiaoTheme(Brightness.light),
      darkTheme: guardiaoTheme(Brightness.dark),
      home: StreamBuilder<String?>(
        stream: backend.authStateChanges(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          if (snap.data == null) {
            return LoginScreen(backend: backend, isDemo: isDemo);
          }
          return DevicesScreen(
            key: ValueKey(snap.data),
            backend: backend,
            isDemo: isDemo,
          );
        },
      ),
    );
  }
}
