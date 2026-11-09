import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guardiao/update/update_bar.dart';
import 'package:guardiao/update/update_controller.dart';
import 'package:guardiao/update/update_installer.dart';
import 'package:guardiao/update/update_models.dart';
import 'package:guardiao/update/update_source.dart';

AppUpdate update(int build) => AppUpdate(
  build: build,
  apkUrl: 'https://exemplo.com/guardiao.apk',
  sizeBytes: 100,
  sha256: 'abc',
);

void main() {
  group('lendo a Release do GitHub', () {
    test('etiqueta apk-N vira o número da versão', () {
      expect(buildFromTag('apk-12'), 12);
      expect(buildFromTag('v1.0'), isNull);
      expect(buildFromTag(null), isNull);
    });

    test('pega o APK, o tamanho e a soma SHA-256', () {
      final u = parseRelease({
        'tag_name': 'apk-7',
        'body': ' Novidades ',
        'assets': [
          {'name': 'outro.zip', 'browser_download_url': 'https://x/outro.zip'},
          {
            'name': 'guardiao.apk',
            'browser_download_url': 'https://github.com/x/guardiao.apk',
            'size': 70000000,
            'digest': 'sha256:ABCDEF',
          },
        ],
      });
      expect(u!.build, 7);
      expect(u.apkUrl, 'https://github.com/x/guardiao.apk');
      expect(u.sizeBytes, 70000000);
      expect(u.sha256, 'abcdef');
      expect(u.notes, 'Novidades');
    });

    test('recusa Release sem APK, com etiqueta estranha ou link sem https', () {
      expect(parseRelease({'tag_name': 'apk-1', 'assets': []}), isNull);
      expect(parseRelease({'tag_name': 'beta', 'assets': []}), isNull);
      expect(
        parseRelease({
          'tag_name': 'apk-2',
          'assets': [
            {
              'name': 'guardiao.apk',
              'browser_download_url': 'http://inseguro/x.apk',
            },
          ],
        }),
        isNull,
      );
    });
  });

  group('UpdateController', () {
    UpdateController make(FakeUpdateSource s, FakeUpdateInstaller i) =>
        UpdateController(source: s, installer: i);

    test(
      'só avisa quando a versão do GitHub é maior que a instalada',
      () async {
        final installer = FakeUpdateInstaller(build: 3);
        final c = make(FakeUpdateSource(update(3)), installer);
        await c.check();
        expect(c.status, UpdateStatus.idle);
        expect(c.visible, isFalse);

        final c2 = make(FakeUpdateSource(update(4)), installer);
        await c2.check();
        expect(c2.status, UpdateStatus.available);
        expect(c2.visible, isTrue);
        expect(c2.currentName, '0.1.0');
      },
    );

    test('sem informação do GitHub não avisa nada', () async {
      final c = make(FakeUpdateSource(null), FakeUpdateInstaller());
      await c.check();
      expect(c.visible, isFalse);
    });

    test('atualizar baixa e abre o instalador', () async {
      final installer = FakeUpdateInstaller(build: 1);
      final c = make(FakeUpdateSource(update(2)), installer);
      await c.check();
      await c.start();
      expect(installer.downloads, 1);
      expect(installer.installs, 1);
      expect(installer.installed!.path, contains('guardiao-2.apk'));
      expect(c.status, UpdateStatus.readyToInstall);
    });

    test(
      'sem permissão de instalar, abre a configuração e continua depois',
      () async {
        final installer = FakeUpdateInstaller(build: 1, allowed: false);
        final c = make(FakeUpdateSource(update(2)), installer);
        await c.check();
        await c.start();
        expect(c.status, UpdateStatus.needsPermission);
        expect(installer.settingsOpened, 1);
        expect(installer.installs, 0);

        installer.allowed = true;
        await c.continueInstall();
        expect(installer.installs, 1);
        expect(installer.downloads, 1, reason: 'não baixa de novo');
      },
    );

    test('falha no download mostra erro e permite tentar de novo', () async {
      final installer = FakeUpdateInstaller(build: 1, failDownload: true);
      final c = make(FakeUpdateSource(update(2)), installer);
      await c.check();
      await c.start();
      expect(c.status, UpdateStatus.error);
      expect(c.error, contains('Tente novamente'));

      installer.failDownload = false;
      await c.start();
      expect(c.status, UpdateStatus.readyToInstall);
    });

    test(
      '"Depois" esconde a barra até aparecer uma versão ainda mais nova',
      () async {
        final source = FakeUpdateSource(update(2));
        final c = make(source, FakeUpdateInstaller(build: 1));
        await c.check();
        c.dismiss();
        expect(c.visible, isFalse);
        await c.check();
        expect(c.visible, isFalse);
        source.update = update(3);
        await c.check();
        expect(c.visible, isTrue);
      },
    );
  });

  group('UpdateBar', () {
    testWidgets('mostra o aviso, o progresso e o fim', (tester) async {
      final installer = FakeUpdateInstaller(build: 1);
      final c = UpdateController(
        source: FakeUpdateSource(update(5)),
        installer: installer,
      );
      await c.check();
      await tester.pumpWidget(
        MaterialApp(
          home: UpdateHost(
            controller: c,
            child: const Scaffold(body: Text('conteúdo')),
          ),
        ),
      );
      expect(find.byKey(const Key('updateBar')), findsOneWidget);
      expect(find.textContaining('Nova versão'), findsOneWidget);
      expect(find.text('conteúdo'), findsOneWidget);

      await tester.tap(find.byKey(const Key('updateStart')));
      await tester.pump();
      await tester.pump();
      expect(installer.installs, 1);
      expect(find.textContaining('Confirme a instalação'), findsOneWidget);
    });

    testWidgets('sem versão nova a barra some', (tester) async {
      final c = UpdateController(
        source: FakeUpdateSource(null),
        installer: FakeUpdateInstaller(),
      );
      await c.check();
      await tester.pumpWidget(
        MaterialApp(
          home: UpdateHost(controller: c, child: const Text('conteúdo')),
        ),
      );
      expect(find.byKey(const Key('updateBar')), findsNothing);
      expect(find.text('conteúdo'), findsOneWidget);
    });
  });
}
