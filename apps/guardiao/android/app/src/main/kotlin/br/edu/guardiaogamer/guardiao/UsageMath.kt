package br.edu.guardiaogamer.guardiao

/**
 * Contas do tempo de uso, sem nada do Android: recebe a lista de eventos do
 * UsageStatsManager já convertida e devolve quanto cada aplicativo ficou na
 * tela. Fica separado do serviço para poder ser testado sozinho.
 */
object UsageMath {
    /** ACTIVITY_RESUMED (Android 10+) e MOVE_TO_FOREGROUND (antes): mesmo valor. */
    const val RESUMED = 1

    /** ACTIVITY_PAUSED e MOVE_TO_BACKGROUND: mesmo valor. */
    const val PAUSED = 2

    /** SCREEN_NON_INTERACTIVE: a tela apagou. */
    const val SCREEN_OFF = 16

    /** DEVICE_SHUTDOWN. */
    const val SHUTDOWN = 26

    data class Event(val pkg: String?, val type: Int, val time: Long)

    data class Result(
        /** Milissegundos em primeiro plano, por pacote. */
        val millisByPackage: Map<String, Long>,
        /** Pacote que está na tela agora, se houver. */
        val foreground: String?,
    ) {
        fun minutes(pkg: String): Int = ((millisByPackage[pkg] ?: 0L) / 60_000L).toInt()
    }

    /**
     * Só um aplicativo fica em primeiro plano por vez. Quando outro volta a
     * ficar visível, o anterior é fechado na hora, mesmo que o evento de
     * "pausa" tenha se perdido. Apagar a tela ou desligar fecha tudo.
     */
    fun compute(events: List<Event>, now: Long): Result {
        val totals = HashMap<String, Long>()
        var current: String? = null
        var start = 0L
        var depth = 0

        fun close(at: Long) {
            val pkg = current ?: return
            if (at > start) totals[pkg] = (totals[pkg] ?: 0L) + (at - start)
            current = null
            depth = 0
        }

        for (e in events.sortedBy { it.time }) {
            when (e.type) {
                RESUMED -> {
                    val pkg = e.pkg ?: continue
                    if (current == pkg) {
                        depth++
                    } else {
                        close(e.time)
                        current = pkg
                        start = e.time
                        depth = 1
                    }
                }
                PAUSED -> {
                    if (current != null && current == e.pkg) {
                        depth--
                        if (depth <= 0) close(e.time)
                    }
                }
                SCREEN_OFF, SHUTDOWN -> close(e.time)
            }
        }
        val foreground = current
        close(now)
        return Result(totals, foreground)
    }

    /** Decide se o aplicativo deve ser bloqueado agora. */
    fun shouldBlock(blocked: Boolean, limitMinutes: Int?, usedMinutes: Int): Boolean =
        blocked || (limitMinutes != null && usedMinutes >= limitMinutes)
}
