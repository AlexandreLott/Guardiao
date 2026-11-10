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
import java.util.Calendar

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
    private var ticks = 0

    private val tick = object : Runnable {
        override fun run() {
            if (!running) return
            try {
                check()
            } catch (_: Exception) {
                // Uma leitura ruim não pode derrubar o serviço.
            }
            // A cada ~30 s: prova de vida do serviço e leitura das proteções,
            // que a tarefa em segundo plano envia ao responsável.
            if (ticks++ % HEALTH_EVERY_TICKS == 0) {
                try {
                    HealthSnapshot.markTick(this@MonitorService)
                    HealthSnapshot.write(this@MonitorService)
                } catch (_: Exception) {
                }
            }
            main.postDelayed(this, INTERVAL_MS)
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        overlay = BlockOverlay(
            this,
            onGoHome = { goHome() },
            onOpenCredits = { openCredits() },
            onOpenApp = { pkg -> openApp(pkg) },
        )
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        // Continua ligado mesmo sem o acesso ao uso: retirá-lo é justamente uma
        // tentativa de burla que precisa ser percebida e informada.
        if (!MonitorConfig.isEnabled(this)) {
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
        val plan = MonitorConfig.load(this)
        if (plan.apps.isEmpty()) {
            overlay.hide()
            return
        }
        val usage = UsageReader.today(this)
        val foreground = usage.foreground
        val rule = plan.apps.firstOrNull { it.pkg == foreground }
        if (foreground == null || foreground == packageName || rule == null || isEssential(foreground)) {
            overlay.hide()
            lastSentHome = null
            return
        }
        val now = Calendar.getInstance()
        val weekday = ((now.get(Calendar.DAY_OF_WEEK) + 5) % 7) + 1 // 1 = segunda
        val minute = now.get(Calendar.HOUR_OF_DAY) * 60 + now.get(Calendar.MINUTE)
        val today = "%04d-%02d-%02d".format(
            now.get(Calendar.YEAR), now.get(Calendar.MONTH) + 1, now.get(Calendar.DAY_OF_MONTH),
        )
        val used = usage.minutes(rule.pkg)
        val result = PolicyMath.evaluate(rule, used, plan, weekday, minute, today)
        if (result.verdict == PolicyMath.Verdict.ALLOW) {
            overlay.hide()
            lastSentHome = null
            return
        }
        val title: String
        val message: String
        when (result.verdict) {
            PolicyMath.Verdict.BLOCKED -> {
                title = "${rule.name} está bloqueado"
                message = "O responsável bloqueou este aplicativo."
            }
            PolicyMath.Verdict.PAUSED -> {
                title = "${rule.name} está em pausa"
                message = "Agora é hora de: ${result.reason}. Daqui a pouco libera."
            }
            else -> {
                title = "${rule.name} descansa por hoje"
                message = "Você usou todo o tempo combinado com a sua família para este jogo hoje. Amanhã tem mais!"
            }
        }
        val mission = plan.message.ifBlank { null }
        val suggestions = plan.apps
            .filter { it.pkg != rule.pkg && it.pkg != packageName && (it.allowed || it.category == "study") }
            .filter { it.blocked.not() }
            .take(3)
            .map { Suggestion(it.pkg, it.name, if (it.category == "study") "Estudo e música" else "Sempre liberado") }
        val midnight = Calendar.getInstance().apply {
            add(Calendar.DAY_OF_MONTH, 1)
            set(Calendar.HOUR_OF_DAY, 0); set(Calendar.MINUTE, 0); set(Calendar.SECOND, 0); set(Calendar.MILLISECOND, 0)
        }
        val secondsLeft = (midnight.timeInMillis - now.timeInMillis) / 1000
        overlay.show(
            BlockInfo("${rule.pkg}|${result.verdict}|${result.reason}", rule.pkg, title, message, mission, suggestions),
            secondsLeft,
        )
        goHomeOnce(rule.pkg)
    }

    private var lastSentHome: String? = null

    /** Manda para a tela inicial só na primeira vez, para a tela de bloqueio poder ser lida. */
    private fun goHomeOnce(pkg: String) {
        if (lastSentHome == pkg) return
        lastSentHome = pkg
        goHome()
    }

    /** Telefone e emergência nunca são cobertos. */
    private fun isEssential(pkg: String): Boolean =
        pkg.contains("dialer") || pkg.contains("incallui") || pkg.contains("emergency") ||
            pkg.contains("telecom")

    private fun openCredits() {
        MonitorConfig.requestTab(this, "credits")
        overlay.hide()
        val launch = packageManager.getLaunchIntentForPackage(packageName) ?: return
        launch.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_REORDER_TO_FRONT)
        try {
            startActivity(launch)
        } catch (_: Exception) {
        }
    }

    private fun openApp(pkg: String) {
        val launch = packageManager.getLaunchIntentForPackage(pkg) ?: return
        launch.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        overlay.hide()
        try {
            startActivity(launch)
        } catch (_: Exception) {
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
            .setContentTitle("Guardian")
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
        private const val HEALTH_EVERY_TICKS = 10

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
