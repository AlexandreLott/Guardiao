import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guardiao/role/role.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'helpers.dart';

import 'package:guardiao_core/guardiao_core.dart';

void main() {
  late MemoryCloud cloud;
  late MemoryBackend parent;
  late MemoryBackend childBackend;

  setUp(() async {
    cloud = MemoryCloud();
    parent = MemoryBackend(cloud);
    await parent.registerParent('mae@exemplo.com', 'segredo1');
    childBackend = MemoryBackend(cloud);
  });

  Future<void> openApp(WidgetTester tester) async {
    await tester.pumpWidget(appFor(childBackend, role: DeviceRole.child));
    await tester.pumpAndSettle();
  }

  Future<void> tapNewCode(WidgetTester tester) async {
    await tester.ensureVisible(find.byKey(const Key('newCodeButton')));
    await tester.tap(find.byKey(const Key('newCodeButton')));
    await tester.pumpAndSettle();
  }

  testWidgets('começa mostrando o QR e o código de vínculo', (tester) async {
    await openApp(tester);
    expect(find.text('Vincular este aparelho'), findsOneWidget);
    expect(find.byKey(const Key('pairingQr')), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const Key('pairingCode'))).data,
      matches(RegExp(r'^[A-Z2-9]{4}-[A-Z2-9]{4}$')),
    );
    expect(find.textContaining('Vale por mais'), findsOneWidget);
    await closeApp(tester);
  });

  testWidgets('o QR carrega o mesmo código que está escrito na tela', (
    tester,
  ) async {
    await openApp(tester);
    expect(find.byType(QrImageView), findsOneWidget);
    final code = shownPairingCode(tester);
    expect(find.byKey(ValueKey(pairingQrPayload(code))), findsOneWidget);
    expect(parsePairingQr(pairingQrPayload(code)), code);
    await closeApp(tester);
  });

  testWidgets('o código gerado já está disponível para o responsável', (
    tester,
  ) async {
    await openApp(tester);
    final preview = await parent.previewPairRequest(shownPairingCode(tester));
    expect(preview.platform, DevicePlatform.other); // fonte de demonstração
    expect(preview.deviceName, isNotEmpty);
    await closeApp(tester);
  });

  testWidgets('"Gerar novo código" troca o código e cancela o anterior', (
    tester,
  ) async {
    await openApp(tester);
    final first = shownPairingCode(tester);
    await tapNewCode(tester);
    final second = shownPairingCode(tester);
    expect(second, isNot(first));
    await expectLater(
      parent.previewPairRequest(first),
      throwsA(isA<PairingException>()),
    );
    await parent.previewPairRequest(second);
    await closeApp(tester);
  });

  testWidgets('o nome digitado vai para o pedido', (tester) async {
    await openApp(tester);
    await tester.enterText(
      find.byKey(const Key('nameField')),
      'Notebook da Ana',
    );
    await tapNewCode(tester);
    final preview = await parent.previewPairRequest(shownPairingCode(tester));
    expect(preview.deviceName, 'Notebook da Ana');
    await closeApp(tester);
  });

  testWidgets('nome vazio não gera código', (tester) async {
    await openApp(tester);
    await tester.ensureVisible(find.byKey(const Key('nameField')));
    await tester.enterText(find.byKey(const Key('nameField')), '  ');
    await tapNewCode(tester);
    expect(find.text('Dê um nome para este aparelho.'), findsOneWidget);
    await closeApp(tester);
  });

  testWidgets('pareia, envia os apps e mostra os limites do responsável', (
    tester,
  ) async {
    await openApp(tester);

    // O responsável lê o QR e aprova; a tela do filho muda sozinha.
    await parent.approvePairRequest(shownPairingCode(tester));
    await tester.pumpAndSettle();

    // Entrou na tela principal e o responsável já enxerga os apps do aparelho.
    expect(find.text('Seu tempo de hoje'), findsOneWidget);
    await tester.scrollUntilVisible(find.byKey(const Key('parentLabel')), 300);
    expect(find.text('Responsável: ma***@exemplo.com'), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, 2000));
    await tester.pumpAndSettle();
    final device = (await tester.runAsync(() => parent.watchDevices().first))!
        .single;
    final apps = (await tester.runAsync(
      () => parent.watchApps(device.id).first,
    ))!;
    expect(
      apps.map((a) => a.name),
      containsAll(['Roblox', 'Minecraft', 'Free Fire']),
    );

    // O responsável define um limite e outro bloqueio: aparecem na hora.
    await parent.setRule(
      device.id,
      const AppRule(appId: 'demo.roblox', dailyLimitMinutes: 90),
    );
    await parent.setRule(
      device.id,
      const AppRule(appId: 'demo.freefire', blocked: true),
    );
    await tester.pumpAndSettle();
    expect(find.text('Usou 0 min de 1 h 30 min hoje'), findsOneWidget);
    expect(find.text('1 h 30 min restantes'), findsOneWidget);
    expect(find.text('Bloqueado pelo responsável'), findsOneWidget);
    expect(find.text('Sem limite (2)'), findsOneWidget);

    // Se o responsável remove o aparelho, o app volta a mostrar o QR.
    await parent.removeDevice(device.id);
    await tester.pumpAndSettle();
    expect(find.text('Vincular este aparelho'), findsOneWidget);
    expect(find.byKey(const Key('pairingQr')), findsOneWidget);
    await closeApp(tester);
  });
}
