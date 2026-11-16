package br.edu.guardiaogamer.guardiao

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * Religa o acompanhamento quando o aparelho liga, quando ele volta de um
 * "início rápido" (alguns fabricantes usam um aviso próprio) e depois que o
 * app é atualizado.
 */
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action !in ACTIONS) return
        if (!MonitorConfig.isEnabled(context)) return
        WatchdogJob.schedule(context)
        try {
            MonitorService.start(context)
        } catch (_: Exception) {
            // O sistema pode recusar agora; o vigia tenta de novo em minutos.
        }
    }

    private companion object {
        val ACTIONS = setOf(
            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_MY_PACKAGE_REPLACED,
            "android.intent.action.QUICKBOOT_POWERON",
            "com.htc.intent.action.QUICKBOOT_POWERON",
        )
    }
}
