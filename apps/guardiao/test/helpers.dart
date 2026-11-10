import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guardiao/app.dart';
import 'package:guardiao/child/platform/installed_apps_source.dart';
import 'package:guardiao/common/pin.dart';
import 'package:guardiao/child/usage/usage_monitor.dart';
import 'package:guardiao/qr/qr_scanner.dart';
import 'package:guardiao/role/role.dart';
import 'package:guardiao/watch/background_tasks.dart';
import 'package:guardiao/watch/health_source.dart';
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
  HealthSource? healthSource,
  HealthStore? healthStore,
  BackgroundTasks? background,
  PinStore? pinStore,
}) => GuardiaoApp(
  backend: backend,
  roleStore: store ?? MemoryRoleStore(role),
  source: source ?? DemoAppsSource(),
  scanner: scanner ?? UnsupportedQrScanner(),
  monitor: monitor ?? UnsupportedUsageMonitor(),
  initialRole: role,
  isDemo: isDemo,
  healthSource: healthSource,
  healthStore: healthStore,
  background: background,
  pinStore: pinStore,
);

/// Desmonta a árvore para cancelar os temporizadores da sincronização.
Future<void> closeApp(WidgetTester tester) async =>
    tester.pumpWidget(const SizedBox());

/// Código que a tela do filho está mostrando agora (sem traço).
String shownPairingCode(WidgetTester tester) => normalizePairingCode(
  tester.widget<Text>(find.byKey(const Key('pairingCode'))).data!,
);

/// Registra as chamadas de ligar/desligar a verificação em segundo plano.
class RecordingBackground implements BackgroundTasks {
  final calls = <String>[];

  @override
  Future<void> enable(DeviceRole role) async =>
      calls.add('enable:${role.name}');

  @override
  Future<void> disable() async => calls.add('disable');
}

/// Tela alta, para que listas e folhas longas caibam sem rolar.
void tallScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

/// No aparelho do filho: gera o código, o responsável aprova e a tela
/// "Tudo pronto!" leva para a tela principal.
Future<void> pairThroughWizard(
  WidgetTester tester,
  GuardianBackend parent,
) async {
  await tester.ensureVisible(find.byKey(const Key('generateButton')));
  await tester.tap(find.byKey(const Key('generateButton')));
  await tester.pumpAndSettle();
  // Se faltam permissões, o passo delas vem antes do QR.
  if (find.byKey(const Key('permissionsContinue')).evaluate().isNotEmpty) {
    for (final k in const ['permUsage', 'permOverlay']) {
      final row = find.byKey(Key(k));
      final on = tester
          .widget<Switch>(
            find.descendant(of: row, matching: find.byType(Switch)),
          )
          .value;
      if (!on) {
        await tester.tap(
          find.descendant(of: row, matching: find.byType(Switch)),
        );
        await tester.pumpAndSettle();
      }
    }
    await tester.tap(find.byKey(const Key('permissionsContinue')));
    await tester.pumpAndSettle();
  }
  await parent.approvePairRequest(shownPairingCode(tester));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('linkedContinue')));
  await tester.pumpAndSettle();
}
