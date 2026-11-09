package br.edu.guardiaogamer.guardiao

import android.app.admin.DeviceAdminReceiver
import android.content.Context
import android.content.Intent

/**
 * Administrador do dispositivo. Não pede nenhuma política: serve só para o
 * Android exigir que ele seja desativado antes de desinstalar o Guardião. No
 * momento da desativação, a situação é gravada para a tarefa em segundo plano
 * avisar o responsável.
 */
class GuardianAdminReceiver : DeviceAdminReceiver() {
    override fun onEnabled(context: Context, intent: Intent) {
        HealthSnapshot.write(context, adminOverride = true)
    }

    override fun onDisableRequested(context: Context, intent: Intent): CharSequence =
        "Ao desativar esta proteção, o responsável será avisado e o Guardião poderá ser desinstalado."

    override fun onDisabled(context: Context, intent: Intent) {
        HealthSnapshot.write(context, adminOverride = false)
    }
}
