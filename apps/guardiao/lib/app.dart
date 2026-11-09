import 'package:flutter/material.dart';
import 'package:guardiao_core/guardiao_core.dart';

import 'child/child_flow.dart';
import 'child/platform/installed_apps_source.dart';
import 'child/usage/usage_monitor.dart';
import 'parent/parent_flow.dart';
import 'qr/qr_scanner.dart';
import 'role/role.dart';
import 'role/role_screen.dart';
import 'update/update_bar.dart';
import 'update/update_controller.dart';

/// O app inteiro: escolhe a função do aparelho no primeiro acesso e depois
/// abre o lado do responsável ou o do filho.
class GuardiaoApp extends StatefulWidget {
  const GuardiaoApp({
    super.key,
    required this.backend,
    required this.roleStore,
    required this.source,
    required this.scanner,
    required this.monitor,
    this.initialRole,
    this.isDemo = false,
    this.updates,
  });

  final GuardianBackend backend;
  final RoleStore roleStore;
  final InstalledAppsSource source;
  final QrScanner scanner;
  final UsageMonitor monitor;
  final DeviceRole? initialRole;
  final bool isDemo;

  /// Aviso e instalação de versões novas (só no Android).
  final UpdateController? updates;

  @override
  State<GuardiaoApp> createState() => _GuardiaoAppState();
}

class _GuardiaoAppState extends State<GuardiaoApp> {
  late DeviceRole? _role = widget.initialRole;

  Future<void> _pick(DeviceRole role) async {
    await widget.roleStore.write(role);
    if (mounted) setState(() => _role = role);
  }

  /// Volta para a tela de escolha. Sai da conta antes, para que um aparelho
  /// não fique com o login do outro lado.
  Future<void> _changeRole() async {
    await widget.backend.signOut();
    await widget.roleStore.write(null);
    if (mounted) setState(() => _role = null);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Guardião Gamer',
      debugShowCheckedModeBanner: false,
      theme: guardiaoTheme(Brightness.light),
      darkTheme: guardiaoTheme(Brightness.dark),
      builder: (context, child) =>
          UpdateHost(controller: widget.updates, child: child!),
      home: switch (_role) {
        null => RoleScreen(onPick: _pick),
        DeviceRole.parent => ParentFlow(
          key: const ValueKey('parent'),
          backend: widget.backend,
          scanner: widget.scanner,
          isDemo: widget.isDemo,
          onChangeRole: _changeRole,
        ),
        DeviceRole.child => ChildGate(
          key: const ValueKey('child'),
          backend: widget.backend,
          source: widget.source,
          monitor: widget.monitor,
          isDemo: widget.isDemo,
          onChangeRole: _changeRole,
        ),
      },
    );
  }
}
