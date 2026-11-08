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
    testWidgets('mostra o login, recusa senha curta e e-mail inválido', (tester) async {
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

    testWidgets('cria a conta e cai na lista vazia de aparelhos', (tester) async {
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
      await tester.pumpWidget(appFor(setup.backend, role: DeviceRole.parent, isDemo: true));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('submitButton'))); // credenciais já preenchidas
      await tester.pumpAndSettle();
    }

    testWidgets('lista o aparelho, os apps e as regras já existentes', (tester) async {
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

    testWidgets('define um limite diário e o aplicativo mostra a regra', (tester) async {
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
            of: find.byType(ListView), matching: find.byType(Scrollable)),
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
            of: find.byType(ListView), matching: find.byType(Scrollable)),
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

    testWidgets('remover o aparelho pede confirmação e volta para a lista', (tester) async {
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

  testWidgets('adicionar aparelho mostra o código e avisa quando o filho vincula',
      (tester) async {
    final cloud = MemoryCloud();
    final parent = MemoryBackend(cloud);
    await parent.registerParent('mae@exemplo.com', 'segredo1');
    await tester.pumpWidget(appFor(parent, role: DeviceRole.parent));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('addDeviceButton')));
    await tester.pumpAndSettle();
    final codeText = tester.widget<Text>(find.byKey(const Key('pairingCode'))).data!;
    expect(codeText, matches(RegExp(r'^[A-Z2-9]{4}-[A-Z2-9]{4}$')));
    expect(find.textContaining('Vale por mais'), findsOneWidget);

    // O filho digita o código em outro aparelho.
    final child = MemoryBackend(cloud);
    await child.signInChild();
    await child.claimPairing(
        code: codeText, deviceName: 'Notebook do Pedro', platform: DevicePlatform.windows);
    await tester.pumpAndSettle();

    expect(find.text('Notebook do Pedro foi vinculado!'), findsOneWidget);
    await tester.tap(find.text('Pronto'));
    await tester.pumpAndSettle();
    expect(find.text('Notebook do Pedro'), findsOneWidget);
    expect(find.text('Windows · Online agora'), findsOneWidget);
    await closeApp(tester);
  });

  testWidgets('"Novo código" troca o código mostrado', (tester) async {
    final parent = MemoryBackend(MemoryCloud());
    await parent.registerParent('mae@exemplo.com', 'segredo1');
    await tester.pumpWidget(appFor(parent, role: DeviceRole.parent));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('addDeviceButton')));
    await tester.pumpAndSettle();
    final first = tester.widget<Text>(find.byKey(const Key('pairingCode'))).data;
    await tester.tap(find.byKey(const Key('newCodeButton')));
    await tester.pumpAndSettle();
    final second = tester.widget<Text>(find.byKey(const Key('pairingCode'))).data;
    expect(second, isNot(first));
    await closeApp(tester);
  });
}
