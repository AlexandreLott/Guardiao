import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guardiao/child/usage/android_usage_monitor.dart';
import 'package:guardiao/child/usage/usage_monitor.dart';
import 'package:guardiao/child/usage/windows_probe.dart';
import 'package:guardiao/child/usage/windows_usage_monitor.dart';
import 'package:guardiao/parent/usage_summary.dart';
import 'package:guardiao/role/role.dart';
import 'package:guardiao_core/guardiao_core.dart';

import 'helpers.dart';

class _FakeProbe implements SystemProbe {
  String? exe;
  int idle = 0;
  final killed = <String>[];

  @override
  String? foregroundExe() => exe;

  @override
  int idleSeconds() => idle;

  @override
  Future<void> kill(String name) async => killed.add(name);
}

void main() {
  group('quais apps são vigiados', () {
    const apps = [
      InstalledApp(
        id: 'com.roblox.client',
        name: 'Roblox',
        packageName: 'com.roblox.client',
      ),
      InstalledApp(id: 'win_x', name: 'Jogo', packageName: 'Jogo.EXE'),
      InstalledApp(id: 'win_y', name: 'Sem exe'),
      InstalledApp(id: 'com.chrome', name: 'Chrome', packageName: 'com.chrome'),
    ];
    const rules = {
      'com.roblox.client': AppRule(
        appId: 'com.roblox.client',
        dailyLimitMinutes: 60,
      ),
      'win_x': AppRule(appId: 'win_x', blocked: true),
      'win_y': AppRule(appId: 'win_y', dailyLimitMinutes: 30),
      'com.chrome': AppRule(appId: 'com.chrome'), // regra padrão: nada a vigiar
    };

    test('no Android usa o nome do pacote', () {
      final list = buildMonitored(apps, rules, DevicePlatform.android);
      expect(list.map((a) => a.key), [
        'com.roblox.client',
        'Jogo.EXE',
        'win_y',
      ]);
      expect(list.first.limitMinutes, 60);
    });

    test('no Windows usa o .exe em minúsculas e ignora quem não tem', () {
      final list = buildMonitored(apps, rules, DevicePlatform.windows);
      expect(list.map((a) => a.key), ['com.roblox.client', 'jogo.exe']);
      expect(list.last.blocked, isTrue);
    });
  });

  group('Windows', () {
    late _FakeProbe probe;
    late DateTime now;
    late MemoryLedgerStore store;

    WindowsUsageMonitor make() =>
        WindowsUsageMonitor(probe: probe, store: store, clock: () => now);

    setUp(() {
      probe = _FakeProbe();
      now = DateTime(2026, 10, 26, 15);
      store = MemoryLedgerStore();
    });

    Future<void> run(
      WindowsUsageMonitor m,
      int polls, {
      int stepSeconds = 2,
    }) async {
      for (var i = 0; i < polls; i++) {
        now = now.add(Duration(seconds: stepSeconds));
        await m.poll();
      }
    }

    const game = MonitoredApp(
      appId: 'g',
      key: 'jogo.exe',
      name: 'Jogo',
      limitMinutes: 2,
    );

    test('conta o tempo do programa que está na frente', () async {
      final m = make();
      await m.start([game]);
      probe.exe = 'Jogo.exe';
      await run(m, 45); // 90 s
      probe.exe = 'outro.exe';
      await run(m, 30); // 60 s
      expect(await m.usageByKey(), {'jogo.exe': 1, 'outro.exe': 1});
      await m.stop();
    });

    test('não conta quando o computador está parado', () async {
      final m = make();
      await m.start([game]);
      probe.exe = 'jogo.exe';
      probe.idle = 600;
      await run(m, 60);
      expect(await m.usageByKey(), isEmpty);
      await m.stop();
    });

    test('encerra o programa quando o limite acaba, e não antes', () async {
      final m = make();
      await m.start([game]); // limite: 2 min
      probe.exe = 'jogo.exe';
      await run(m, 59); // 118 s
      expect(probe.killed, isEmpty);
      await run(m, 2);
      expect(probe.killed, contains('jogo.exe'));
      await m.stop();
    });

    test('programa bloqueado é encerrado na primeira olhada', () async {
      final m = make();
      await m.start([
        const MonitoredApp(
          appId: 'b',
          key: 'bloqueado.exe',
          name: 'B',
          blocked: true,
        ),
      ]);
      probe.exe = 'bloqueado.exe';
      await run(m, 1);
      expect(probe.killed, ['bloqueado.exe']);
      await m.stop();
    });

    test('nunca encerra o próprio Guardião', () async {
      final m = make();
      await m.start([
        const MonitoredApp(
          appId: 'g',
          key: 'guardiao.exe',
          name: 'G',
          blocked: true,
        ),
      ]);
      probe.exe = 'guardiao.exe';
      await run(m, 5);
      expect(probe.killed, isEmpty);
      await m.stop();
    });

    test('um dia novo zera a contagem', () async {
      final m = make();
      await m.start([game]);
      probe.exe = 'jogo.exe';
      await run(m, 40);
      expect((await m.usageByKey())['jogo.exe'], 1);
      now = DateTime(2026, 10, 27, 0, 0, 5);
      probe.exe = null;
      await m.poll();
      expect(await m.usageByKey(), isEmpty);
      await m.stop();
    });

    test('pausa longa (computador suspenso) não vira tempo de uso', () async {
      final m = make();
      await m.start([game]);
      probe.exe = 'jogo.exe';
      await run(m, 1);
      now = now.add(const Duration(hours: 3));
      await m.poll();
      expect(await m.usageByKey(), isEmpty); // só alguns segundos
      await m.stop();
    });

    test('o tempo sobrevive a reabrir o app no mesmo dia', () async {
      final a = make();
      await a.start([game]);
      probe.exe = 'jogo.exe';
      await run(a, 40);
      await a.stop();

      final b = make();
      expect((await b.usageByKey())['jogo.exe'], 1);
      await b.stop();
    });
  });

  group('Android (canal de plataforma)', () {
    const channel = MethodChannel('br.edu.guardiaogamer/monitor');
    final calls = <MethodCall>[];

    setUp(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      calls.clear();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            switch (call.method) {
              case 'permissions':
                return {
                  'usageAccess': false,
                  'overlay': true,
                  'notifications': false,
                };
              case 'usageToday':
                return {'com.roblox.client': 42};
            }
            return null;
          });
    });

    tearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );

    test('lista o que falta liberar', () async {
      final missing = await AndroidUsageMonitor().missingPermissions();
      expect(missing, {
        MonitorPermission.usageAccess,
        MonitorPermission.notifications,
      });
    });

    test('manda as regras em JSON e lê o uso', () async {
      final m = AndroidUsageMonitor();
      await m.start(const [
        MonitoredApp(
          appId: 'com.roblox.client',
          key: 'com.roblox.client',
          name: 'Roblox',
          limitMinutes: 60,
        ),
      ]);
      final sent = jsonDecode(calls.single.arguments['apps'] as String) as List;
      expect(sent.single, {
        'pkg': 'com.roblox.client',
        'name': 'Roblox',
        'limit': 60,
        'blocked': false,
      });
      expect(await m.usageByKey(), {'com.roblox.client': 42});
    });

    test('cada permissão abre a tela certa', () async {
      final m = AndroidUsageMonitor();
      await m.request(MonitorPermission.usageAccess);
      await m.request(MonitorPermission.overlay);
      await m.request(MonitorPermission.notifications);
      expect(calls.map((c) => c.method), [
        'openUsageAccessSettings',
        'openOverlaySettings',
        'requestNotifications',
      ]);
    });
  });

  group('resumo do responsável', () {
    test('soma por dia, inclui dias sem uso e termina em hoje', () {
      final totals = summarizeDays(
        [
          const UsageEntry(day: '2026-10-26', appId: 'a', minutes: 30),
          const UsageEntry(day: '2026-10-26', appId: 'b', minutes: 15),
          const UsageEntry(day: '2026-10-24', appId: 'a', minutes: 60),
        ],
        DateTime(2026, 10, 26, 18),
        days: 4,
      );
      expect(totals, [
        const DayTotal('2026-10-23', 0),
        const DayTotal('2026-10-24', 60),
        const DayTotal('2026-10-25', 0),
        const DayTotal('2026-10-26', 45),
      ]);
    });

    test('usageOfDay separa o dia pedido', () {
      final used = usageOfDay([
        const UsageEntry(day: '2026-10-26', appId: 'a', minutes: 5),
        const UsageEntry(day: '2026-10-25', appId: 'a', minutes: 99),
      ], '2026-10-26');
      expect(used, {'a': 5});
    });
  });

  group('tela do filho', () {
    late MemoryCloud cloud;
    late MemoryBackend parent;
    late MemoryBackend childBackend;
    late DemoUsageMonitor monitor;

    setUp(() async {
      cloud = MemoryCloud();
      parent = MemoryBackend(cloud);
      await parent.registerParent('mae@exemplo.com', 'segredo1');
      childBackend = MemoryBackend(cloud);
      monitor = DemoUsageMonitor();
    });

    Future<PairedDevice> pairChild(WidgetTester tester) async {
      await tester.pumpWidget(
        appFor(childBackend, role: DeviceRole.child, monitor: monitor),
      );
      await tester.pumpAndSettle();
      await parent.approvePairRequest(shownPairingCode(tester));
      await tester.pumpAndSettle();
      return (await tester.runAsync(() => parent.watchDevices().first))!.single;
    }

    Future<void> tickMinute(WidgetTester tester) async {
      await tester.pump(const Duration(seconds: 31));
      await tester.pump();
    }

    testWidgets(
      'mostra o tempo usado e o restante, e o responsável vê o mesmo',
      (tester) async {
        final device = await pairChild(tester);
        await parent.setRule(
          device.id,
          const AppRule(appId: 'demo.roblox', dailyLimitMinutes: 90),
        );
        await tester.pump();
        await tester.pump();

        expect(monitor.started.single.key, 'demo.roblox');
        expect(monitor.started.single.limitMinutes, 90);
        expect(find.text('Usou 0 min de 1 h 30 min hoje'), findsOneWidget);

        monitor.simulate('demo.roblox', 30);
        monitor.simulate('demo.chrome', 12);
        await tickMinute(tester);

        expect(find.text('Usou 30 min de 1 h 30 min hoje'), findsOneWidget);
        expect(find.text('1 h restantes'), findsOneWidget);
        expect(find.text('Hoje: 12 min'), findsOneWidget); // app sem limite

        final reported = (await tester.runAsync(
          () => parent
              .watchUsage(device.id, sinceDay: dayKey(DateTime.now()))
              .first,
        ))!;
        expect(
          {for (final e in reported) e.appId: e.minutes},
          {'demo.roblox': 30, 'demo.chrome': 12},
        );
        await closeApp(tester);
      },
    );

    testWidgets('limite esgotado vira "Bloqueado" na tela do filho', (
      tester,
    ) async {
      final device = await pairChild(tester);
      await parent.setRule(
        device.id,
        const AppRule(appId: 'demo.roblox', dailyLimitMinutes: 30),
      );
      await tester.pump();
      monitor.simulate('demo.roblox', 30);
      await tickMinute(tester);
      expect(find.text('Bloqueado'), findsOneWidget);
      await closeApp(tester);
    });

    testWidgets('pede as permissões que faltam e some quando liberadas', (
      tester,
    ) async {
      monitor = DemoUsageMonitor(
        missing: {MonitorPermission.usageAccess, MonitorPermission.overlay},
      );
      await pairChild(tester);
      await tester.pump();
      expect(find.byKey(const Key('permissionsCard')), findsOneWidget);
      expect(find.byKey(const Key('permission_usageAccess')), findsOneWidget);
      expect(find.byKey(const Key('permission_overlay')), findsOneWidget);

      await tester.tap(find.byKey(const Key('permission_usageAccess')));
      await tester.pump();
      await tester.pump();
      expect(find.byKey(const Key('permission_usageAccess')), findsNothing);
      expect(find.byKey(const Key('permission_overlay')), findsOneWidget);

      await tester.tap(find.byKey(const Key('permission_overlay')));
      await tester.pump();
      await tester.pump();
      expect(find.byKey(const Key('permissionsCard')), findsNothing);
      await closeApp(tester);
    });

    testWidgets('sem medidor no aparelho, avisa que o tempo não diminui', (
      tester,
    ) async {
      await tester.pumpWidget(appFor(childBackend, role: DeviceRole.child));
      await tester.pumpAndSettle();
      await parent.approvePairRequest(shownPairingCode(tester));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('ainda não mede o tempo de uso'),
        findsOneWidget,
      );
      await closeApp(tester);
    });
  });
}
