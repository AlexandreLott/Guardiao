package br.edu.guardiaogamer.guardiao

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/** Religa o acompanhamento depois que o aparelho reinicia. */
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Intent.ACTION_BOOT_COMPLETED) return
        if (!MonitorConfig.isEnabled(context)) return
        try {
            MonitorService.start(context)
        } catch (_: Exception) {
            // O sistema pode recusar; o serviço volta quando o app for aberto.
        }
    }
}
