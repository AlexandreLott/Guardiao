import 'package:flutter_test/flutter_test.dart';
import 'package:guardiao_core/guardiao_core.dart';

void main() {
  late DateTime clock;
  late MemoryCloud cloud;
  late MemoryBackend parent;
  late MemoryBackend child;

  setUp(() async {
    clock = DateTime(2026, 10, 26, 9);
    cloud = MemoryCloud(now: () => clock);
    parent = MemoryBackend(cloud);
    child = MemoryBackend(cloud);
    await parent.registerParent('mae@exemplo.com', 'segredo1');
    await child.signInChild();
  });

  Future<PairedDevice> pair({String name = 'Celular do Pedro'}) async {
    final code = await parent.createPairingCode();
    return child.claimPairing(
      code: formatPairingCode(code.code).toLowerCase(),
      deviceName: name,
      platform: DevicePlatform.android,
    );
  }

  group('conta', () {
    test('não aceita e-mail repetido nem senha curta', () async {
      final other = MemoryBackend(cloud);
      expect(() => other.registerParent('mae@exemplo.com', 'outra-senha'),
          throwsA(isA<AuthException>()));
      expect(() => other.registerParent('novo@exemplo.com', '123'),
          throwsA(isA<AuthException>()));
    });

    test('login com senha errada falha e com a certa funciona', () async {
      final other = MemoryBackend(cloud);
      expect(() => other.signInParent('mae@exemplo.com', 'errada'),
          throwsA(isA<AuthException>()));
      final uid = await other.signInParent('MAE@exemplo.com', 'segredo1');
      expect(uid, parent.currentUid);
    });
  });

  group('pareamento', () {
    test('vincula o aparelho e o responsável o enxerga', () async {
      final device = await pair();
      expect(device.parentUid, parent.currentUid);
      final devices = await parent.watchDevices().first;
      expect(devices.single.name, 'Celular do Pedro');
      expect(devices.single.platform, DevicePlatform.android);
    });

    test('código só vale uma vez', () async {
      final code = await parent.createPairingCode();
      await child.claimPairing(
          code: code.code, deviceName: 'A', platform: DevicePlatform.windows);
      final second = MemoryBackend(cloud);
      await second.signInChild();
      expect(
        () => second.claimPairing(
            code: code.code, deviceName: 'B', platform: DevicePlatform.windows),
        throwsA(isA<PairingException>()),
      );
    });

    test('código expira em 10 minutos', () async {
      final code = await parent.createPairingCode();
      clock = clock.add(pairingCodeTtl);
      expect(
        () => child.claimPairing(
            code: code.code, deviceName: 'A', platform: DevicePlatform.android),
        throwsA(isA<PairingException>().having((e) => e.message, 'mensagem', contains('expirou'))),
      );
    });

    test('código inexistente dá erro claro', () async {
      expect(
        () => child.claimPairing(
            code: 'AAAAAAAA', deviceName: 'A', platform: DevicePlatform.android),
        throwsA(isA<PairingException>()),
      );
    });

    test('remover o aparelho o desvincula', () async {
      final device = await pair();
      final seen = <PairedDevice?>[];
      final sub = child.watchOwnDevice().listen(seen.add);
      await Future<void>.delayed(Duration.zero);
      expect(seen.last, isNotNull);
      await parent.removeDevice(device.id);
      await Future<void>.delayed(Duration.zero);
      expect(seen.last, isNull);
      await sub.cancel();
    });

    test('um responsável não mexe no aparelho de outro', () async {
      final device = await pair();
      final stranger = MemoryBackend(cloud);
      await stranger.registerParent('outro@exemplo.com', 'segredo2');
      expect(() => stranger.removeDevice(device.id), throwsA(isA<PairingException>()));
      expect(() => stranger.setRule(device.id, const AppRule(appId: 'x', blocked: true)),
          throwsA(isA<PairingException>()));
    });
  });

  group('apps e regras', () {
    test('lista de apps do filho chega ao responsável, em ordem alfabética', () async {
      final device = await pair();
      await child.syncInstalledApps(const [
        InstalledApp(id: 'com.roblox.client', name: 'Roblox', packageName: 'com.roblox.client'),
        InstalledApp(id: 'com.dts.freefireth', name: 'free fire'),
        InstalledApp(id: 'com.android.chrome', name: 'Chrome'),
      ]);
      final apps = await parent.watchApps(device.id).first;
      expect(apps.map((a) => a.name), ['Chrome', 'free fire', 'Roblox']);
    });

    test('nova sincronização remove apps desinstalados', () async {
      final device = await pair();
      await child.syncInstalledApps(const [
        InstalledApp(id: 'a', name: 'A'),
        InstalledApp(id: 'b', name: 'B'),
      ]);
      await child.syncInstalledApps(const [InstalledApp(id: 'b', name: 'B')]);
      expect((await parent.watchApps(device.id).first).map((a) => a.id), ['b']);
    });

    test('regra definida pelo responsável chega ao filho', () async {
      final device = await pair();
      await parent.setRule(
          device.id, const AppRule(appId: 'roblox', dailyLimitMinutes: 60));
      final rules = await child.watchOwnRules().first;
      expect(rules['roblox']!.dailyLimitMinutes, 60);
      expect(rules['roblox']!.remainingMinutes(20), 40);
    });

    test('voltar ao padrão apaga a regra', () async {
      final device = await pair();
      await parent.setRule(device.id, const AppRule(appId: 'x', blocked: true));
      await parent.setRule(device.id, const AppRule(appId: 'x'));
      expect(await child.watchOwnRules().first, isEmpty);
    });

    test('sincronizar sem estar vinculado falha', () async {
      expect(() => child.syncInstalledApps(const []), throwsA(isA<PairingException>()));
    });
  });

  group('prévia do código', () {
    test('mostra o e-mail do responsável escondido, sem queimar o código', () async {
      final code = await parent.createPairingCode();
      final preview = await child.previewPairing(code.code);
      expect(preview.parentLabel, 'ma***@exemplo.com');
      expect(preview.expiresAt, code.expiresAt);
      // Ainda dá para vincular depois de olhar a prévia.
      final device = await child.claimPairing(
          code: code.code, deviceName: 'Celular', platform: DevicePlatform.android);
      expect(device.parentUid, parent.currentUid);
    });

    test('recusa código desconhecido, usado ou expirado', () async {
      await expectLater(child.previewPairing('AAAAAAAA'), throwsA(isA<PairingException>()));
      final code = await parent.createPairingCode();
      clock = clock.add(const Duration(minutes: 11));
      await expectLater(child.previewPairing(code.code), throwsA(isA<PairingException>()));
      clock = DateTime(2026, 10, 26, 9);
      final fresh = await parent.createPairingCode();
      await child.claimPairing(
          code: fresh.code, deviceName: 'Celular', platform: DevicePlatform.android);
      final other = MemoryBackend(cloud);
      await other.signInChild();
      await expectLater(other.previewPairing(fresh.code), throwsA(isA<PairingException>()));
    });
  });

  group('tempo de uso', () {
    test('o filho envia, o responsável lê a partir do dia pedido', () async {
      final device = await pair();
      await child.reportUsage('2026-10-25', {'com.roblox.client': 30});
      await child.reportUsage('2026-10-26', {'com.roblox.client': 45, 'com.whatsapp': 5});
      final all = await parent.watchUsage(device.id, sinceDay: '2026-10-25').first;
      expect(all, hasLength(3));
      final today = await parent.watchUsage(device.id, sinceDay: '2026-10-26').first;
      expect(today.map((e) => e.minutes), [45, 5]);
      expect(today.first.appId, 'com.roblox.client');
    });

    test('um novo envio no mesmo dia substitui o anterior e limita a 24 h', () async {
      final device = await pair();
      await child.reportUsage('2026-10-26', {'a': 10});
      await child.reportUsage('2026-10-26', {'a': 99999});
      final list = await parent.watchUsage(device.id, sinceDay: '2026-10-26').first;
      expect(list.single.minutes, 1440);
    });

    test('outro responsável não consegue ver o uso', () async {
      final device = await pair();
      final other = MemoryBackend(cloud);
      await other.registerParent('pai@exemplo.com', 'segredo2');
      expect(() => other.watchUsage(device.id, sinceDay: '2026-10-01'),
          throwsA(isA<PairingException>()));
    });
  });

  test('touch atualiza o último contato e o status online', () async {
    final device = await pair();
    clock = clock.add(const Duration(hours: 2));
    var current = (await parent.watchDevices().first).single;
    expect(current.isOnline(clock), isFalse);
    await child.touch();
    current = (await parent.watchDevices().first).single;
    expect(current.isOnline(clock), isTrue);
    expect(current.id, device.id);
  });
}
