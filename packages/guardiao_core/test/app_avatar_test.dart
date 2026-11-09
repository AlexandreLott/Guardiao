import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guardiao_core/guardiao_core.dart';

// PNG 1x1 transparente.
final _png = base64Encode(
  base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
  ),
);

void main() {
  testWidgets('com ícone mostra a imagem; sem ícone, a letra', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Column(
          children: [
            AppAvatar(InstalledApp(id: 'a', name: 'Roblox', icon: _png)),
            const AppAvatar(InstalledApp(id: 'b', name: 'Minecraft')),
            const AppAvatar(
              InstalledApp(id: 'c', name: 'Quebrado', icon: '%%%'),
            ),
          ],
        ),
      ),
    );
    expect(find.byKey(const Key('appIcon')), findsOneWidget);
    expect(find.text('M'), findsOneWidget);
    expect(
      find.text('Q'),
      findsOneWidget,
      reason: 'ícone inválido cai na letra',
    );
    expect(find.text('R'), findsNothing);
  });

  test('o ícone viaja no mapa do app e entra na comparação', () {
    final a = InstalledApp(id: 'a', name: 'A', icon: 'AAAA');
    final back = InstalledApp.fromMap('a', a.toMap());
    expect(back, a);
    expect(back.icon, 'AAAA');
    expect(const InstalledApp(id: 'a', name: 'A') == a, isFalse);
  });
}
