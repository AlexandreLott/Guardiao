import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guardiao/role/role.dart';
import 'package:guardiao_core/guardiao_core.dart';

import 'helpers.dart';

void main() {
  test('DeviceRole.parse aceita só nomes válidos', () {
    expect(DeviceRole.parse('parent'), DeviceRole.parent);
    expect(DeviceRole.parse('child'), DeviceRole.child);
    expect(DeviceRole.parse('admin'), isNull);
    expect(DeviceRole.parse(null), isNull);
  });

  testWidgets('primeiro acesso mostra a escolha e guarda a função', (tester) async {
    final store = MemoryRoleStore();
    final backend = MemoryBackend(MemoryCloud());
    await tester.pumpWidget(appFor(backend, store: store));
    await tester.pumpAndSettle();

    expect(find.text('Este aparelho é de quem?'), findsOneWidget);
    await tester.tap(find.byKey(const Key('roleParent')));
    await tester.pumpAndSettle();

    expect(await store.read(), DeviceRole.parent);
    expect(find.text('Entrar'), findsOneWidget); // login do responsável
    await closeApp(tester);
  });

  testWidgets('escolher "filho" abre o pedido de código', (tester) async {
    final store = MemoryRoleStore();
    final backend = MemoryBackend(MemoryCloud());
    await tester.pumpWidget(appFor(backend, store: store));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('roleChild')));
    await tester.pumpAndSettle();

    expect(await store.read(), DeviceRole.child);
    expect(find.text('Vincular este aparelho'), findsOneWidget);
    await closeApp(tester);
  });

  testWidgets('quem já escolheu pula a tela de escolha', (tester) async {
    final backend = MemoryBackend(MemoryCloud());
    await tester.pumpWidget(appFor(backend, role: DeviceRole.child));
    await tester.pumpAndSettle();
    expect(find.text('Este aparelho é de quem?'), findsNothing);
    expect(find.text('Vincular este aparelho'), findsOneWidget);
    await closeApp(tester);
  });

  testWidgets('dá para voltar e escolher outra função antes de vincular', (tester) async {
    final store = MemoryRoleStore(DeviceRole.child);
    final backend = MemoryBackend(MemoryCloud());
    await tester.pumpWidget(appFor(backend, role: DeviceRole.child, store: store));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const Key('changeRoleButton')));
    await tester.tap(find.byKey(const Key('changeRoleButton')));
    await tester.pumpAndSettle();
    expect(await store.read(), isNull);
    expect(find.text('Este aparelho é de quem?'), findsOneWidget);
    expect(backend.currentUid, isNull); // saiu da conta anônima

    await tester.tap(find.byKey(const Key('roleParent')));
    await tester.pumpAndSettle();
    expect(find.text('Entrar'), findsOneWidget);
    await closeApp(tester);
  });

  testWidgets('responsável troca a função pelo menu da conta', (tester) async {
    final cloud = MemoryCloud();
    final backend = MemoryBackend(cloud);
    await backend.registerParent('mae@exemplo.com', 'segredo1');
    final store = MemoryRoleStore(DeviceRole.parent);
    await tester.pumpWidget(appFor(backend, role: DeviceRole.parent, store: store));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('accountMenu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('changeRoleItem')));
    await tester.pumpAndSettle();

    expect(find.text('Este aparelho é de quem?'), findsOneWidget);
    expect(await store.read(), isNull);
    expect(backend.currentUid, isNull);
    await closeApp(tester);
  });
}
