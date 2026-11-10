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

  Future<void> tapGenerate(WidgetTester tester) async {
    await tester.ensureVisible(find.byKey(const Key('generateButton')));
    await tester.tap(find.byKey(const Key('generateButton')));
    await tester.pumpAndSettle();
  }

  /// Abre o app e avança do nome até a tela do QR.
  Future<void> openQr(WidgetTester tester) async {
    await openApp(tester);
    await tapGenerate(tester);
  }

  Future<void> tapNewCode(WidgetTester tester) async {
    await tester.ensureVisible(find.byKey(const Key('newCodeButton')));
    await tester.tap(find.byKey(const Key('newCodeButton')));
    await tester.pumpAndSettle();
  }

  testWidgets('começa mostrando o QR e o código de vínculo', (tester) async {
    await openQr(tester);
    expect(find.text('Mostre para o responsável'), findsOneWidget);
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
    await openQr(tester);
    expect(find.byType(QrImageView), findsOneWidget);
    final code = shownPairingCode(tester);
    expect(find.byKey(ValueKey(pairingQrPayload(code))), findsOneWidget);
    expect(parsePairingQr(pairingQrPayload(code)), code);
    await closeApp(tester);
  });

  testWidgets('o código gerado já está disponível para o responsável', (
    tester,
  ) async {
    await openQr(tester);
    final preview = await parent.previewPairRequest(shownPairingCode(tester));
    expect(preview.platform, DevicePlatform.other); // fonte de demonstração
    expect(preview.deviceName, isNotEmpty);
    await closeApp(tester);
  });

  testWidgets('"Gerar novo código" troca o código e cancela o anterior', (
    tester,
  ) async {
    await openQr(tester);
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
    await tapGenerate(tester);
    final preview = await parent.previewPairRequest(shownPairingCode(tester));
    expect(preview.deviceName, 'Notebook da Ana');
    await closeApp(tester);
  });

  testWidgets('nome vazio não gera código', (tester) async {
    await openApp(tester);
    await tester.ensureVisible(find.byKey(const Key('nameField')));
    await tester.enterText(find.byKey(const Key('nameField')), '  ');
    await tapGenerate(tester);
    expect(find.text('Dê um nome para este aparelho.'), findsOneWidget);
    await closeApp(tester);
  });

  testWidgets('pareia, envia os apps e mostra os limites do responsável', (
    tester,
  ) async {
    tallScreen(tester);
    await openQr(tester);

    // O responsável lê o QR e aprova; a tela do filho muda sozinha.
    await parent.approvePairRequest(shownPairingCode(tester));
    await tester.pumpAndSettle();
    expect(find.text('Tudo pronto!'), findsOneWidget);
    await tester.tap(find.byKey(const Key('linkedContinue')));
    await tester.pumpAndSettle();

    // Entrou na tela principal e o responsável já enxerga os apps do aparelho.
    expect(find.text('Tempo de tela hoje'), findsOneWidget);
    await tester.scrollUntilVisible(find.byKey(const Key('parentLabel')), 300);
    expect(find.text('Responsável: ma***@exemplo.com'), findsOneWidget);
    await tester.drag(find.byType(ListView).first, const Offset(0, 2000));
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
    expect(find.text('0 min de 1h 30min hoje'), findsOneWidget);
    expect(find.text('Dentro do limite'), findsOneWidget);
    expect(find.text('Bloqueado pelo responsável'), findsOneWidget);
    expect(find.text('Sem limite (2)'), findsOneWidget);

    // Se o responsável remove o aparelho, o app volta a mostrar o QR.
    await parent.removeDevice(device.id);
    await tester.pumpAndSettle();
    expect(find.text('Vincular este aparelho'), findsOneWidget);
    await closeApp(tester);
  });
}
