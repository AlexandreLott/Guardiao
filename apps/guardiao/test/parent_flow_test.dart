import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guardiao_core/guardiao_core.dart';
import 'package:guardiao/role/role.dart';

import 'helpers.dart';

void main() {
  Future<void> login(WidgetTester tester, String email, String password) async {
    await tester.enterText(find.byKey(const Key('emailField')), email);
    await tester.enterText(find.byKey(const Key('passwordField')), password);
    await tester.tap(find.byKey(const Key('submitButton')));
    await tester.pumpAndSettle();
  }

  group('conta', () {
    testWidgets('mostra o login, recusa senha curta e e-mail inválido', (
      tester,
    ) async {
      final backend = MemoryBackend(MemoryCloud());
      await tester.pumpWidget(appFor(backend, role: DeviceRole.parent));
      await tester.pumpAndSettle();
      expect(find.text('Entrar'), findsOneWidget);

      await login(tester, 'sem-arroba', '123456');
      expect(find.text('Digite um e-mail válido.'), findsOneWidget);
      await login(tester, 'mae@exemplo.com', '123');
      expect(find.textContaining('pelo menos 6'), findsOneWidget);
      await closeApp(tester);
    });

    testWidgets('cria a conta e cai na lista vazia de aparelhos', (
      tester,
    ) async {
      final backend = MemoryBackend(MemoryCloud());
      await tester.pumpWidget(appFor(backend, role: DeviceRole.parent));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('toggleButton')));
      await tester.pump();
      expect(find.text('Criar conta'), findsOneWidget);
      await login(tester, 'mae@exemplo.com', 'segredo1');
      expect(find.text('Meus aparelhos'), findsOneWidget);
      expect(find.text('Nenhum aparelho ainda'), findsOneWidget);
      await closeApp(tester);
    });

    testWidgets('senha errada mostra o erro e a certa entra', (tester) async {
      final cloud = MemoryCloud();
      await MemoryBackend(cloud).registerParent('mae@exemplo.com', 'segredo1');
      final backend = MemoryBackend(cloud);
      await tester.pumpWidget(appFor(backend, role: DeviceRole.parent));
      await tester.pumpAndSettle();
      await login(tester, 'mae@exemplo.com', 'errada!');
      expect(find.text('E-mail ou senha incorretos.'), findsOneWidget);
      await login(tester, 'mae@exemplo.com', 'segredo1');
      expect(find.text('Meus aparelhos'), findsOneWidget);
      await closeApp(tester);
    });

    testWidgets('sair volta para o login', (tester) async {
      final cloud = MemoryCloud();
      final backend = MemoryBackend(cloud);
      await backend.registerParent('mae@exemplo.com', 'segredo1');
      await tester.pumpWidget(appFor(backend, role: DeviceRole.parent));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('accountMenu')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('signOutItem')));
      await tester.pumpAndSettle();
      expect(find.text('Entrar'), findsOneWidget);
      await closeApp(tester);
    });
  });

  group('modo demonstração (dados de exemplo)', () {
    Future<void> openDemo(WidgetTester tester) async {
      final setup = (await tester.runAsync(() => createBackend()))!;
      expect(setup.isDemo, isTrue);
      // Sai da conta usada para montar os dados e entra pelo login, como na vida real.
      await setup.backend.signOut();
      await tester.pumpWidget(
        appFor(setup.backend, role: DeviceRole.parent, isDemo: true),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('submitButton')),
      ); // credenciais já preenchidas
      await tester.pumpAndSettle();
    }

    testWidgets('lista o aparelho, os apps e as regras já existentes', (
      tester,
    ) async {
      await openDemo(tester);
      expect(find.text('Celular do Pedro (exemplo)'), findsOneWidget);
      await tester.tap(find.text('Celular do Pedro (exemplo)'));
      await tester.pumpAndSettle();

      expect(find.text('7 aplicativos instalados'), findsOneWidget);
      // Roblox tem limite e já usou 45 min hoje (dado de exemplo).
      expect(find.text('Limite de 1 h por dia · Hoje: 45 min'), findsOneWidget);
      expect(find.text('Bloqueado o dia todo'), findsOneWidget); // Free Fire
      // O painel soma o dia: 45 + 20 + 12 min.
      expect(find.text('Hoje: 1 h 17 min de jogo e apps'), findsOneWidget);
      expect(find.byKey(const Key('usageSummary')), findsOneWidget);
      // Apps com regra aparecem antes dos outros.
      final roblox = tester.getTopLeft(find.text('Roblox')).dy;
      final minecraft = tester.getTopLeft(find.text('Minecraft')).dy;
      expect(roblox, lessThan(minecraft));
      await closeApp(tester);
    });

    testWidgets('busca filtra os aplicativos', (tester) async {
      await openDemo(tester);
      await tester.tap(find.text('Celular do Pedro (exemplo)'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('searchField')), 'mine');
      await tester.pumpAndSettle();
      expect(find.text('Minecraft'), findsOneWidget);
      expect(find.text('Roblox'), findsNothing);
      await tester.enterText(find.byKey(const Key('searchField')), 'zzz');
      await tester.pumpAndSettle();
      expect(find.text('Nenhum aplicativo encontrado.'), findsOneWidget);
      await closeApp(tester);
    });

    testWidgets('define um limite diário e o aplicativo mostra a regra', (
      tester,
    ) async {
      await openDemo(tester);
      await tester.tap(find.text('Celular do Pedro (exemplo)'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Minecraft'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('limitSwitch')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('limitLabel')), findsOneWidget);
      expect(find.text('1 h'), findsWidgets); // valor inicial da barra
      await tester.tap(find.byKey(const Key('saveRuleButton')));
      await tester.pumpAndSettle();

      // Minecraft agora tem a regra (e passou a aparecer entre os com regra).
      expect(find.textContaining('Limite de 1 h por dia'), findsNWidgets(2));
      await closeApp(tester);
    });

    testWidgets('bloqueia um app e depois remove a regra', (tester) async {
      await openDemo(tester);
      await tester.tap(find.text('Celular do Pedro (exemplo)'));
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('Chrome'),
        200,
        scrollable: find.descendant(
          of: find.byType(ListView),
          matching: find.byType(Scrollable),
        ),
      );
      await tester.tap(find.text('Chrome'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('blockSwitch')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('saveRuleButton')));
      await tester.pumpAndSettle();
      // O Chrome bloqueado sobe para o grupo "com regra", no topo da lista.
      await tester.drag(find.byType(ListView), const Offset(0, 1500));
      await tester.pumpAndSettle();
      expect(find.text('Bloqueado o dia todo'), findsNWidgets(2));

      // Reabre e desliga o bloqueio: "Remover regra".
      await tester.scrollUntilVisible(
        find.text('Chrome'),
        200,
        scrollable: find.descendant(
          of: find.byType(ListView),
          matching: find.byType(Scrollable),
        ),
      );
      await tester.tap(find.text('Chrome'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('blockSwitch')));
      await tester.pumpAndSettle();
      expect(find.text('Remover regra'), findsOneWidget);
      await tester.tap(find.byKey(const Key('saveRuleButton')));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(ListView), const Offset(0, 1500));
      await tester.pumpAndSettle();
      expect(find.text('Bloqueado o dia todo'), findsOneWidget);
      await closeApp(tester);
    });

    testWidgets('remover o aparelho pede confirmação e volta para a lista', (
      tester,
    ) async {
      await openDemo(tester);
      await tester.tap(find.text('Celular do Pedro (exemplo)'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remover aparelho'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(find.text('7 aplicativos instalados'), findsOneWidget);

      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remover aparelho'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remover'));
      await tester.pumpAndSettle();
      expect(find.text('Nenhum aparelho ainda'), findsOneWidget);
      await closeApp(tester);
    });
  });

  group('vincular aparelhos de filhos', () {
    late MemoryCloud cloud;
    late MemoryBackend parent;

    setUp(() async {
      cloud = MemoryCloud();
      parent = MemoryBackend(cloud);
      await parent.registerParent('mae@exemplo.com', 'segredo1');
    });

    Future<PairRequest> childRequest(
      String name,
      DevicePlatform platform,
    ) async {
      final child = MemoryBackend(cloud);
      await child.signInChild();
      return child.createPairRequest(deviceName: name, platform: platform);
    }

    Future<void> openAdd(WidgetTester tester, {FakeScanner? scanner}) async {
      await tester.pumpWidget(
        appFor(parent, role: DeviceRole.parent, scanner: scanner),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('addDeviceButton')));
      await tester.pumpAndSettle();
    }

    Future<void> typeCode(WidgetTester tester, String code) async {
      await tester.enterText(find.byKey(const Key('codeField')), code);
      await tester.ensureVisible(find.byKey(const Key('codeContinueButton')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('codeContinueButton')));
      await tester.pumpAndSettle();
    }

    testWidgets('escaneia o QR, confere o aparelho e vincula', (tester) async {
      final request = await childRequest(
        'Celular do Pedro',
        DevicePlatform.android,
      );
      final scanner = FakeScanner();
      await openAdd(tester, scanner: scanner);

      await tester.tap(find.byKey(const Key('scanButton')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('fakeCamera')), findsOneWidget);
      scanner.scan(pairingQrPayload(request.code));
      await tester.pumpAndSettle();

      expect(find.text('Vincular este aparelho?'), findsOneWidget);
      expect(
        find.text('Android · confira se é o aparelho do seu filho'),
        findsOneWidget,
      );
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('nameField')))
            .controller!
            .text,
        'Celular do Pedro',
      );
      await tester.tap(find.byKey(const Key('approveButton')));
      await tester.pumpAndSettle();

      expect(find.text('Celular do Pedro foi vinculado!'), findsOneWidget);
      await tester.tap(find.byKey(const Key('doneButton')));
      await tester.pumpAndSettle();
      expect(find.text('Celular do Pedro'), findsOneWidget);
      expect(find.text('Android · Online agora'), findsOneWidget);
      await closeApp(tester);
    });

    testWidgets('sem câmera (computador), vincula digitando o código', (
      tester,
    ) async {
      final request = await childRequest(
        'Notebook do Pedro',
        DevicePlatform.windows,
      );
      await openAdd(tester); // leitor sem suporte
      expect(find.byKey(const Key('scanButton')), findsNothing);

      await typeCode(tester, request.code.toLowerCase());
      expect(
        find.text('Windows · confira se é o aparelho do seu filho'),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('approveButton')));
      await tester.pumpAndSettle();
      expect(find.text('Notebook do Pedro foi vinculado!'), findsOneWidget);
      await tester.tap(find.byKey(const Key('doneButton')));
      await tester.pumpAndSettle();
      expect(find.text('Windows · Online agora'), findsOneWidget);
      await closeApp(tester);
    });

    testWidgets('dá para trocar o nome antes de vincular', (tester) async {
      final request = await childRequest('Galaxy A15', DevicePlatform.android);
      await openAdd(tester);
      await typeCode(tester, request.code);
      await tester.enterText(
        find.byKey(const Key('nameField')),
        'Celular da Ana',
      );
      await tester.tap(find.byKey(const Key('approveButton')));
      await tester.pumpAndSettle();
      expect(find.text('Celular da Ana foi vinculado!'), findsOneWidget);
      expect(
        (await tester.runAsync(() => parent.watchDevices().first))!.single.name,
        'Celular da Ana',
      );
      await closeApp(tester);
    });

    testWidgets('vincula vários aparelhos, um depois do outro', (tester) async {
      final phone = await childRequest(
        'Celular do Pedro',
        DevicePlatform.android,
      );
      final notebook = await childRequest(
        'Notebook da Ana',
        DevicePlatform.windows,
      );
      await openAdd(tester);

      await typeCode(tester, phone.code);
      await tester.tap(find.byKey(const Key('approveButton')));
      await tester.pumpAndSettle();
      expect(find.text('Celular do Pedro foi vinculado!'), findsOneWidget);

      await tester.tap(find.byKey(const Key('addAnotherButton')));
      await tester.pumpAndSettle();
      expect(find.text('Vincular o aparelho do seu filho'), findsOneWidget);
      await typeCode(tester, notebook.code);
      await tester.tap(find.byKey(const Key('approveButton')));
      await tester.pumpAndSettle();
      expect(find.text('Notebook da Ana foi vinculado!'), findsOneWidget);

      await tester.tap(find.byKey(const Key('doneButton')));
      await tester.pumpAndSettle();
      expect(find.text('Celular do Pedro'), findsOneWidget);
      expect(find.text('Notebook da Ana'), findsOneWidget);
      expect(
        (await tester.runAsync(() => parent.watchDevices().first))!,
        hasLength(2),
      );
      await closeApp(tester);
    });

    testWidgets('"Não é esse" volta sem vincular', (tester) async {
      final request = await childRequest(
        'Celular do Pedro',
        DevicePlatform.android,
      );
      await openAdd(tester);
      await typeCode(tester, request.code);
      await tester.tap(find.byKey(const Key('backButton')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('codeField')), findsOneWidget);
      expect(
        (await tester.runAsync(() => parent.watchDevices().first))!,
        isEmpty,
      );
      await closeApp(tester);
    });

    testWidgets(
      'mostra erro para código curto, desconhecido, QR alheio e código usado',
      (tester) async {
        final request = await childRequest(
          'Celular do Pedro',
          DevicePlatform.android,
        );
        final scanner = FakeScanner();
        await openAdd(tester, scanner: scanner);

        await typeCode(tester, 'ab12');
        expect(find.textContaining('8 letras e números'), findsOneWidget);

        await typeCode(tester, 'AAAAAAAA');
        expect(find.textContaining('Código não encontrado'), findsOneWidget);

        await tester.tap(find.byKey(const Key('scanButton')));
        await tester.pumpAndSettle();
        scanner.scan('https://exemplo.com/qualquer-coisa');
        await tester.pumpAndSettle();
        expect(
          find.textContaining('não é de um aparelho do Guardião'),
          findsOneWidget,
        );

        await parent.approvePairRequest(
          request.code,
        ); // outro caminho já usou o código
        await typeCode(tester, request.code);
        expect(find.textContaining('já foi usado'), findsOneWidget);
        await closeApp(tester);
      },
    );

    testWidgets('câmera sem permissão leva para a digitação com aviso', (
      tester,
    ) async {
      final scanner = FakeScanner();
      await openAdd(tester, scanner: scanner);
      await tester.tap(find.byKey(const Key('scanButton')));
      await tester.pumpAndSettle();
      scanner.fail('Sem a permissão da câmera.');
      await tester.pumpAndSettle();
      expect(find.text('Sem a permissão da câmera.'), findsOneWidget);
      expect(find.byKey(const Key('codeField')), findsOneWidget);
      await closeApp(tester);
    });

    testWidgets(
      'no modo demonstração, o código de exemplo vincula o notebook',
      (tester) async {
        final setup = (await tester.runAsync(() => createBackend()))!;
        await setup.backend.signOut();
        await tester.pumpWidget(
          appFor(setup.backend, role: DeviceRole.parent, isDemo: true),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('submitButton')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('addDeviceButton')));
        await tester.pumpAndSettle();
        expect(
          find.textContaining(formatPairingCode(demoPairingCode)),
          findsOneWidget,
        );
        await typeCode(tester, demoPairingCode);
        await tester.tap(find.byKey(const Key('approveButton')));
        await tester.pumpAndSettle();
        expect(
          find.text('Notebook do Pedro (exemplo) foi vinculado!'),
          findsOneWidget,
        );
        await tester.tap(find.byKey(const Key('doneButton')));
        await tester.pumpAndSettle();
        expect(find.text('Celular do Pedro (exemplo)'), findsOneWidget);
        expect(find.text('Notebook do Pedro (exemplo)'), findsOneWidget);
        await closeApp(tester);
      },
    );
  });
}
