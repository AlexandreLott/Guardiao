import 'package:flutter_test/flutter_test.dart';
import 'package:guardiao_core/guardiao_core.dart';

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
  group('DeviceHealth.newlyLost', () {
    test('sem leitura anterior não há o que comparar', () {
      expect(DeviceHealth.newlyLost(null, health(usageAccess: false)), isEmpty);
    });

    test('tudo igual não gera aviso', () {
      expect(DeviceHealth.newlyLost(health(), health()), isEmpty);
    });

    test('cada proteção retirada gera o aviso correspondente', () {
      expect(
        DeviceHealth.newlyLost(
          health(),
          health(
            usageAccess: false,
            overlay: false,
            notifications: false,
            admin: false,
            monitorRunning: false,
          ),
        ),
        AlertKind.values,
      );
    });

    test('o que já estava desligado antes não avisa de novo', () {
      expect(
        DeviceHealth.newlyLost(
          health(admin: false),
          health(admin: false, overlay: false),
        ),
        [AlertKind.overlayRevoked],
      );
    });

    test('proteção que volta não gera aviso', () {
      expect(DeviceHealth.newlyLost(health(overlay: false), health()), isEmpty);
    });
  });

  group('DeviceHealth em JSON', () {
    test('vai e volta sem perder nada', () {
      final h = health(
        admin: false,
        at: DateTime.fromMillisecondsSinceEpoch(5),
      );
      expect(DeviceHealth.fromJson(h.toJson()), h);
    });

    test('campos ausentes valem como desligado, exceto o serviço', () {
      final h = DeviceHealth.fromJson({'checkedAt': 1});
      expect(h.usageAccess, isFalse);
      expect(h.admin, isFalse);
      expect(h.monitorRunning, isTrue);
    });

    test('sameState ignora o horário', () {
      expect(
        health(at: DateTime(2026)).sameState(health(at: DateTime(2027))),
        isTrue,
      );
      expect(health().sameState(health(admin: false)), isFalse);
      expect(health().sameState(null), isFalse);
    });
  });

  group('AlertKind', () {
    test('o nome no Firestore faz a viagem de ida e volta', () {
      for (final kind in AlertKind.values) {
        expect(AlertKind.parse(kind.wire), kind);
        expect(kind.title, isNotEmpty);
        expect(kind.description, isNotEmpty);
      }
      expect(AlertKind.parse('desconhecido'), isNull);
      expect(AlertKind.parse(null), isNull);
    });
  });

  group('sem sinal', () {
    final base = DateTime(2026, 11, 9, 12);
    PairedDevice device(DateTime? lastSeen) => PairedDevice(
      id: 'd',
      parentUid: 'p',
      name: 'Celular',
      platform: DevicePlatform.android,
      pairedAt: base,
      lastSeen: lastSeen,
    );

    test('só passa de 45 minutos sem contato', () {
      expect(
        device(base).hasNoSignal(base.add(const Duration(minutes: 45))),
        isFalse,
      );
      expect(
        device(base).hasNoSignal(base.add(const Duration(minutes: 46))),
        isTrue,
      );
    });

    test('sem nenhum contato registrado não dispara', () {
      expect(device(null).hasNoSignal(base), isFalse);
    });
  });

  group('avisos no backend em memória', () {
    late MemoryCloud cloud;
    late MemoryBackend parent;
    late MemoryBackend child;
    late PairedDevice paired;
    var clock = DateTime(2026, 11, 9, 9);

    setUp(() async {
      clock = DateTime(2026, 11, 9, 9);
      cloud = MemoryCloud(now: () => clock);
      parent = MemoryBackend(cloud);
      child = MemoryBackend(cloud);
      await parent.registerParent('mae@exemplo.com', 'segredo1');
      await child.signInChild();
      final request = await child.createPairRequest(
        deviceName: 'Celular',
        platform: DevicePlatform.android,
      );
      paired = await parent.approvePairRequest(request.code);
    });

    test(
      'o filho avisa e o responsável vê, do mais novo para o mais antigo',
      () async {
        await child.reportAlert(AlertKind.overlayRevoked);
        clock = clock.add(const Duration(minutes: 5));
        await child.reportAlert(AlertKind.adminDisabled);

        final alerts = await parent.watchAlerts(paired.id).first;
        expect(alerts.map((a) => a.kind), [
          AlertKind.adminDisabled,
          AlertKind.overlayRevoked,
        ]);
        expect(alerts.every((a) => !a.seen), isTrue);
      },
    );

    test('marcar como visto atinge todos os avisos', () async {
      await child.reportAlert(AlertKind.overlayRevoked);
      await child.reportAlert(AlertKind.usageAccessRevoked);
      await parent.markAlertsSeen(paired.id);
      final alerts = await parent.watchAlerts(paired.id).first;
      expect(alerts.every((a) => a.seen), isTrue);
    });

    test('outro responsável não acompanha os avisos', () async {
      final other = MemoryBackend(cloud);
      await other.registerParent('pai@exemplo.com', 'segredo2');
      expect(
        () => other.watchAlerts(paired.id),
        throwsA(isA<PairingException>()),
      );
    });

    test('a situação das proteções e o contato aparecem no aparelho', () async {
      clock = clock.add(const Duration(minutes: 20));
      await child.reportHealth(health(admin: false, at: clock));
      final device = (await parent.watchDevices().first).single;
      expect(device.lastSeen, clock);
      expect(device.health!.admin, isFalse);
      expect(device.health!.usageAccess, isTrue);
    });
  });
}
