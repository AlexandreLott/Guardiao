import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guardiao/nearby/nearby.dart';
import 'package:guardiao/parent/add_device_sheet.dart';
import 'package:guardiao/role/role.dart';
import 'package:guardiao_core/guardiao_core.dart';

import 'fake_nearby.dart';
import 'helpers.dart';

/// Responsável e filho são dois apps de verdade lado a lado, falando com a mesma
/// nuvem e com o mesmo "ar" de Bluetooth falso.
/// Avança o tempo sem esperar "assentar": a tela de espera tem um indicador
/// de progresso que gira para sempre, então pumpAndSettle nunca terminaria.
Future<void> flush(WidgetTester tester) async {
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  group('sem Bluetooth', () {
    testWidgets('o botão não aparece quando não há suporte', (tester) async {
      final backend = MemoryBackend(MemoryCloud());
      await tester.pumpWidget(appFor(backend, role: DeviceRole.child));
      await flush(tester);
      expect(find.byKey(const Key('nearbyReceiveButton')), findsNothing);
      await closeApp(tester);
    });
  });

  group('lado do filho', () {
    late MemoryCloud cloud;
    late MemoryBackend parent;
    late MemoryBackend childBackend;
    late FakeAir air;
    late FakeNearby childNearby;
    late FakeNearby parentNearby;

    setUp(() async {
      cloud = MemoryCloud();
      parent = MemoryBackend(cloud);
      await parent.registerParent('maria@exemplo.com', 'segredo1');
      childBackend = MemoryBackend(cloud);
      air = FakeAir();
      childNearby = FakeNearby(air);
      parentNearby = FakeNearby(air, address: 'AA:BB:CC:00:00:99', name: 'Pai');
    });

    Future<void> openSheet(WidgetTester tester) async {
      await tester.pumpWidget(appFor(childBackend, role: DeviceRole.child, nearby: childNearby));
      await flush(tester);
      await tester.ensureVisible(find.byKey(const Key('nearbyReceiveButton')));
      await tester.tap(find.byKey(const Key('nearbyReceiveButton')));
      await flush(tester);
    }

    testWidgets('fica visível, recebe o código, mostra quem enviou e vincula', (tester) async {
      final code = (await tester.runAsync(() async => parent.createPairingCode()))!;
      await openSheet(tester);

      expect(childNearby.lastPrepareAsChild, isTrue);
      expect(find.text('Esperando o responsável…'), findsOneWidget);
      expect(air.visible.values, ['Celular do Pedro']);

      await tester.runAsync(() async {
        await parentNearby.sendCode(
            const NearbyDevice(id: 'AA:BB:CC:00:00:01', name: 'Celular do Pedro'), code.code);
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await flush(tester);

      expect(find.text('Vincular a este responsável?'), findsOneWidget);
      expect(find.textContaining('ma***@exemplo.com'), findsOneWidget);

      await tester.tap(find.byKey(const Key('nearbyConfirm')));
      await flush(tester);
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await flush(tester);

      final devices = (await tester.runAsync(() => parent.watchDevices().first))!;
      expect(devices, hasLength(1));
      expect(air.visible, isEmpty, reason: 'sair da tela apaga o anúncio');
      await closeApp(tester);
    });

    testWidgets('recusar não vincula e continua esperando', (tester) async {
      final code = (await tester.runAsync(() async => parent.createPairingCode()))!;
      await openSheet(tester);
      await tester.runAsync(() async {
        await parentNearby.sendCode(
            const NearbyDevice(id: 'AA:BB:CC:00:00:01', name: 'x'), code.code);
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await flush(tester);

      await tester.tap(find.byKey(const Key('nearbyReject')));
      await flush(tester);

      expect(find.text('Esperando o responsável…'), findsOneWidget);
      final devices = (await tester.runAsync(() => parent.watchDevices().first))!;
      expect(devices, isEmpty);
      await closeApp(tester);
    });

    testWidgets('código expirado ou desconhecido mostra o motivo', (tester) async {
      await openSheet(tester);
      await tester.runAsync(() async {
        await parentNearby.sendCode(
            const NearbyDevice(id: 'AA:BB:CC:00:00:01', name: 'x'), 'ZZZZZZZZ');
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await flush(tester);
      expect(find.textContaining('Código não encontrado'), findsOneWidget);
      expect(find.text('Vincular a este responsável?'), findsNothing);
      await closeApp(tester);
    });

    testWidgets('permissão negada explica o que fazer', (tester) async {
      childNearby.status = NearbyStatus.denied;
      await openSheet(tester);
      expect(find.textContaining('permissão de Bluetooth'), findsOneWidget);
      expect(air.visible, isEmpty);
      await closeApp(tester);
    });

    testWidgets('Bluetooth desligado avisa', (tester) async {
      childNearby.status = NearbyStatus.off;
      await openSheet(tester);
      expect(find.textContaining('desligado'), findsOneWidget);
      await closeApp(tester);
    });
  });

  group('lado do responsável', () {
    late MemoryCloud cloud;
    late MemoryBackend parent;
    late FakeAir air;
    late FakeNearby parentNearby;
    late FakeNearby childNearby;

    setUp(() async {
      cloud = MemoryCloud();
      parent = MemoryBackend(cloud);
      await parent.registerParent('maria@exemplo.com', 'segredo1');
      air = FakeAir();
      parentNearby = FakeNearby(air, address: 'AA:BB:CC:00:00:99', name: 'Mãe');
      childNearby = FakeNearby(air);
    });

    /// Fecha a folha antes de desmontar o app, como o usuário faria.
    Future<void> closeSheetAndApp(WidgetTester tester) async {
      Navigator.of(tester.element(find.byType(AddDeviceSheet))).pop();
      await flush(tester);
      await closeApp(tester);
    }

    Future<void> openAddSheet(WidgetTester tester) async {
      await tester.pumpWidget(
          appFor(parent, role: DeviceRole.parent, nearby: parentNearby));
      await flush(tester);
      await tester.tap(find.byKey(const Key('addDeviceButton')));
      await flush(tester);
    }

    testWidgets('lista o aparelho do filho e envia o código mostrado na tela', (tester) async {
      final received = <String>[];
      // A assinatura fica aberta até o fim do teste (cancelá-la antes de
      // desmontar o app trava o ambiente de teste); o "ar" é descartado depois.
      childNearby.receiveCodes().listen(received.add);
      await openAddSheet(tester);

      await tester.ensureVisible(find.byKey(const Key('nearbyButton')));
      await tester.tap(find.byKey(const Key('nearbyButton')));
      await flush(tester);
      expect(parentNearby.lastPrepareAsChild, isFalse);

      final tile = find.byKey(const Key('nearbyDevice_AA:BB:CC:00:00:01'));
      expect(tile, findsOneWidget);
      expect(find.text('Celular do Pedro'), findsOneWidget);

      final shown = tester.widget<Text>(find.byKey(const Key('pairingCode'))).data!;
      await tester.ensureVisible(tile);
      await tester.tap(tile);
      await flush(tester);
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));

      expect(received, [normalizePairingCode(shown)]);
      expect(find.textContaining('Código enviado para Celular do Pedro'), findsOneWidget);

      await closeSheetAndApp(tester);
    });

    testWidgets('falha no envio mostra o erro e deixa tentar de novo', (tester) async {
      childNearby.receiveCodes().listen((_) {});
      parentNearby.failSend = true;
      await openAddSheet(tester);
      await tester.ensureVisible(find.byKey(const Key('nearbyButton')));
      await tester.tap(find.byKey(const Key('nearbyButton')));
      await flush(tester);

      final tile = find.byKey(const Key('nearbyDevice_AA:BB:CC:00:00:01'));
      await tester.ensureVisible(tile);
      await tester.tap(tile);
      await flush(tester);
      expect(find.textContaining('Não foi possível conectar'), findsOneWidget);

      parentNearby.failSend = false;
      await tester.ensureVisible(tile);
      await tester.tap(tile);
      await flush(tester);
      expect(find.textContaining('Código enviado'), findsOneWidget);

      await closeSheetAndApp(tester);
    });

    testWidgets('Bluetooth desligado: mostra o aviso e não procura', (tester) async {
      parentNearby.status = NearbyStatus.off;
      await openAddSheet(tester);
      await tester.ensureVisible(find.byKey(const Key('nearbyButton')));
      await tester.tap(find.byKey(const Key('nearbyButton')));
      await flush(tester);
      expect(find.textContaining('desligado'), findsOneWidget);
      await closeSheetAndApp(tester);
    });
  });
}
