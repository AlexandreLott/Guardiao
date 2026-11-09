package br.edu.guardiaogamer.guardiao

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class HealthMathTest {
    private val now = 10_000_000L

    @Test
    fun servicoDesligadoNaoContaComoParado() {
        assertTrue(HealthMath.monitorRunning(enabled = false, tickAt = 0, now = now))
    }

    @Test
    fun servicoQueBateuHaPoucoEstaRodando() {
        assertTrue(HealthMath.monitorRunning(true, now - 60_000, now))
        assertTrue(HealthMath.monitorRunning(true, now - HealthMath.STALE_MS, now))
    }

    @Test
    fun servicoSemBaterHaMuitoTempoEstaParado() {
        assertFalse(HealthMath.monitorRunning(true, now - HealthMath.STALE_MS - 1, now))
    }

    @Test
    fun servicoQueNuncaBateuEstaParado() {
        assertFalse(HealthMath.monitorRunning(true, 0, now))
    }

    @Test
    fun jsonTemTodosOsCampos() {
        assertEquals(
            "{\"usageAccess\":true,\"overlay\":false,\"notifications\":true,\"admin\":false," +
                "\"monitorRunning\":true,\"checkedAt\":42}",
            HealthMath.toJson(true, false, true, false, true, 42),
        )
    }
}
