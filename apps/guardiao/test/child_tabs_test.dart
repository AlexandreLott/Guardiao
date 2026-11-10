import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guardiao/child/usage/usage_monitor.dart';
import 'package:guardiao/common/pin.dart';
import 'package:guardiao/role/role.dart';
import 'package:guardiao_core/guardiao_core.dart';

import 'helpers.dart';

void main() {
  late MemoryCloud cloud;
  late MemoryBackend parent;
  late MemoryBackend childBackend;
  late DemoUsageMonitor monitor;
  late PairedDevice device;

  setUp(() async {
    cloud = MemoryCloud();
    parent = MemoryBackend(cloud);
    await parent.registerParent('mae@exemplo.com', 'segredo1');
    childBackend = MemoryBackend(cloud);
    monitor = DemoUsageMonitor();
  });

  Future<void> openChild(WidgetTester tester, {PinStore? pin}) async {
    tallScreen(tester);
    await tester.pumpWidget(
      appFor(
        childBackend,
        role: DeviceRole.child,
        monitor: monitor,
        pinStore: pin ?? MemoryPinStore(),
      ),
    );
    await tester.pumpAndSettle();
    await pairThroughWizard(tester, parent);
    device = (await tester.runAsync(() => parent.watchDevices().first))!.single;
  }

  Future<void> goTo(WidgetTester tester, String nav) async {
    await tester.tap(find.byKey(Key(nav)));
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

  testWidgets('as quatro abas do filho abrem', (tester) async {
    await openChild(tester);
    await goTo(tester, 'nav_report');
    expect(find.text('Relatório'), findsWidgets);
    await goTo(tester, 'nav_credits');
    expect(find.byKey(const Key('creditTotal')), findsOneWidget);
    await goTo(tester, 'nav_guardian');
    expect(find.byKey(const Key('createPin')), findsOneWidget);
    await goTo(tester, 'nav_home');
    expect(find.text('Tempo de tela hoje'), findsOneWidget);
    await closeApp(tester);
  });

  group('créditos', () {
    testWidgets('missão feita espera aprovação e vira tempo extra', (
      tester,
    ) async {
      await openChild(tester);
      await parent.saveConfig(
        device.id,
        const DeviceConfig(
          missions: [Mission(id: 'm1', title: 'Arrumar o quarto', minutes: 30)],
        ),
      );
      await parent.setRule(
        device.id,
        const AppRule(appId: 'demo.roblox', dailyLimitMinutes: 60),
      );
      await tester.pump();
      await goTo(tester, 'nav_credits');
      expect(find.text('0 min'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('useCreditButton')))
            .onPressed,
        isNull,
      );

      await tester.tap(find.byKey(const Key('claim_m1')));
      await tester.pumpAndSettle();
      expect(find.text('Esperando aprovação'), findsOneWidget);

      final claim = (await tester.runAsync(
        () => parent.watchClaims(device.id).first,
      ))!.single;
      expect(claim.title, 'Arrumar o quarto');
      await parent.decideClaim(device.id, claim.id, true);
      await tester.pumpAndSettle();
      expect(
        tester.widget<Text>(find.byKey(const Key('creditTotal'))).data,
        '30 min',
      );

      await tester.tap(find.byKey(const Key('useCreditButton')));
      await tester.pumpAndSettle();
      expect(
        tester.widget<Text>(find.byKey(const Key('creditTotal'))).data,
        '0 min',
      );
      // O bônus de hoje chega ao medidor nativo: 60 + 30 minutos.
      await tester.pump(const Duration(seconds: 31));
      await tester.pump();
      expect(monitor.startedExtras.bonusMinutes, 30);
      expect(monitor.started.single.limitMinutes, 60);
      await closeApp(tester);
    });

    testWidgets('sem permissão para pedir, não há botão "Fiz!"', (
      tester,
    ) async {
      await openChild(tester);
      await parent.saveConfig(
        device.id,
        const DeviceConfig(
          allowRequests: false,
          missions: [Mission(id: 'm1', title: 'Arrumar o quarto', minutes: 30)],
        ),
      );
      await tester.pump();
      await goTo(tester, 'nav_credits');
      expect(find.byKey(const Key('claim_m1')), findsNothing);
      await closeApp(tester);
    });
  });

  group('painel do responsável no aparelho do filho (PIN)', () {
    testWidgets('cria o PIN, tranca e destranca só com o PIN certo', (
      tester,
    ) async {
      final store = MemoryPinStore();
      await openChild(tester, pin: store);
      await goTo(tester, 'nav_guardian');
      await typePin(tester, '4321');
      expect(await tester.runAsync(() => store.hasPin()), isTrue);
      expect(find.byKey(const Key('lockPanelButton')), findsOneWidget);

      await tester.ensureVisible(find.byKey(const Key('lockPanelButton')));
      await tester.tap(find.byKey(const Key('lockPanelButton')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('enterPin')), findsOneWidget);

      await typePin(tester, '1111');
      expect(find.text('PIN incorreto.'), findsOneWidget);
      expect(find.byKey(const Key('enterPin')), findsOneWidget);

      await typePin(tester, '4321');
      expect(find.byKey(const Key('lockPanelButton')), findsOneWidget);
      await closeApp(tester);
    });

    testWidgets('a criança não consegue mudar regras por este painel', (
      tester,
    ) async {
      await openChild(tester, pin: MemoryPinStore('1234'));
      await goTo(tester, 'nav_guardian');
      await typePin(tester, '1234');
      // A conta do filho é anônima: as regras não aceitam escrita dela.
      await tester.runAsync(
        () => expectLater(
          childBackend.saveConfig(device.id, const DeviceConfig(lockAll: true)),
          throwsA(anything),
        ),
      );
      await closeApp(tester);
    });

    testWidgets('trocar o PIN exige o novo PIN de 4 números', (tester) async {
      final store = MemoryPinStore('1234');
      await openChild(tester, pin: store);
      await goTo(tester, 'nav_guardian');
      await typePin(tester, '1234');
      await tester.ensureVisible(find.byKey(const Key('changePinRow')));
      await tester.tap(find.byKey(const Key('changePinRow')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('changePin')), findsOneWidget);
      await typePin(tester, '9876');
      expect(await tester.runAsync(() => store.verify('9876')), isTrue);
      expect(await tester.runAsync(() => store.verify('1234')), isFalse);
      await closeApp(tester);
    });
  });

  testWidgets('relatório mostra o uso e muda de período', (tester) async {
    await openChild(tester);
    monitor.simulate('demo.roblox', 40);
    await tester.pump(const Duration(seconds: 31));
    await tester.pump();
    await goTo(tester, 'nav_report');
    expect(find.textContaining('40 min'), findsWidgets);
    await closeApp(tester);
  });
}
