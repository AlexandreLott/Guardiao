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
import android.provider.Settings
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel
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

    /** Motor do Flutter sem telas que mantém as regras em dia com a nuvem. */
    private var syncEngine: FlutterEngine? = null
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
            onGoHome = { dismiss(); goHome() },
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
        startSyncEngine()
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
        if (foreground == null || isGuardian(foreground) || rule == null || isEssential(foreground)) {
            // Depois do bloqueio o celular vai para a tela inicial, e o que
            // fica na frente é o launcher. A tela de bloqueio continua ali até
            // a criança tocar em um botão; antes ela sumia em três segundos.
            if (overlay.isShowing && (foreground == null || foreground == homePackage() || foreground == "com.android.systemui")) {
                return
            }
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
        val suggestions = suggestionsFor(plan, rule.pkg, result.verdict)
        val midnight = Calendar.getInstance().apply {
            add(Calendar.DAY_OF_MONTH, 1)
            set(Calendar.HOUR_OF_DAY, 0); set(Calendar.MINUTE, 0); set(Calendar.SECOND, 0); set(Calendar.MILLISECOND, 0)
        }
        val secondsLeft = (midnight.timeInMillis - now.timeInMillis) / 1000
        overlay.show(
            BlockInfo(
                "${rule.pkg}|${result.verdict}|${result.reason}", rule.pkg, title, message, mission, suggestions,
                plan.credits,
                showClock = result.verdict != PolicyMath.Verdict.BLOCKED,
            ),
            secondsLeft,
        )
        goHomeOnce(rule.pkg)
    }

    /**
     * Três sugestões para a tela de bloqueio: primeiro os apps que o
     * responsável deixou sempre liberados (ou de estudo); depois apps comuns
     * que estejam instalados e sem regra; e, para completar, ideias para
     * fazer fora do celular.
     */
    private fun suggestionsFor(plan: MonitorPlan, blockedPkg: String, verdict: PolicyMath.Verdict): List<Suggestion> {
        val out = ArrayList<Suggestion>()
        plan.apps
            .filter { it.pkg != blockedPkg && !isGuardian(it.pkg) && (it.allowed || it.category == "study") }
            .filter { it.blocked.not() }
            .take(3)
            .forEach { out.add(Suggestion(it.pkg, it.name, if (it.category == "study") "Estudo e música" else "Sempre liberado")) }
        // Em pausa (rotina ou bloqueio geral) só abre o que é sempre liberado.
        val everythingPaused = plan.lockAll || verdict == PolicyMath.Verdict.PAUSED
        if (!everythingPaused) {
            val ruled = plan.apps.map { it.pkg }.toSet()
            for ((pkg, label, hint) in COMMON_APPS) {
                if (out.size >= 3) break
                if (pkg == blockedPkg || pkg in ruled || out.any { it.pkg == pkg }) continue
                if (packageManager.getLaunchIntentForPackage(pkg) == null) continue
                out.add(Suggestion(pkg, label, hint))
            }
        }
        for ((label, hint) in OFFLINE_IDEAS) {
            if (out.size >= 3) break
            out.add(Suggestion("", label, hint))
        }
        return out
    }

    private var lastSentHome: String? = null

    /** Fecha a tela de bloqueio a pedido da criança. */
    private fun dismiss() {
        overlay.hide()
        lastSentHome = null
    }

    private var cachedHome: String? = null

    /** Pacote da tela inicial (launcher) deste aparelho. */
    private fun homePackage(): String? {
        cachedHome?.let { return it }
        val intent = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_HOME)
        val found = try {
            packageManager.resolveActivity(intent, 0)?.activityInfo?.packageName
        } catch (_: Exception) {
            null
        }
        cachedHome = found
        return found
    }

    /** Manda para a tela inicial só na primeira vez, para a tela de bloqueio poder ser lida. */
    private fun goHomeOnce(pkg: String) {
        if (lastSentHome == pkg) return
        lastSentHome = pkg
        goHome()
    }

    /**
     * O Guardian oficial e as variantes de teste (Mãe e Filho) nunca são
     * bloqueados: sem isso o bloqueio geral trancava o app do responsável
     * quando os dois estão no mesmo celular.
     */
    private fun isGuardian(pkg: String): Boolean =
        pkg == packageName || pkg.startsWith(GUARDIAN_PREFIX)

    /** Telefone e emergência nunca são cobertos. */
    private fun isEssential(pkg: String): Boolean =
        pkg.contains("dialer") || pkg.contains("incallui") || pkg.contains("emergency") ||
            pkg.contains("telecom")

    private fun openCredits() {
        MonitorConfig.requestTab(this, "credits")
        dismiss()
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
        dismiss()
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

    /**
     * Liga a sincronização sem tela. Antes, as mudanças do responsável só
     * chegavam ao bloqueio com a tela do app aberta; com o app fechado, ligar
     * o bloqueio geral não tinha efeito. Qualquer falha aqui é ignorada: o
     * bloqueio segue com as últimas regras guardadas.
     */
    private fun startSyncEngine() {
        if (syncEngine != null) return
        try {
            val loader = FlutterInjector.instance().flutterLoader()
            loader.startInitialization(applicationContext)
            loader.ensureInitializationComplete(applicationContext, null)
            val engine = FlutterEngine(applicationContext)
            MethodChannel(engine.dartExecutor.binaryMessenger, SYNC_CHANNEL)
                .setMethodCallHandler { call, result ->
                    when (call.method) {
                        "permissions" -> result.success(
                            mapOf(
                                "usageAccess" to UsageReader.hasUsageAccess(this),
                                "overlay" to Settings.canDrawOverlays(this),
                                "notifications" to true,
                            ),
                        )
                        "start" -> {
                            val json = call.argument<String>("apps")
                            try {
                                MonitorConfig.parse(json ?: "") // recusa JSON quebrado
                                MonitorConfig.save(this, json!!, enabled = true)
                                result.success(null)
                            } catch (e: Exception) {
                                result.error("BAD_ARGS", e.message, null)
                            }
                        }
                        "usageToday" -> try {
                            if (!UsageReader.hasUsageAccess(this)) {
                                result.success(emptyMap<String, Int>())
                            } else {
                                val usage = UsageReader.today(this)
                                result.success(usage.millisByPackage.mapValues { (it.value / 60_000L).toInt() })
                            }
                        } catch (e: Exception) {
                            result.error("USAGE_FAILED", e.message, null)
                        }
                        "adminActive" -> result.success(HealthSnapshot.isAdminActive(this))
                        else -> result.notImplemented()
                    }
                }
            engine.dartExecutor.executeDartEntrypoint(
                DartExecutor.DartEntrypoint(loader.findAppBundlePath(), "guardianHeadlessSync"),
            )
            syncEngine = engine
        } catch (_: Throwable) {
            syncEngine = null
        }
    }

    /** Se a criança tirar o app da lista de recentes, o serviço volta sozinho. */
    override fun onTaskRemoved(rootIntent: Intent?) {
        if (MonitorConfig.isEnabled(this)) {
            try {
                start(this)
            } catch (_: Exception) {
            }
        }
        super.onTaskRemoved(rootIntent)
    }

    override fun onDestroy() {
        running = false
        main.removeCallbacks(tick)
        overlay.hide()
        try {
            syncEngine?.destroy()
        } catch (_: Throwable) {
        }
        syncEngine = null
        super.onDestroy()
    }

    companion object {
        private const val CHANNEL = "guardiao_monitor"
        private const val NOTIFICATION_ID = 7101
        private const val INTERVAL_MS = 3_000L
        private const val HEALTH_EVERY_TICKS = 10
        private const val SYNC_CHANNEL = "br.edu.guardiaogamer/monitor"
        private const val GUARDIAN_PREFIX = "br.edu.guardiaogamer.guardiao"

        /** Apps comuns sugeridos quando estão instalados e sem regra. */
        private val COMMON_APPS = listOf(
            Triple("com.duolingo", "Estudar um pouco?", "Duolingo · lição de 5 min"),
            Triple("com.spotify.music", "Ouvir uma música?", "Spotify · sua playlist favorita"),
            Triple("com.whatsapp", "Mandar um oi pra família?", "WhatsApp"),
            Triple("com.google.android.apps.youtube.music", "Ouvir uma música?", "YouTube Music"),
            Triple("com.amazon.kindle", "Ler um livro?", "Kindle"),
            Triple("com.google.android.apps.photos", "Ver suas fotos?", "Google Fotos"),
        )

        /** Ideias para fora do celular, usadas para completar três sugestões. */
        private val OFFLINE_IDEAS = listOf(
            "Ler um livro ou gibi" to "Uns minutinhos já valem",
            "Brincar lá fora" to "Bola, bicicleta ou pega-pega",
            "Desenhar ou montar algo" to "Papel, lápis, blocos",
        )

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
