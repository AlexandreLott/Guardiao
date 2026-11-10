import 'models.dart';

/// Situação de um app neste momento.
enum AppState {
  /// Sem regra: usa à vontade.
  free,

  /// Tem limite e ainda sobra tempo.
  limited,

  /// O tempo do dia acabou.
  exhausted,

  /// Bloqueado pelo responsável o dia todo.
  blocked,

  /// Parado por "Bloqueio geral" ou por uma rotina.
  paused,
}

/// Resultado da conta de [verdictFor].
class AppVerdict {
  const AppVerdict(this.state, {this.minutesLeft, this.reason});

  final AppState state;

  /// Minutos que sobram hoje (só para [AppState.limited]).
  final int? minutesLeft;

  /// Por que está parado ("Bloqueio geral", "Hora de dormir").
  final String? reason;

  /// Pode ser aberto agora?
  bool get allowed => state == AppState.free || state == AppState.limited;
}

/// Junta regra, tempo usado, bônus de créditos, bloqueio geral e rotinas.
///
/// Ordem: bloqueado pelo responsável → pausas (bloqueio geral e rotinas, que
/// não valem para apps "sempre liberados") → limite diário (somado do bônus).
AppVerdict verdictFor({
  required InstalledApp app,
  required AppRule? rule,
  required int usedMinutes,
  required DeviceConfig config,
  required DateTime now,
  int bonusMinutes = 0,
}) {
  if (rule?.blocked ?? false) return const AppVerdict(AppState.blocked);
  final always = rule?.alwaysAllowed ?? false;
  if (!always) {
    if (config.lockAll) {
      return const AppVerdict(AppState.paused, reason: 'Bloqueio geral');
    }
    final category = categoryOf(app);
    for (final r in config.activeRoutines(now)) {
      final stops = switch (r.mode) {
        RoutineMode.pauseAll => true,
        RoutineMode.studyOnly => category != AppCategory.study,
        RoutineMode.gamesOnly => category != AppCategory.games,
      };
      if (stops) return AppVerdict(AppState.paused, reason: r.name);
    }
  }
  final limit = rule?.dailyLimitMinutes;
  if (limit == null) return const AppVerdict(AppState.free);
  final left = limit + bonusMinutes - usedMinutes;
  if (left <= 0) return const AppVerdict(AppState.exhausted);
  return AppVerdict(AppState.limited, minutesLeft: left);
}
