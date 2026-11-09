package br.edu.guardiaogamer.guardiao

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.provider.Settings
import android.content.pm.ResolveInfo
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Ponte entre o Flutter e o Android.
 *
 * - `listInstalledApps`: aplicativos com ícone de lançamento (os mesmos que
 *   aparecem no menu do celular). Usa a declaração `<queries>` do manifesto,
 *   então não precisa da permissão ampla QUERY_ALL_PACKAGES.
 * - `deviceName`: fabricante e modelo, como "samsung SM-A155M".
 * - canal `monitor`: tempo de uso e bloqueio, veja [MonitorService].
 */
class MainActivity : FlutterActivity() {
    private var notificationResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        configureMonitor(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "listInstalledApps" -> listInstalledApps(result)
                    "deviceName" -> result.success(deviceName())
                    else -> result.notImplemented()
                }
            }
    }

    // ------------------------------------------------------- tempo de uso

    private fun configureMonitor(flutterEngine: FlutterEngine) {
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, MONITOR)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "permissions" -> result.success(monitorPermissions())
                    "openUsageAccessSettings" -> {
                        openSettings(Settings.ACTION_USAGE_ACCESS_SETTINGS, withPackage = false)
                        result.success(null)
                    }
                    "openOverlaySettings" -> {
                        openSettings(Settings.ACTION_MANAGE_OVERLAY_PERMISSION, withPackage = true)
                        result.success(null)
                    }
                    "requestNotifications" -> requestNotifications(result)
                    "start" -> {
                        val json = call.argument<String>("apps")
                        if (json == null) {
                            result.error("BAD_ARGS", "apps é obrigatório", null)
                        } else {
                            startMonitoring(json, result)
                        }
                    }
                    "stop" -> {
                        MonitorConfig.setEnabled(this, false)
                        MonitorService.stop(this)
                        result.success(null)
                    }
                    "usageToday" -> usageToday(result)
                    else -> result.notImplemented()
                }
            }
    }

    private fun monitorPermissions(): Map<String, Boolean> = mapOf(
        "usageAccess" to UsageReader.hasUsageAccess(this),
        "overlay" to Settings.canDrawOverlays(this),
        "notifications" to (
            Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU ||
                checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) ==
                PackageManager.PERMISSION_GRANTED
            ),
    )

    private fun openSettings(action: String, withPackage: Boolean) {
        val intent = Intent(action)
        if (withPackage) intent.data = Uri.parse("package:$packageName")
        startActivity(intent)
    }

    private fun requestNotifications(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU ||
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) ==
            PackageManager.PERMISSION_GRANTED
        ) {
            result.success(true)
            return
        }
        if (notificationResult != null) {
            result.error("BUSY", "Já existe um pedido de permissão em andamento.", null)
            return
        }
        notificationResult = result
        requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), REQUEST_NOTIFICATIONS)
    }

    /** Guarda as regras e liga o serviço (se o acesso ao uso já foi liberado). */
    private fun startMonitoring(json: String, result: MethodChannel.Result) {
        try {
            MonitorConfig.parse(json) // recusa JSON quebrado antes de gravar
        } catch (e: Exception) {
            result.error("BAD_ARGS", "Regras inválidas: ${e.message}", null)
            return
        }
        MonitorConfig.save(this, json, enabled = true)
        if (UsageReader.hasUsageAccess(this)) {
            try {
                MonitorService.start(this)
            } catch (e: Exception) {
                result.error("START_FAILED", e.message, null)
                return
            }
        }
        result.success(null)
    }

    private fun usageToday(result: MethodChannel.Result) {
        if (!UsageReader.hasUsageAccess(this)) {
            result.success(emptyMap<String, Int>())
            return
        }
        try {
            val usage = UsageReader.today(this)
            result.success(usage.millisByPackage.mapValues { (it.value / 60_000L).toInt() })
        } catch (e: Exception) {
            result.error("USAGE_FAILED", e.message, null)
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != REQUEST_NOTIFICATIONS) return
        val pending = notificationResult ?: return
        notificationResult = null
        pending.success(
            grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED,
        )
    }

    // --------------------------------------------------------- apps e nome

    private fun listInstalledApps(result: MethodChannel.Result) {
        // A consulta pode demorar com muitos apps; sai da thread principal.
        Thread {
            try {
                val apps = queryLauncherApps()
                runOnUiThread { result.success(apps) }
            } catch (e: Exception) {
                runOnUiThread { result.error("LIST_FAILED", e.message, null) }
            }
        }.start()
    }

    private fun queryLauncherApps(): List<Map<String, String>> {
        val pm = packageManager
        val intent = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER)
        val resolved: List<ResolveInfo> =
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                pm.queryIntentActivities(intent, PackageManager.ResolveInfoFlags.of(0))
            } else {
                @Suppress("DEPRECATION")
                pm.queryIntentActivities(intent, 0)
            }
        return resolved
            .map { mapOf(
                "packageName" to it.activityInfo.packageName,
                "name" to it.loadLabel(pm).toString(),
            ) }
            .distinctBy { it["packageName"] }
            .sortedBy { it["name"]?.lowercase() }
    }

    private fun deviceName(): String {
        val maker = Build.MANUFACTURER.orEmpty().trim()
        val model = Build.MODEL.orEmpty().trim()
        return if (model.startsWith(maker, ignoreCase = true)) model else "$maker $model".trim()
    }

    companion object {
        const val CHANNEL = "br.edu.guardiaogamer/device"
        const val MONITOR = "br.edu.guardiaogamer/monitor"
        const val REQUEST_NOTIFICATIONS = 4712
    }
}
