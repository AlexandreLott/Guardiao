package br.edu.guardiaogamer.guardiao

/**
 * Decide se um aplicativo pode abrir agora. Espelha `verdictFor` do Dart
 * (packages/guardiao_core/lib/src/policy.dart), sem nada do Android, para
 * poder ser testado sozinho.
 */
object PolicyMath {
    enum class Verdict { ALLOW, BLOCKED, EXHAUSTED, PAUSED }

    data class Result(val verdict: Verdict, val reason: String? = null)

    /** A rotina vale neste instante? Faixas que cruzam a meia-noite valem até de manhã. */
    fun routineActive(r: RoutineRule, weekday: Int, minute: Int): Boolean {
        if (!r.enabled) return false
        if (r.startMinute <= r.endMinute) {
            return weekday in r.days && minute >= r.startMinute && minute < r.endMinute
        }
        if (minute >= r.startMinute) return weekday in r.days
        if (minute < r.endMinute) {
            val yesterday = if (weekday == 1) 7 else weekday - 1
            return yesterday in r.days
        }
        return false
    }

    fun evaluate(
        app: MonitoredApp,
        usedMinutes: Int,
        plan: MonitorPlan,
        weekday: Int,
        minute: Int,
        today: String,
    ): Result {
        if (app.blocked) return Result(Verdict.BLOCKED)
        if (!app.allowed) {
            if (plan.lockAll) return Result(Verdict.PAUSED, "Bloqueio geral")
            for (r in plan.routines) {
                if (!routineActive(r, weekday, minute)) continue
                val stops = when (r.mode) {
                    "study_only" -> app.category != "study"
                    "games_only" -> app.category != "games"
                    else -> true
                }
                if (stops) return Result(Verdict.PAUSED, r.name)
            }
        }
        val limit = app.limitMinutes ?: return Result(Verdict.ALLOW)
        val bonus = if (plan.bonusDay == today) plan.bonusMinutes else 0
        return if (usedMinutes >= limit + bonus) Result(Verdict.EXHAUSTED) else Result(Verdict.ALLOW)
    }
}
