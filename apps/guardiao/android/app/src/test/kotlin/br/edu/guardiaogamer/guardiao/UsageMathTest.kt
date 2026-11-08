package br.edu.guardiaogamer.guardiao

import br.edu.guardiaogamer.guardiao.UsageMath.Event
import br.edu.guardiaogamer.guardiao.UsageMath.PAUSED
import br.edu.guardiaogamer.guardiao.UsageMath.RESUMED
import br.edu.guardiaogamer.guardiao.UsageMath.SCREEN_OFF
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class UsageMathTest {
    private val min = 60_000L

    @Test
    fun `soma as sessões de um aplicativo`() {
        val r = UsageMath.compute(
            listOf(
                Event("jogo", RESUMED, 0), Event("jogo", PAUSED, 10 * min),
                Event("outro", RESUMED, 10 * min), Event("outro", PAUSED, 15 * min),
                Event("jogo", RESUMED, 20 * min), Event("jogo", PAUSED, 25 * min),
            ),
            now = 30 * min,
        )
        assertEquals(15, r.minutes("jogo"))
        assertEquals(5, r.minutes("outro"))
        assertNull(r.foreground)
    }

    @Test
    fun `aplicativo ainda aberto conta até agora e é o primeiro plano`() {
        val r = UsageMath.compute(listOf(Event("jogo", RESUMED, 5 * min)), now = 12 * min)
        assertEquals(7, r.minutes("jogo"))
        assertEquals("jogo", r.foreground)
    }

    @Test
    fun `trocar de tela dentro do mesmo app não perde tempo`() {
        // A2 fica visível antes de A1 pausar: o app continua em uso o tempo todo.
        val r = UsageMath.compute(
            listOf(
                Event("jogo", RESUMED, 0), Event("jogo", RESUMED, 4 * min),
                Event("jogo", PAUSED, 4 * min + 100), Event("jogo", PAUSED, 9 * min),
            ),
            now = 20 * min,
        )
        assertEquals(9, r.minutes("jogo"))
    }

    @Test
    fun `outro app na tela fecha o anterior mesmo sem evento de pausa`() {
        val r = UsageMath.compute(
            listOf(Event("a", RESUMED, 0), Event("b", RESUMED, 6 * min), Event("b", PAUSED, 8 * min)),
            now = 10 * min,
        )
        assertEquals(6, r.minutes("a"))
        assertEquals(2, r.minutes("b"))
    }

    @Test
    fun `tela apagada fecha a sessão`() {
        val r = UsageMath.compute(
            listOf(Event("jogo", RESUMED, 0), Event(null, SCREEN_OFF, 3 * min)),
            now = 60 * min,
        )
        assertEquals(3, r.minutes("jogo"))
        assertNull(r.foreground)
    }

    @Test
    fun `eventos fora de ordem e pausa sem início são ignorados`() {
        val r = UsageMath.compute(
            listOf(Event("jogo", PAUSED, 2 * min), Event("jogo", PAUSED, 1 * min)),
            now = 5 * min,
        )
        assertEquals(0, r.minutes("jogo"))
        val ordered = UsageMath.compute(
            listOf(Event("jogo", PAUSED, 5 * min), Event("jogo", RESUMED, 1 * min)),
            now = 9 * min,
        )
        assertEquals(4, ordered.minutes("jogo"))
    }

    @Test
    fun `bloqueia quando o limite acaba ou o responsável bloqueou`() {
        assertFalse(UsageMath.shouldBlock(false, 60, 59))
        assertTrue(UsageMath.shouldBlock(false, 60, 60))
        assertTrue(UsageMath.shouldBlock(false, 0, 0))
        assertFalse(UsageMath.shouldBlock(false, null, 10_000))
        assertTrue(UsageMath.shouldBlock(true, null, 0))
    }
}
