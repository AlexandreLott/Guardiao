import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:guardiao_core/guardiao_core.dart';

void main() {
  group('código de pareamento', () {
    test('tem 8 caracteres do alfabeto sem ambiguidade', () {
      final code = generatePairingCode(Random(1));
      expect(code, hasLength(pairingCodeLength));
      expect(code.split('').every(pairingAlphabet.contains), isTrue);
      expect(pairingAlphabet.contains('0'), isFalse);
      expect(pairingAlphabet.contains('O'), isFalse);
      expect(pairingAlphabet.contains('I'), isFalse);
    });

    test('é diferente a cada chamada', () {
      final rng = Random(7);
      final codes = {for (var i = 0; i < 500; i++) generatePairingCode(rng)};
      expect(codes.length, 500);
    });

    test('normaliza e formata', () {
      expect(normalizePairingCode(' k7m2-9qxa '), 'K7M29QXA');
      expect(formatPairingCode('k7m29qxa'), 'K7M2-9QXA');
      expect(isValidPairingCode('k7m2-9qxa'), isTrue);
      expect(isValidPairingCode('K7M2-9QX'), isFalse);
      expect(isValidPairingCode('K7M2-9Q0A'), isFalse); // 0 não existe no alfabeto
    });
  });

  group('AppRule', () {
    test('sem limite devolve null', () {
      expect(const AppRule(appId: 'a').remainingMinutes(40), isNull);
    });
    test('desconta o tempo usado e nunca fica negativo', () {
      const rule = AppRule(appId: 'a', dailyLimitMinutes: 60);
      expect(rule.remainingMinutes(25), 35);
      expect(rule.remainingMinutes(90), 0);
    });
    test('bloqueado sempre zera', () {
      const rule = AppRule(appId: 'a', dailyLimitMinutes: 60, blocked: true);
      expect(rule.remainingMinutes(0), 0);
    });
    test('ida e volta pelo mapa', () {
      const rule = AppRule(appId: 'a', dailyLimitMinutes: 45, blocked: true);
      final back = AppRule.fromMap('a', rule.toMap());
      expect(back.dailyLimitMinutes, 45);
      expect(back.blocked, isTrue);
      expect(const AppRule(appId: 'x').isDefault, isTrue);
    });
  });

  test('safeId remove barras e limita o tamanho', () {
    expect(safeId('a/b c'), 'a_b_c');
    expect(safeId('   '), 'app');
    expect(safeId('x' * 300), hasLength(120));
  });

  test('maskEmail esconde o meio do endereço', () {
    expect(maskEmail('joao.silva@gmail.com'), 'jo***@gmail.com');
    expect(maskEmail('ab@x.com'), 'a***@x.com');
    expect(maskEmail('a@x.com'), 'a***@x.com');
    expect(maskEmail(null), 'um responsável');
    expect(maskEmail('sem-arroba'), 'um responsável');
    expect(maskEmail('@x.com'), 'um responsável');
  });

  test('dayKey completa com zeros', () {
    expect(dayKey(DateTime(2026, 1, 5)), '2026-01-05');
    expect(dayKey(DateTime(2026, 11, 28)), '2026-11-28');
  });
}
