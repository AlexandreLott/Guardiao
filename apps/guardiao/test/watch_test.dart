import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guardiao/child/usage/usage_monitor.dart';
import 'package:guardiao/role/role.dart';
import 'package:guardiao/watch/child_watch.dart';
import 'package:guardiao/watch/health_source.dart';
import 'package:guardiao/watch/parent_watch.dart';
import 'package:guardiao_core/guardiao_core.dart';

import 'helpers.dart';

DeviceHealth health({
  bool usageAccess = true,
  bool overlay = true,
  bool notifications = true,
  bool admin = true,
  bool monitorRunning = true,
  DateTime? at,
}) => DeviceHealth(
  usageAccess: usageAccess,
  overlay: overlay,
  notifications: notifications,
  admin: admin,
  monitorRunning: monitorRunning,
  checkedAt: at ?? DateTime(2026, 11, 9, 10),
);

void main() {
  late DateTime clock;
  late MemoryCloud cloud;
  late MemoryBackend parent;
  late MemoryBackend child;
  late PairedDevice paired;

  setUp(() async {
    clock = DateTime.now();
    cloud = MemoryCloud(now: () => clock);
    parent = MemoryBackend(cloud);
    child = MemoryBackend(cloud);
    await parent.registerParent('mae@exemplo.com', 'segredo1');
    await child.signInChild();
    final request = await child.createPairRequest(
      deviceName: 'Celular do Pedro',
      platform: DevicePlatform.android,
    );
    paired = await parent.approvePairRequest(request.code);
  });

  group('leitura da situação gravada pelo Android', () {
    test('lê o JSON do serviço', () {
      final h = parseHealth(
        '{"usageAccess":true,"overlay":false,"notifications":true,'
        '"admin":false,"monitorRunning":true,"checkedAt":42}',
      );
      expect(h!.overlay, isFalse);
      expect(h.usageAccess, isTrue);
      expect(h.checkedAt, DateTime.fromMillisecondsSinceEpoch(42));
    });

    test('texto ausente ou quebrado vira nulo', () {
      expect(parseHealth(null), isNull);
      expect(parseHealth(''), isNull);
      expect(parseHealth('{quebrado'), isNull);
      expect(parseHealth('[1,2]'), isNull);
    });
  });

  group('HealthReporter (aparelho do filho)', () {
    late FakeHealthSource source;
    late MemoryHealthStore store;
    late HealthReporter reporter;

    setUp(() {
      source = FakeHealthSource(health());
      store = MemoryHealthStore();
      reporter = HealthReporter(backend: child, source: source, store: store);
    });

    Future<List<TamperAlert>> alerts() => parent.watchAlerts(paired.id).first;

    test('primeira leitura registra a situação e não gera aviso', () async {
      expect(await reporter.run(), isEmpty);
      expect(await alerts(), isEmpty);
      final device = (await parent.watchDevices().first).single;
      expect(device.health!.admin, isTrue);
      expect(store.value, isNotNull);
    });

    test('permissão retirada vira aviso uma única vez', () async {
      await reporter.run();
      source.value = health(overlay: false);
      expect(await reporter.run(), [AlertKind.overlayRevoked]);
      expect(await reporter.run(), isEmpty);
      final list = await alerts();
      expect(list.single.kind, AlertKind.overlayRevoked);
      final device = (await parent.watchDevices().first).single;
      expect(device.health!.overlay, isFalse);
    });

    test('administrador desativado e serviço parado geram avisos', () async {
      await reporter.run();
      source.value = health(admin: false, monitorRunning: false);
      expect(await reporter.run(), [
        AlertKind.adminDisabled,
        AlertKind.monitorStopped,
      ]);
    });

    test('perder de novo depois de recuperar avisa outra vez', () async {
      await reporter.run();
      source.value = health(usageAccess: false);
      await reporter.run();
      source.value = health();
      await reporter.run();
      source.value = health(usageAccess: false);
      await reporter.run();
      final kinds = (await alerts()).map((a) => a.kind);
      expect(kinds, [
        AlertKind.usageAccessRevoked,
        AlertKind.usageAccessRevoked,
      ]);
    });

    test('mesmo sem mudança, o contato chega à nuvem', () async {
      await reporter.run();
      final before = (await parent.watchDevices().first).single.lastSeen;
      clock = clock.add(const Duration(minutes: 15));
      await reporter.run();
      final after = (await parent.watchDevices().first).single.lastSeen;
      expect(after!.isAfter(before!), isTrue);
    });

    test('sem leitura disponível só atualiza o contato', () async {
      source.value = null;
      clock = clock.add(const Duration(minutes: 15));
      expect(await reporter.run(), isEmpty);
      final device = (await parent.watchDevices().first).single;
      expect(device.lastSeen, clock);
      expect(device.health, isNull);
    });
  });

  group('runChildWatch', () {
    test('não faz nada enquanto o aparelho não está vinculado', () async {
      final loose = MemoryBackend(cloud);
      await loose.signInChild();
      final source = FakeHealthSource(health());
      final store = MemoryHealthStore();
      await runChildWatch(backend: loose, source: source, store: store);
      expect(store.value, isNull);
    });

    test('vinculado, registra a situação', () async {
      final store = MemoryHealthStore();
      await runChildWatch(
        backend: child,
        source: FakeHealthSource(health()),
        store: store,
      );
      expect(store.value, isNotNull);
    });

    test('sem login não faz nada', () async {
      final store = MemoryHealthStore();
      await runChildWatch(
        backend: MemoryBackend(cloud),
        source: FakeHealthSource(health()),
        store: store,
      );
      expect(store.value, isNull);
    });
  });

  group('ParentWatch (aparelho do responsável)', () {
    late FakeNotifier notifier;
    late MemoryNoticeStore store;
    late ParentWatch watch;

    setUp(() {
      notifier = FakeNotifier();
      store = MemoryNoticeStore();
      watch = ParentWatch(
        backend: parent,
        notifier: notifier,
        store: store,
        clock: () => clock,
      );
    });

    test('nada de novo, nenhuma notificação', () async {
      expect(await watch.run(), isEmpty);
    });

    test('aviso do filho vira notificação uma única vez', () async {
      await child.reportAlert(AlertKind.adminDisabled);
      final shown = await watch.run();
      expect(shown, hasLength(1));
      expect(shown.single.title, contains('Celular do Pedro'));
      expect(shown.single.title, contains(AlertKind.adminDisabled.title));
      expect(await watch.run(), isEmpty);
      expect(notifier.shown, hasLength(1));
    });

    test('avisos já vistos não notificam', () async {
      await child.reportAlert(AlertKind.overlayRevoked);
      await parent.markAlertsSeen(paired.id);
      expect(await watch.run(), isEmpty);
    });

    test(
      'aparelho sem sinal notifica uma vez por período de silêncio',
      () async {
        await child.touch();
        clock = clock.add(const Duration(minutes: 30));
        expect(await watch.run(), isEmpty);

        clock = clock.add(const Duration(minutes: 30));
        final shown = await watch.run();
        expect(shown.single.title, contains('sem comunicação'));
        expect(shown.single.body, contains('desinstalado'));

        clock = clock.add(const Duration(hours: 2));
        expect(await watch.run(), isEmpty, reason: 'já avisou deste silêncio');

        // O aparelho volta e some de novo: novo período, novo aviso.
        await child.touch();
        clock = clock.add(const Duration(hours: 1));
        expect(await watch.run(), hasLength(1));
      },
    );

    test(
      'falha ao mostrar a notificação tenta de novo na rodada seguinte',
      () async {
        await child.reportAlert(AlertKind.monitorStopped);
        final flaky = _FlakyNotifier();
        final w = ParentWatch(
          backend: parent,
          notifier: flaky,
          store: store,
          clock: () => clock,
        );
        expect(await w.run(), isEmpty);
        flaky.fail = false;
        expect(await w.run(), hasLength(1));
      },
    );

    test('sem login não notifica', () async {
      final loose = MemoryBackend(cloud);
      final w = ParentWatch(
        backend: loose,
        notifier: notifier,
        store: store,
        clock: () => clock,
      );
      expect(await w.run(), isEmpty);
    });

    test('o registro do que já foi notificado tem tamanho limitado', () async {
      for (var i = 0; i < 320; i++) {
        await child.reportAlert(AlertKind.overlayRevoked);
      }
      await watch.run();
      expect(store.keys.length, lessThanOrEqualTo(300));
    });
  });

  group('sinceText', () {
    test('minutos, horas e dias', () {
      expect(sinceText(const Duration(minutes: 50)), '50 min');
      expect(sinceText(const Duration(hours: 5)), '5 h');
      expect(sinceText(const Duration(days: 3)), '3 d');
    });
  });

  group('telas do responsável', () {
    Future<void> openParent(WidgetTester tester) async {
      await tester.pumpWidget(
        appFor(MemoryBackend(cloud), role: DeviceRole.parent),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('emailField')),
        'mae@exemplo.com',
      );
      await tester.enterText(
        find.byKey(const Key('passwordField')),
        'segredo1',
      );
      await tester.tap(find.byKey(const Key('submitButton')));
      await tester.pumpAndSettle();
    }

    testWidgets('sem problemas, a lista não mostra alerta', (tester) async {
      await tester.runAsync(() => child.touch());
      await openParent(tester);
      expect(find.text('Celular do Pedro'), findsOneWidget);
      expect(find.byKey(const Key('deviceWarning')), findsNothing);
      await closeApp(tester);
    });

    testWidgets(
      'aviso do filho aparece na lista e no aparelho, e some ao marcar como visto',
      (tester) async {
        await tester.runAsync(() async {
          await child.reportHealth(health(overlay: false));
          await child.reportAlert(AlertKind.overlayRevoked);
        });
        await openParent(tester);
        expect(find.byKey(const Key('deviceWarning')), findsOneWidget);

        await tester.tap(find.text('Celular do Pedro'));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('alertsPanel')), findsOneWidget);
        expect(find.text(AlertKind.overlayRevoked.title), findsOneWidget);
        expect(find.byKey(const Key('offNowText')), findsOneWidget);

        await tester.tap(find.byKey(const Key('alertsSeen')));
        await tester.pumpAndSettle();
        expect(find.text(AlertKind.overlayRevoked.title), findsNothing);
        // A permissão continua desligada agora, então o painel permanece.
        expect(find.byKey(const Key('offNowText')), findsOneWidget);
        await closeApp(tester);
      },
    );

    testWidgets('aparelho sem sinal é destacado', (tester) async {
      await tester.runAsync(() => child.touch());
      // O relógio da tela é o real; deixa o contato antigo o bastante.
      cloud.devices[paired.id]!.info = cloud.devices[paired.id]!.info.copyWith(
        lastSeen: DateTime.now().subtract(const Duration(hours: 3)),
      );
      await openParent(tester);
      expect(find.byKey(const Key('deviceWarning')), findsOneWidget);
      await tester.tap(find.text('Celular do Pedro'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('noSignalText')), findsOneWidget);
      expect(find.textContaining('desinstalado'), findsOneWidget);
      await closeApp(tester);
    });
  });

  group('tela do filho', () {
    testWidgets('oferece a proteção contra desinstalação e a ativa', (
      tester,
    ) async {
      final monitor = DemoUsageMonitor(adminActive: false);
      await tester.pumpWidget(
        appFor(child, role: DeviceRole.child, monitor: monitor),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('adminCard')), findsOneWidget);

      await tester.tap(find.byKey(const Key('adminButton')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('adminCard')), findsNothing);
      expect(find.text('Proteção contra desinstalação ativa.'), findsOneWidget);
      await closeApp(tester);
    });

    testWidgets('onde não há administrador, nada é oferecido', (tester) async {
      await tester.pumpWidget(
        appFor(child, role: DeviceRole.child, monitor: DemoUsageMonitor()),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('adminCard')), findsNothing);
      await closeApp(tester);
    });

    testWidgets('com o app aberto, retirar uma permissão avisa o responsável', (
      tester,
    ) async {
      final source = FakeHealthSource(health());
      await tester.pumpWidget(
        appFor(
          child,
          role: DeviceRole.child,
          monitor: DemoUsageMonitor(),
          healthSource: source,
          healthStore: MemoryHealthStore(),
        ),
      );
      await tester.pumpAndSettle();
      source.value = health(usageAccess: false);
      // O verificador do app aberto roda a cada 2 minutos.
      await tester.pump(const Duration(minutes: 2, seconds: 1));
      await tester.pump();
      final alerts = await tester.runAsync(
        () => parent.watchAlerts(paired.id).first,
      );
      expect(alerts!.map((a) => a.kind), [AlertKind.usageAccessRevoked]);
      await closeApp(tester);
    });
  });

  group('verificação em segundo plano', () {
    testWidgets('liga ao abrir com função, ao escolher e desliga ao trocar', (
      tester,
    ) async {
      final background = RecordingBackground();
      await tester.pumpWidget(
        appFor(
          MemoryBackend(cloud),
          role: DeviceRole.parent,
          background: background,
        ),
      );
      await tester.pumpAndSettle();
      expect(background.calls, ['enable:parent']);
      await closeApp(tester);

      final fresh = RecordingBackground();
      await tester.pumpWidget(appFor(MemoryBackend(cloud), background: fresh));
      await tester.pumpAndSettle();
      expect(fresh.calls, isEmpty);
      await tester.tap(find.byKey(const Key('roleChild')));
      await tester.pumpAndSettle();
      expect(fresh.calls, ['enable:child']);
      await closeApp(tester);
    });
  });
}

class _FlakyNotifier implements Notifier {
  bool fail = true;

  @override
  Future<void> show(WatchNotice notice) async {
    if (fail) throw StateError('sem permissão');
  }
}
