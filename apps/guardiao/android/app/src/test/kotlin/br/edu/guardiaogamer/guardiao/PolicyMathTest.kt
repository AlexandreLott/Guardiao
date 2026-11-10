package br.edu.guardiaogamer.guardiao

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class PolicyMathTest {
    private val game = MonitoredApp("com.roblox.client", "Roblox", 60, false, false, "games")
    private val study = MonitoredApp("com.duolingo", "Duolingo", null, false, false, "study")

    private fun plan(
        lockAll: Boolean = false,
        routines: List<RoutineRule> = emptyList(),
        bonusDay: String? = null,
        bonus: Int = 0,
    ) = MonitorPlan(listOf(game, study), lockAll, routines, bonusDay, bonus)

    private fun eval(app: MonitoredApp, used: Int, p: MonitorPlan, weekday: Int = 2, minute: Int = 15 * 60) =
        PolicyMath.evaluate(app, used, p, weekday, minute, "2026-11-10").verdict

    @Test
    fun limitEsgotaESomaBonusDoDia() {
        assertEquals(PolicyMath.Verdict.ALLOW, eval(game, 59, plan()))
        assertEquals(PolicyMath.Verdict.EXHAUSTED, eval(game, 60, plan()))
        assertEquals(PolicyMath.Verdict.ALLOW, eval(game, 60, plan(bonusDay = "2026-11-10", bonus = 20)))
        // Bônus de outro dia não vale hoje.
        assertEquals(PolicyMath.Verdict.EXHAUSTED, eval(game, 60, plan(bonusDay = "2026-11-09", bonus = 20)))
    }

    @Test
    fun bloqueadoVenceTudo() {
        val blocked = game.copy(blocked = true, allowed = true)
        assertEquals(PolicyMath.Verdict.BLOCKED, eval(blocked, 0, plan()))
    }

    @Test
    fun bloqueioGeralPausaMenosOsSempreLiberados() {
        assertEquals(PolicyMath.Verdict.PAUSED, eval(game, 0, plan(lockAll = true)))
        assertEquals(PolicyMath.Verdict.ALLOW, eval(game.copy(allowed = true), 0, plan(lockAll = true)))
    }

    @Test
    fun rotinasPorModo() {
        fun routine(mode: String) =
            listOf(RoutineRule("Lição", 14 * 60, 16 * 60, setOf(2), mode, true))
        assertEquals(PolicyMath.Verdict.PAUSED, eval(study, 0, plan(routines = routine("pause_all"))))
        assertEquals(PolicyMath.Verdict.ALLOW, eval(study, 0, plan(routines = routine("study_only"))))
        assertEquals(PolicyMath.Verdict.PAUSED, eval(game, 0, plan(routines = routine("study_only"))))
        assertEquals(PolicyMath.Verdict.ALLOW, eval(game, 0, plan(routines = routine("games_only"))))
        assertEquals(PolicyMath.Verdict.PAUSED, eval(study, 0, plan(routines = routine("games_only"))))
        // Fora do horário ou de outro dia, nada muda.
        assertEquals(PolicyMath.Verdict.ALLOW, eval(game, 0, plan(routines = routine("pause_all")), minute = 17 * 60))
        assertEquals(PolicyMath.Verdict.ALLOW, eval(game, 0, plan(routines = routine("pause_all")), weekday = 3))
    }

    @Test
    fun rotinaDesligadaNaoVale() {
        val off = listOf(RoutineRule("X", 0, 1439, setOf(2), "pause_all", false))
        assertEquals(PolicyMath.Verdict.ALLOW, eval(game, 0, plan(routines = off)))
    }

    @Test
    fun faixaQueCruzaAMeiaNoite() {
        val sleep = RoutineRule("Dormir", 21 * 60, 7 * 60, setOf(2), "pause_all", true)
        assertTrue(PolicyMath.routineActive(sleep, 2, 22 * 60)) // terça à noite
        assertTrue(PolicyMath.routineActive(sleep, 3, 6 * 60)) // quarta de manhã
        assertFalse(PolicyMath.routineActive(sleep, 3, 22 * 60)) // quarta à noite
        assertFalse(PolicyMath.routineActive(sleep, 2, 6 * 60)) // terça de manhã vem da segunda
    }
}
