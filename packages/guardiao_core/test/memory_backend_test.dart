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

  /// O filho gera o código e o responsável o aprova (como se tivesse lido o QR).
  Future<PairedDevice> pair({String name = 'Celular do Pedro'}) async {
    final request = await child.createPairRequest(
      deviceName: name,
      platform: DevicePlatform.android,
    );
    return parent.approvePairRequest(
      formatPairingCode(request.code).toLowerCase(),
    );
  }

  group('conta', () {
    test('não aceita e-mail repetido nem senha curta', () async {
      final other = MemoryBackend(cloud);
      expect(
        () => other.registerParent('mae@exemplo.com', 'outra-senha'),
        throwsA(isA<AuthException>()),
      );
      expect(
        () => other.registerParent('novo@exemplo.com', '123'),
        throwsA(isA<AuthException>()),
      );
    });

    test('login com senha errada falha e com a certa funciona', () async {
      final other = MemoryBackend(cloud);
      expect(
        () => other.signInParent('mae@exemplo.com', 'errada'),
        throwsA(isA<AuthException>()),
      );
      final uid = await other.signInParent('MAE@exemplo.com', 'segredo1');
      expect(uid, parent.currentUid);
    });
  });

  group('pareamento (o filho gera o código)', () {
    test('vincula o aparelho e o responsável o enxerga', () async {
      final device = await pair();
      expect(device.parentUid, parent.currentUid);
      expect(device.id, child.currentUid);
      final devices = await parent.watchDevices().first;
      expect(devices.single.name, 'Celular do Pedro');
      expect(devices.single.platform, DevicePlatform.android);
    });

    test('o filho vê quem é o responsável (e-mail escondido)', () async {
      await pair();
      final own = await child.watchOwnDevice().first;
      expect(own!.parentLabel, 'ma***@exemplo.com');
    });

    test('o responsável pode trocar o nome ao vincular', () async {
      final request = await child.createPairRequest(
        deviceName: 'Galaxy A15',
        platform: DevicePlatform.android,
      );
      final device = await parent.approvePairRequest(
        request.code,
        deviceName: ' Celular do Pedro ',
      );
      expect(device.name, 'Celular do Pedro');
    });

    test('um responsável vincula vários aparelhos de filhos', () async {
      final phone = await pair(name: 'Celular do Pedro');

      final notebook = MemoryBackend(cloud);
      await notebook.signInChild();
      final req = await notebook.createPairRequest(
        deviceName: 'Notebook da Ana',
        platform: DevicePlatform.windows,
      );
      final second = await parent.approvePairRequest(req.code);

      expect(second.id, isNot(phone.id));
      final devices = await parent.watchDevices().first;
      expect(devices.map((d) => d.name), [
        'Celular do Pedro',
        'Notebook da Ana',
      ]);
      expect(devices.map((d) => d.platform), [
        DevicePlatform.android,
        DevicePlatform.windows,
      ]);
      // Cada filho enxerga só o próprio aparelho.
      expect((await notebook.watchOwnDevice().first)!.name, 'Notebook da Ana');
      expect((await child.watchOwnDevice().first)!.name, 'Celular do Pedro');
    });

    test('a prévia mostra o aparelho sem queimar o código', () async {
      final request = await child.createPairRequest(
        deviceName: 'Notebook',
        platform: DevicePlatform.windows,
      );
      final preview = await parent.previewPairRequest(request.code);
      expect(preview.deviceName, 'Notebook');
      expect(preview.platform, DevicePlatform.windows);
      expect(preview.expiresAt, request.expiresAt);
      await parent.approvePairRequest(request.code); // ainda vale
    });

    test('código só vale uma vez', () async {
      final request = await child.createPairRequest(
        deviceName: 'A',
        platform: DevicePlatform.windows,
      );
      await parent.approvePairRequest(request.code);
      final other = MemoryBackend(cloud);
      await other.registerParent('pai@exemplo.com', 'segredo2');
      await expectLater(
        other.approvePairRequest(request.code),
        throwsA(
          isA<PairingException>().having(
            (e) => e.message,
            'mensagem',
            contains('já foi usado'),
          ),
        ),
      );
      await expectLater(
        other.previewPairRequest(request.code),
        throwsA(isA<PairingException>()),
      );
    });

    test('código expira em 10 minutos', () async {
      final request = await child.createPairRequest(
        deviceName: 'A',
        platform: DevicePlatform.android,
      );
      clock = clock.add(pairingCodeTtl);
      await expectLater(
        parent.approvePairRequest(request.code),
        throwsA(
          isA<PairingException>().having(
            (e) => e.message,
            'mensagem',
            contains('expirou'),
          ),
        ),
      );
    });

    test('gerar outro código cancela o anterior', () async {
      final first = await child.createPairRequest(
        deviceName: 'A',
        platform: DevicePlatform.android,
      );
      final second = await child.createPairRequest(
        deviceName: 'A',
        platform: DevicePlatform.android,
      );
      expect(second.code, isNot(first.code));
      await expectLater(
        parent.previewPairRequest(first.code),
        throwsA(isA<PairingException>()),
      );
      await parent.previewPairRequest(second.code);
    });

    test('cancelar apaga o pedido, e só quem o criou cancela', () async {
      final request = await child.createPairRequest(
        deviceName: 'A',
        platform: DevicePlatform.android,
      );
      await parent.cancelPairRequest(request.code); // outro aparelho: ignorado
      await parent.previewPairRequest(request.code);
      await child.cancelPairRequest(request.code);
      await expectLater(
        parent.previewPairRequest(request.code),
        throwsA(isA<PairingException>()),
      );
    });

    test('código inexistente ou malformado dá erro claro', () async {
      await expectLater(
        parent.previewPairRequest('AAAAAAAA'),
        throwsA(isA<PairingException>()),
      );
      await expectLater(
        parent.approvePairRequest('abc'),
        throwsA(
          isA<PairingException>().having(
            (e) => e.message,
            'mensagem',
            contains('8 letras'),
          ),
        ),
      );
    });

    test('aparelho já vinculado não pode ser vinculado de novo', () async {
      await pair();
      final again = await child.createPairRequest(
        deviceName: 'A',
        platform: DevicePlatform.android,
      );
      await expectLater(
        parent.approvePairRequest(again.code),
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
      expect(
        () => stranger.removeDevice(device.id),
        throwsA(isA<PairingException>()),
      );
      expect(
        () => stranger.setRule(
          device.id,
          const AppRule(appId: 'x', blocked: true),
        ),
        throwsA(isA<PairingException>()),
      );
    });
  });

  group('apps e regras', () {
    test(
      'lista de apps do filho chega ao responsável, em ordem alfabética',
      () async {
        final device = await pair();
        await child.syncInstalledApps(const [
          InstalledApp(
            id: 'com.roblox.client',
            name: 'Roblox',
            packageName: 'com.roblox.client',
          ),
          InstalledApp(id: 'com.dts.freefireth', name: 'free fire'),
          InstalledApp(id: 'com.android.chrome', name: 'Chrome'),
        ]);
        final apps = await parent.watchApps(device.id).first;
        expect(apps.map((a) => a.name), ['Chrome', 'free fire', 'Roblox']);
      },
    );

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
        device.id,
        const AppRule(appId: 'roblox', dailyLimitMinutes: 60),
      );
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
      expect(
        () => child.syncInstalledApps(const []),
        throwsA(isA<PairingException>()),
      );
    });
  });

  group('tempo de uso', () {
    test('o filho envia, o responsável lê a partir do dia pedido', () async {
      final device = await pair();
      await child.reportUsage('2026-10-25', {'com.roblox.client': 30});
      await child.reportUsage('2026-10-26', {
        'com.roblox.client': 45,
        'com.whatsapp': 5,
      });
      final all = await parent
          .watchUsage(device.id, sinceDay: '2026-10-25')
          .first;
      expect(all, hasLength(3));
      final today = await parent
          .watchUsage(device.id, sinceDay: '2026-10-26')
          .first;
      expect(today.map((e) => e.minutes), [45, 5]);
      expect(today.first.appId, 'com.roblox.client');
    });

    test(
      'um novo envio no mesmo dia substitui o anterior e limita a 24 h',
      () async {
        final device = await pair();
        await child.reportUsage('2026-10-26', {'a': 10});
        await child.reportUsage('2026-10-26', {'a': 99999});
        final list = await parent
            .watchUsage(device.id, sinceDay: '2026-10-26')
            .first;
        expect(list.single.minutes, 1440);
      },
    );

    test('outro responsável não consegue ver o uso', () async {
      final device = await pair();
      final other = MemoryBackend(cloud);
      await other.registerParent('pai@exemplo.com', 'segredo2');
      expect(
        () => other.watchUsage(device.id, sinceDay: '2026-10-01'),
        throwsA(isA<PairingException>()),
      );
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
