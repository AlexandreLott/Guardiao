import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guardiao/role/role.dart';
import 'package:guardiao_core/guardiao_core.dart';

import 'helpers.dart';

void main() {
  Future<void> openDevice(WidgetTester tester) async {
    tallScreen(tester);
    final setup = (await tester.runAsync(createBackend))!;
    await tester.pumpWidget(
      appFor(setup.backend, role: DeviceRole.parent, isDemo: true),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('submitButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Celular do Pedro (exemplo)'));
    await tester.pumpAndSettle();
  }

  Future<void> typePin(WidgetTester tester, String pin) async {
    for (final d in pin.split('')) {
      await tester.tap(find.byKey(Key('pin_$d')));
      await tester.pump();
    }
    await tester.tap(find.byKey(const Key('pin_ok')));
    await tester.pumpAndSettle();
  }

  testWidgets('o responsável vê as mesmas telas da criança', (tester) async {
    await openDevice(tester);
    // As quatro abas da criança, e nada do painel antes do PIN.
    for (final k in const [
      'nav_home',
      'nav_report',
      'nav_credits',
      'nav_guardian',
    ]) {
      expect(find.byKey(Key(k)), findsOneWidget);
    }
    expect(find.text('Jogos monitorados'), findsOneWidget);
    expect(find.text('Painel do responsável'), findsNothing);

    await tester.tap(find.byKey(const Key('nav_report')));
    await tester.pumpAndSettle();
    expect(find.text('Relatório'), findsWidgets);
    expect(find.text('Painel do responsável'), findsNothing);
    await closeApp(tester);
  });

  testWidgets('o painel só abre com o PIN e tranca ao sair da aba', (
    tester,
  ) async {
    await openDevice(tester);
    await tester.tap(find.byKey(const Key('nav_guardian')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('enterPin')), findsOneWidget);
    expect(find.byKey(const Key('seg_1')), findsNothing);

    await typePin(tester, '0000');
    expect(find.text('PIN incorreto.'), findsOneWidget);
    expect(find.byKey(const Key('seg_1')), findsNothing);

    await typePin(tester, '1234');
    expect(find.byKey(const Key('seg_1')), findsOneWidget);
    expect(find.text('Limites, rotinas e créditos'), findsOneWidget);

    // Sair da aba e voltar pede o PIN de novo.
    await tester.tap(find.byKey(const Key('nav_home')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('nav_guardian')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('enterPin')), findsOneWidget);
    await closeApp(tester);
  });
}
