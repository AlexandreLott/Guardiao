package br.edu.guardiaogamer.guardiao

import android.Manifest
import android.app.NotificationManager
import android.app.admin.DevicePolicyManager
import android.content.ComponentName
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.provider.Settings

/** Contas simples sobre a situação das proteções (sem depender do Android). */
object HealthMath {
    /** O serviço de acompanhamento é considerado parado se deveria estar ligado e não bate há mais de 20 min. */
    const val STALE_MS = 20 * 60_000L

    fun monitorRunning(enabled: Boolean, tickAt: Long, now: Long): Boolean =
        !enabled || (tickAt > 0 && now - tickAt <= STALE_MS)

    fun toJson(
        usageAccess: Boolean,
        overlay: Boolean,
        notifications: Boolean,
        admin: Boolean,
        monitorRunning: Boolean,
        checkedAt: Long,
    ): String =
        "{\"usageAccess\":$usageAccess,\"overlay\":$overlay,\"notifications\":$notifications," +
            "\"admin\":$admin,\"monitorRunning\":$monitorRunning,\"checkedAt\":$checkedAt}"
}

/**
 * Situação das proteções do Guardião: acesso ao uso, sobreposição, avisos,
 * administrador do dispositivo e serviço de acompanhamento.
 *
 * A leitura é gravada no arquivo de preferências do Flutter
 * (`FlutterSharedPreferences`, chave `flutter.guardiao_health`) porque a
 * tarefa periódica roda em um motor do Flutter sem os canais do aplicativo e
 * só enxerga o que está nas preferências.
 */
object HealthSnapshot {
    private const val FLUTTER_PREFS = "FlutterSharedPreferences"
    private const val FLUTTER_KEY = "flutter.guardiao_health"
    private const val PREFS = "guardiao_monitor"
    private const val KEY_TICK = "tick_at"

    fun adminComponent(context: Context) = ComponentName(context, GuardianAdminReceiver::class.java)

    fun isAdminActive(context: Context): Boolean {
        val dpm = context.getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager
        return dpm.isAdminActive(adminComponent(context))
    }

    fun notificationsEnabled(context: Context): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            context.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) !=
            PackageManager.PERMISSION_GRANTED
        ) {
            return false
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            return manager.areNotificationsEnabled()
        }
        return true
    }

    /** O serviço de acompanhamento marca aqui que continua vivo. */
    fun markTick(context: Context, now: Long = System.currentTimeMillis()) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().putLong(KEY_TICK, now).apply()
    }

    /**
     * Lê o estado atual, grava para a tarefa em segundo plano e devolve o JSON.
     * [adminOverride] serve ao receptor do administrador, que roda no instante
     * em que o sistema ainda pode responder "ativo".
     */
    fun write(context: Context, adminOverride: Boolean? = null): String {
        val now = System.currentTimeMillis()
        val tick = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getLong(KEY_TICK, 0L)
        val json = HealthMath.toJson(
            usageAccess = UsageReader.hasUsageAccess(context),
            overlay = Settings.canDrawOverlays(context),
            notifications = notificationsEnabled(context),
            admin = adminOverride ?: isAdminActive(context),
            monitorRunning = HealthMath.monitorRunning(MonitorConfig.isEnabled(context), tick, now),
            checkedAt = now,
        )
        context.getSharedPreferences(FLUTTER_PREFS, Context.MODE_PRIVATE)
            .edit().putString(FLUTTER_KEY, json).apply()
        return json
    }
}
