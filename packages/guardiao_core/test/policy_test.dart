import 'package:flutter_test/flutter_test.dart';
import 'package:guardiao_core/guardiao_core.dart';

void main() {
  const roblox = InstalledApp(
    id: 'roblox',
    name: 'Roblox',
    packageName: 'com.roblox.client',
  );
  const duolingo = InstalledApp(
    id: 'duo',
    name: 'Duolingo',
    packageName: 'com.duolingo',
  );
  // Terça-feira, 10/11/2026.
  DateTime at(int h, [int m = 0]) => DateTime(2026, 11, 10, h, m);

  group('categoryOf', () {
    test('reconhece jogos, vídeos, redes, estudo e o resto', () {
      expect(categoryOf(roblox), AppCategory.games);
      expect(categoryOf(duolingo), AppCategory.study);
      expect(
        categoryOf(
          const InstalledApp(
            id: 'n',
            name: 'Netflix',
            packageName: 'com.netflix.mediaclient',
          ),
        ),
        AppCategory.videos,
      );
      expect(
        categoryOf(
          const InstalledApp(
            id: 'w',
            name: 'WhatsApp',
            packageName: 'com.whatsapp',
          ),
        ),
        AppCategory.social,
      );
      expect(
        categoryOf(const InstalledApp(id: 'x', name: 'Relógio')),
        AppCategory.other,
      );
    });
  });

  group('Routine.isActive', () {
    const lunch = Routine(
      id: 'r1',
      name: 'Almoço',
      startMinute: 12 * 60,
      endMinute: 13 * 60,
      days: {1, 2, 3, 4, 5},
    );
    test('vale dentro da faixa e dos dias', () {
      expect(lunch.isActive(at(12, 30)), isTrue);
      expect(lunch.isActive(at(13)), isFalse);
      expect(lunch.isActive(DateTime(2026, 11, 14, 12, 30)), isFalse); // sábado
      expect(lunch.copyWith(enabled: false).isActive(at(12, 30)), isFalse);
    });
    test('faixa que atravessa a meia-noite vale até de manhã', () {
      const sleep = Routine(
        id: 'r2',
        name: 'Dormir',
        startMinute: 21 * 60,
        endMinute: 7 * 60,
        days: {2},
      );
      expect(sleep.isActive(at(22)), isTrue); // terça à noite
      expect(
        sleep.isActive(DateTime(2026, 11, 11, 6, 30)),
        isTrue,
      ); // quarta de manhã
      expect(
        sleep.isActive(DateTime(2026, 11, 11, 22)),
        isFalse,
      ); // quarta à noite
      expect(sleep.isActive(at(6)), isFalse); // terça de manhã (vem da segunda)
    });
    test('vai e volta do mapa', () {
      final back = Routine.fromMap(lunch.toMap())!;
      expect(back.name, 'Almoço');
      expect(back.days, {1, 2, 3, 4, 5});
      expect(Routine.fromMap({'id': 1}), isNull);
    });
  });

  group('DeviceConfig', () {
    test('vai e volta do mapa e ignora itens quebrados', () {
      final config = DeviceConfig(
        lockAll: true,
        routines: const [
          Routine(id: 'a', name: 'A', startMinute: 1, endMinute: 2),
        ],
        missions: defaultMissions,
        blockMessage: 'Oi',
        suggestedMissionId: 'm-quarto',
      );
      final back = DeviceConfig.fromMap({
        ...config.toMap(),
        'routines': [...config.toMap()['routines'] as List, 'lixo'],
      });
      expect(back.lockAll, isTrue);
      expect(back.routines, hasLength(1));
      expect(back.missions, hasLength(4));
      expect(back.suggestedMission?.title, 'Arrumar o quarto');
      expect(DeviceConfig.fromMap(null).lockAll, isFalse);
    });
  });

  group('verdictFor', () {
    const none = DeviceConfig();
    AppVerdict v(
      AppRule? rule, {
      int used = 0,
      DeviceConfig config = none,
      int bonus = 0,
      InstalledApp app = roblox,
      DateTime? now,
    }) => verdictFor(
      app: app,
      rule: rule,
      usedMinutes: used,
      config: config,
      now: now ?? at(15),
      bonusMinutes: bonus,
    );

    test('sem regra, livre', () => expect(v(null).state, AppState.free));
    test('limite com sobra e esgotado', () {
      const rule = AppRule(appId: 'roblox', dailyLimitMinutes: 60);
      expect(v(rule, used: 20).minutesLeft, 40);
      expect(v(rule, used: 60).state, AppState.exhausted);
    });
    test('o bônus de créditos soma ao limite do dia', () {
      const rule = AppRule(appId: 'roblox', dailyLimitMinutes: 60);
      final r = v(rule, used: 60, bonus: 20);
      expect(r.state, AppState.limited);
      expect(r.minutesLeft, 20);
    });
    test('bloqueado vence tudo, inclusive "sempre liberado"', () {
      expect(
        v(const AppRule(appId: 'roblox', blocked: true, alwaysAllowed: true))
            .state,
        AppState.blocked,
      );
    });
    test('bloqueio geral pausa, menos os sempre liberados', () {
      const lock = DeviceConfig(lockAll: true);
      final paused = v(null, config: lock);
      expect(paused.state, AppState.paused);
      expect(paused.reason, 'Bloqueio geral');
      expect(
        v(
          const AppRule(appId: 'roblox', alwaysAllowed: true),
          config: lock,
        ).state,
        AppState.free,
      );
    });
    test('rotina que pausa tudo, só estudo e só jogos', () {
      DeviceConfig routine(RoutineMode mode) => DeviceConfig(
        routines: [
          Routine(
            id: 'r',
            name: 'Lição',
            startMinute: 14 * 60,
            endMinute: 16 * 60,
            mode: mode,
          ),
        ],
      );
      expect(v(null, config: routine(RoutineMode.pauseAll)).reason, 'Lição');
      expect(
        v(null, config: routine(RoutineMode.studyOnly)).state,
        AppState.paused,
      );
      expect(
        v(null, config: routine(RoutineMode.studyOnly), app: duolingo).state,
        AppState.free,
      );
      expect(
        v(null, config: routine(RoutineMode.gamesOnly)).state,
        AppState.free,
      );
      expect(
        v(null, config: routine(RoutineMode.gamesOnly), app: duolingo).state,
        AppState.paused,
      );
      expect(
        v(null, config: routine(RoutineMode.pauseAll), now: at(17)).state,
        AppState.free,
      );
    });
  });

  group('créditos', () {
    final t = DateTime(2026, 11, 10);
    Claim c(String id, ClaimStatus s, int m, {String? usedDay}) => Claim(
      id: id,
      title: id,
      minutes: m,
      status: s,
      createdAt: t,
      usedDay: usedDay,
    );
    test('somam só o aprovado e não usado; bônus é o usado hoje', () {
      final claims = [
        c('a', ClaimStatus.approved, 20),
        c('b', ClaimStatus.pending, 50),
        c('c', ClaimStatus.rejected, 30),
        c('d', ClaimStatus.approved, 15, usedDay: '2026-11-10'),
        c('e', ClaimStatus.approved, 10, usedDay: '2026-11-09'),
      ];
      expect(availableCredit(claims), 20);
      expect(bonusMinutesOf(claims, '2026-11-10'), 15);
    });
  });

  group('MemoryBackend: ajustes e créditos', () {
    test('responsável aprova, criança usa o crédito', () async {
      final cloud = MemoryCloud();
      final parent = MemoryBackend(cloud);
      final child = MemoryBackend(cloud);
      await parent.registerParent('mae@exemplo.com', 'segredo1');
      await child.signInChild();
      final req = await child.createPairRequest(
        deviceName: 'Celular',
        platform: DevicePlatform.android,
      );
      final device = await parent.approvePairRequest(req.code);

      await parent.saveConfig(device.id, const DeviceConfig(lockAll: true));
      expect((await child.watchOwnConfig().first).lockAll, isTrue);

      await child.createClaim(title: 'Ler', minutes: 30);
      var claims = await parent.watchClaims(device.id).first;
      expect(claims.single.status, ClaimStatus.pending);
      await parent.decideClaim(device.id, claims.single.id, true);
      claims = await child.watchOwnClaims().first;
      expect(availableCredit(claims), 30);
      await child.useClaim(claims.single.id, '2026-11-10');
      claims = await child.watchOwnClaims().first;
      expect(availableCredit(claims), 0);
      expect(bonusMinutesOf(claims, '2026-11-10'), 30);
    });
  });
}
