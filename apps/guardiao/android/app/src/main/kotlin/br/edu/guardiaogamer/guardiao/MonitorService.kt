package br.edu.guardiaogamer.guardiao

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper

/**
 * Serviço em primeiro plano que, a cada poucos segundos, vê qual aplicativo
 * está na tela e cobre com [BlockOverlay] quando o limite acabou ou o
 * responsável bloqueou. As regras vêm de [MonitorConfig], então continua
 * valendo sem internet e com o app fechado.
 */
class MonitorService : Service() {
    private val main = Handler(Looper.getMainLooper())
    private lateinit var overlay: BlockOverlay
    private var running = false

    private val tick = object : Runnable {
        override fun run() {
            if (!running) return
            try {
                check()
            } catch (_: Exception) {
                // Uma leitura ruim não pode derrubar o serviço.
            }
            main.postDelayed(this, INTERVAL_MS)
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        overlay = BlockOverlay(this) { goHome() }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (!UsageReader.hasUsageAccess(this) || !MonitorConfig.isEnabled(this)) {
            stopSelf()
            return START_NOT_STICKY
        }
        startInForeground()
        if (!running) {
            running = true
            main.post(tick)
        }
        return START_STICKY
    }

    private fun check() {
        val apps = MonitorConfig.load(this)
        if (apps.isEmpty()) {
            overlay.hide()
            return
        }
        val usage = UsageReader.today(this)
        val foreground = usage.foreground
        val rule = apps.firstOrNull { it.pkg == foreground }
        if (foreground == null || foreground == packageName || rule == null) {
            overlay.hide()
            return
        }
        val used = usage.minutes(rule.pkg)
        if (UsageMath.shouldBlock(rule.blocked, rule.limitMinutes, used)) {
            val message = if (rule.blocked) {
                "O responsável bloqueou este aplicativo."
            } else {
                "O tempo de hoje acabou. Amanhã você joga de novo."
            }
            overlay.show(rule.name, message)
            goHome()
        } else {
            overlay.hide()
        }
    }

    private fun goHome() {
        val home = Intent(Intent.ACTION_MAIN)
            .addCategory(Intent.CATEGORY_HOME)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        try {
            startActivity(home)
        } catch (_: Exception) {
        }
    }

    private fun startInForeground() {
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            manager.createNotificationChannel(
                NotificationChannel(CHANNEL, "Tempo de jogo", NotificationManager.IMPORTANCE_LOW),
            )
        }
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }
        val notification = builder
            .setContentTitle("Guardião")
            .setContentText("Acompanhando o tempo de jogo deste aparelho.")
            .setSmallIcon(applicationInfo.icon)
            .setOngoing(true)
            .build()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE)
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }

    override fun onDestroy() {
        running = false
        main.removeCallbacks(tick)
        overlay.hide()
        super.onDestroy()
    }

    companion object {
        private const val CHANNEL = "guardiao_monitor"
        private const val NOTIFICATION_ID = 7101
        private const val INTERVAL_MS = 3_000L

        fun start(context: Context) {
            val intent = Intent(context, MonitorService::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        fun stop(context: Context) {
            context.stopService(Intent(context, MonitorService::class.java))
        }
    }
}
