import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guardiao/app.dart';
import 'package:guardiao/child/platform/installed_apps_source.dart';
import 'package:guardiao/child/usage/usage_monitor.dart';
import 'package:guardiao/qr/qr_scanner.dart';
import 'package:guardiao/role/role.dart';
import 'package:guardiao_core/guardiao_core.dart';

/// Leitor de QR falso: em vez da câmera, o teste "lê" o texto que quiser.
class FakeScanner implements QrScanner {
  FakeScanner({this.isSupported = true});

  final bool isSupported;
  ValueChanged<String>? _onCode;
  ValueChanged<String>? _onProblem;

  @override
  bool get supported => isSupported;

  @override
  Widget build(
    BuildContext context, {
    required ValueChanged<String> onCode,
    required ValueChanged<String> onProblem,
  }) {
    _onCode = onCode;
    _onProblem = onProblem;
    return const SizedBox(
      key: Key('fakeCamera'),
      height: 120,
      child: Center(child: Text('Câmera')),
    );
  }

  /// Simula a câmera lendo [text].
  void scan(String text) => _onCode!(text);

  /// Simula a câmera falhando (por exemplo, permissão negada).
  void fail(String message) => _onProblem!(message);
}

/// Abre o app inteiro já na função indicada (ou na tela de escolha, se `null`).
Widget appFor(
  GuardianBackend backend, {
  DeviceRole? role,
  RoleStore? store,
  InstalledAppsSource? source,
  QrScanner? scanner,
  UsageMonitor? monitor,
  bool isDemo = false,
}) => GuardiaoApp(
  backend: backend,
  roleStore: store ?? MemoryRoleStore(role),
  source: source ?? DemoAppsSource(),
  scanner: scanner ?? UnsupportedQrScanner(),
  monitor: monitor ?? UnsupportedUsageMonitor(),
  initialRole: role,
  isDemo: isDemo,
);

/// Desmonta a árvore para cancelar os temporizadores da sincronização.
Future<void> closeApp(WidgetTester tester) async =>
    tester.pumpWidget(const SizedBox());

/// Código que a tela do filho está mostrando agora (sem traço).
String shownPairingCode(WidgetTester tester) => normalizePairingCode(
  tester.widget<Text>(find.byKey(const Key('pairingCode'))).data!,
);
