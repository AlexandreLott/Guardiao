import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guardiao/role/role.dart';
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

  testWidgets('começa pedindo o código de pareamento', (tester) async {
    await openApp(tester);
    expect(find.text('Vincular este aparelho'), findsOneWidget);
    expect(find.byKey(const Key('codeField')), findsOneWidget);
    await closeApp(tester);
  });

  testWidgets('código curto mostra o erro sem consultar a nuvem', (tester) async {
    await openApp(tester);
    await tester.enterText(find.byKey(const Key('codeField')), 'ab12');
    await tester.tap(find.byKey(const Key('claimButton')));
    await tester.pump();
    expect(find.textContaining('8 letras e números'), findsOneWidget);
    await closeApp(tester);
  });

  testWidgets('código desconhecido mostra mensagem do servidor', (tester) async {
    await openApp(tester);
    await tester.enterText(find.byKey(const Key('codeField')), 'AAAAAAAA');
    await tester.tap(find.byKey(const Key('claimButton')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Código não encontrado'), findsOneWidget);
    await closeApp(tester);
  });

  testWidgets('formata o código com traço enquanto digita', (tester) async {
    await openApp(tester);
    await tester.enterText(find.byKey(const Key('codeField')), 'k7m29qxa');
    await tester.pump();
    expect(find.text('K7M2-9QXA'), findsOneWidget);
    await closeApp(tester);
  });

  testWidgets('pareia, envia os apps e mostra os limites do responsável', (tester) async {
    final code = await parent.createPairingCode();
    await openApp(tester);

    await tester.enterText(find.byKey(const Key('codeField')), code.code.toLowerCase());
    await tester.tap(find.byKey(const Key('claimButton')));
    await tester.pumpAndSettle();

    // Entrou na tela principal e o responsável já enxerga os apps do aparelho.
    expect(find.text('Seu tempo de hoje'), findsOneWidget);
    final device = (await tester.runAsync(() => parent.watchDevices().first))!.single;
    final apps = (await tester.runAsync(() => parent.watchApps(device.id).first))!;
    expect(apps.map((a) => a.name), containsAll(['Roblox', 'Minecraft', 'Free Fire']));

    // O responsável define um limite e outro bloqueio: aparecem na hora.
    await parent.setRule(device.id, const AppRule(appId: 'demo.roblox', dailyLimitMinutes: 90));
    await parent.setRule(device.id, const AppRule(appId: 'demo.freefire', blocked: true));
    await tester.pumpAndSettle();
    expect(find.text('Usou 0 min de 1 h 30 min hoje'), findsOneWidget);
    expect(find.text('1 h 30 min restantes'), findsOneWidget);
    expect(find.text('Bloqueado pelo responsável'), findsOneWidget);
    expect(find.text('Sem limite (2)'), findsOneWidget);

    // Se o responsável remove o aparelho, o app volta a pedir o código.
    await parent.removeDevice(device.id);
    await tester.pumpAndSettle();
    expect(find.text('Vincular este aparelho'), findsOneWidget);
    await closeApp(tester);
  });
}
