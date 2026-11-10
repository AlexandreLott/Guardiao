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
      expect(find.byKey(const Key('submitButton')), findsOneWidget);

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
      expect(find.text('Criar conta'), findsNWidgets(2));
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
      expect(find.byKey(const Key('submitButton')), findsOneWidget);
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

    Future<void> openPanel(WidgetTester tester, [int tab = 0]) async {
      tallScreen(tester);
      await openDemo(tester);
      await tester.tap(find.text('Celular do Pedro (exemplo)'));
      await tester.pumpAndSettle();
      if (tab > 0) {
        await tester.tap(find.byKey(Key('seg_$tab')));
        await tester.pumpAndSettle();
      }
    }

    testWidgets('resumo soma o dia e conta limites e bloqueios', (
      tester,
    ) async {
      await openPanel(tester);
      expect(find.text('Painel do responsável'), findsOneWidget);
      // 45 + 20 + 12 min de uso nos dados de exemplo.
      expect(
        find.descendant(
          of: find.byKey(const Key('statUsed')),
          matching: find.text('1h 17min'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('statLimited')),
          matching: find.text('1'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('statBlocked')),
          matching: find.text('1'),
        ),
        findsOneWidget,
      );
      await closeApp(tester);
    });

    testWidgets('lista os apps com as regras já existentes', (tester) async {
      await openPanel(tester, 1);
      expect(find.text('7 apps'), findsOneWidget);
      expect(find.text('45 min de 1h hoje'), findsOneWidget); // Roblox
      expect(find.text('Bloqueado o dia todo'), findsOneWidget); // Free Fire
      // Apps com regra aparecem antes dos outros.
      final roblox = tester.getTopLeft(find.text('Roblox')).dy;
      final minecraft = tester.getTopLeft(find.text('Minecraft')).dy;
      expect(roblox, lessThan(minecraft));
      await closeApp(tester);
    });

    testWidgets('busca e categorias filtram os aplicativos', (tester) async {
      await openPanel(tester, 1);
      await tester.enterText(find.byKey(const Key('searchField')), 'mine');
      await tester.pumpAndSettle();
      expect(find.text('Minecraft'), findsOneWidget);
      expect(find.text('Roblox'), findsNothing);
      await tester.enterText(find.byKey(const Key('searchField')), 'zzz');
      await tester.pumpAndSettle();
      expect(find.text('Nenhum aplicativo encontrado.'), findsOneWidget);
      await tester.enterText(find.byKey(const Key('searchField')), '');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(Key('chip_${AppCategory.games.name}')));
      await tester.pumpAndSettle();
      expect(find.text('Roblox'), findsOneWidget);
      expect(find.text('Chrome'), findsNothing);
      await closeApp(tester);
    });

    testWidgets('define um limite diário e o aplicativo mostra a regra', (
      tester,
    ) async {
      await openPanel(tester, 1);
      await tester.tap(find.text('Minecraft'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('limitSwitch')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('limitLabel')), findsOneWidget);
      await tester.tap(find.byKey(const Key('saveRuleButton')));
      await tester.pumpAndSettle();
      // Minecraft agora tem limite (e sobe para o grupo "com regra").
      expect(find.textContaining(' de 1h hoje'), findsNWidgets(2));
      await closeApp(tester);
    });

    testWidgets('bloqueia um app e depois remove a regra', (tester) async {
      await openPanel(tester, 1);
      await tester.enterText(find.byKey(const Key('searchField')), 'chrome');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Chrome'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('blockSwitch')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('saveRuleButton')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('searchField')), '');
      await tester.pumpAndSettle();
      expect(find.text('Bloqueado o dia todo'), findsNWidgets(2));

      await tester.enterText(find.byKey(const Key('searchField')), 'chrome');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Chrome'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('blockSwitch')));
      await tester.pumpAndSettle();
      expect(find.text('Remover regra'), findsOneWidget);
      await tester.tap(find.byKey(const Key('saveRuleButton')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('searchField')), '');
      await tester.pumpAndSettle();
      expect(find.text('Bloqueado o dia todo'), findsOneWidget);
      await closeApp(tester);
    });

    testWidgets('app "sempre liberado" ganha a etiqueta', (tester) async {
      await openPanel(tester, 1);
      await tester.enterText(find.byKey(const Key('searchField')), 'chrome');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Chrome'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('allowedSwitch')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('saveRuleButton')));
      await tester.pumpAndSettle();
      expect(find.text('Sempre liberado'), findsOneWidget);
      await closeApp(tester);
    });

    testWidgets('bloqueio geral liga e aparece na prévia da criança', (
      tester,
    ) async {
      await openPanel(tester);
      await tester.tap(find.byKey(const Key('lockAllSwitch')));
      await tester.pumpAndSettle();
      expect(
        tester.widget<Switch>(find.byKey(const Key('lockAllSwitch'))).value,
        isTrue,
      );
      await tester.ensureVisible(find.byKey(const Key('previewButton')));
      await tester.tap(find.byKey(const Key('previewButton')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('previewBack')), findsOneWidget);
      await tester.tap(find.byKey(const Key('previewBack')));
      await tester.pumpAndSettle();
      await closeApp(tester);
    });

    testWidgets('rotinas: cria as sugeridas, desliga e exclui', (tester) async {
      await openPanel(tester, 2);
      await tester.tap(find.byKey(const Key('suggestedRoutines')));
      await tester.pumpAndSettle();
      expect(find.text('Hora de dormir'), findsOneWidget);
      expect(find.text('21:00 – 07:00 · Todos os dias'), findsOneWidget);
      await tester.ensureVisible(
        find.byKey(const Key('routineSwitch_r-dormir')),
      );
      await tester.tap(find.byKey(const Key('routineSwitch_r-dormir')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<Switch>(find.byKey(const Key('routineSwitch_r-dormir')))
            .value,
        isFalse,
      );
      await tester.tap(find.byKey(const Key('routine_r-dormir')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('deleteRoutine')));
      await tester.tap(find.byKey(const Key('deleteRoutine')));
      await tester.pumpAndSettle();
      expect(find.text('Hora de dormir'), findsNothing);
      await closeApp(tester);
    });

    testWidgets('rotinas: cria uma nova com nome e dias', (tester) async {
      await openPanel(tester, 2);
      await tester.tap(find.byKey(const Key('newRoutine')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('saveRoutine')));
      await tester.pumpAndSettle();
      expect(find.text('Dê um nome para a rotina.'), findsOneWidget);
      await tester.enterText(find.byKey(const Key('routineName')), 'Natação');
      await tester.tap(find.byKey(const Key('day_1'))); // tira segunda
      await tester.ensureVisible(find.byKey(const Key('saveRoutine')));
      await tester.tap(find.byKey(const Key('saveRoutine')));
      await tester.pumpAndSettle();
      expect(find.text('Natação'), findsOneWidget);
      expect(find.text('14:00 – 16:00 · Ter, Qua, Qui e Sex'), findsOneWidget);
      await closeApp(tester);
    });

    testWidgets('créditos: aprova o pedido da criança e cria missões', (
      tester,
    ) async {
      tallScreen(tester);
      final cloud = MemoryCloud();
      final parent = MemoryBackend(cloud);
      await parent.registerParent('mae@exemplo.com', 'segredo1');
      final child = MemoryBackend(cloud);
      await child.signInChild();
      final request = await child.createPairRequest(
        deviceName: 'Celular do Pedro',
        platform: DevicePlatform.android,
      );
      await parent.approvePairRequest(request.code);
      await child.createClaim(title: 'Arrumar o quarto', minutes: 30);

      await tester.pumpWidget(appFor(parent, role: DeviceRole.parent));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Celular do Pedro'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('seg_3')));
      await tester.pumpAndSettle();
      expect(find.text('1 para aprovar'), findsOneWidget);
      expect(find.text('Pedro fez: Arrumar o quarto'), findsOneWidget);
      final claims = await tester.runAsync(
        () => parent.watchClaims(request.deviceId).first,
      );
      await tester.tap(find.byKey(Key('approve_${claims!.single.id}')));
      await tester.pumpAndSettle();
      expect(find.text('nada para aprovar'), findsOneWidget);

      await tester.tap(find.byKey(const Key('suggestedMissions')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(Key('mission_${defaultMissions.first.id}')),
        findsOneWidget,
      );
      await closeApp(tester);
    });

    testWidgets('remover o aparelho pede confirmação e volta para a lista', (
      tester,
    ) async {
      await openPanel(tester);
      await tester.ensureVisible(find.byKey(const Key('removeDevice')));
      await tester.tap(find.byKey(const Key('removeDevice')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(find.text('Painel do responsável'), findsOneWidget);

      await tester.tap(find.byKey(const Key('removeDevice')));
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
      expect(find.text('Vincular aparelho'), findsOneWidget);
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
        expect(find.textContaining('como K7M2-9QXA'), findsOneWidget);

        await typeCode(tester, 'AAAAAAAA');
        expect(find.textContaining('Código não encontrado'), findsOneWidget);

        await tester.tap(find.byKey(const Key('scanButton')));
        await tester.pumpAndSettle();
        scanner.scan('https://exemplo.com/qualquer-coisa');
        await tester.pumpAndSettle();
        expect(
          find.textContaining('não é de um aparelho do Guardian'),
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
