package br.edu.guardiaogamer.guardiao

import android.Manifest
import android.app.admin.DevicePolicyManager
import android.content.Intent
import androidx.core.content.FileProvider
import java.io.File
import android.content.pm.PackageManager
import android.net.Uri
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.Drawable
import android.provider.Settings
import android.util.Base64
import java.io.ByteArrayOutputStream
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
        configureUpdates(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "listInstalledApps" ->
                        listInstalledApps(result, call.argument<Boolean>("icons") ?: true)
                    "deviceName" -> result.success(deviceName())
                    else -> result.notImplemented()
                }
            }
    }

    // ------------------------------------------------- atualização do app

    private fun configureUpdates(flutterEngine: FlutterEngine) {
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, UPDATE)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "version" -> result.success(versionInfo())
                    "updateDir" -> {
                        val dir = File(cacheDir, "updates")
                        dir.mkdirs()
                        // Apaga APKs de atualizações anteriores.
                        dir.listFiles()?.forEach { it.delete() }
                        result.success(dir.absolutePath)
                    }
                    "canInstall" -> result.success(canInstallPackages())
                    "openInstallSettings" -> {
                        openSettings(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES, withPackage = true)
                        result.success(null)
                    }
                    "install" -> installApk(call.argument<String>("path"), result)
                    else -> result.notImplemented()
                }
            }
    }

    private fun versionInfo(): Map<String, Any?> {
        val info = packageManager.getPackageInfo(packageName, 0)
        val code = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            info.longVersionCode
        } else {
            @Suppress("DEPRECATION")
            info.versionCode.toLong()
        }
        return mapOf("versionCode" to code, "versionName" to (info.versionName ?: ""))
    }

    private fun canInstallPackages(): Boolean =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.O || packageManager.canRequestPackageInstalls()

    /** Abre o instalador do sistema com um APK da pasta de atualizações. */
    private fun installApk(path: String?, result: MethodChannel.Result) {
        if (path == null) {
            result.error("BAD_ARGS", "path é obrigatório", null)
            return
        }
        try {
            val dir = File(cacheDir, "updates").canonicalFile
            val file = File(path).canonicalFile
            if (file.parentFile != dir || !file.isFile) {
                result.error("BAD_FILE", "Arquivo fora da pasta de atualizações.", null)
                return
            }
            val uri = FileProvider.getUriForFile(this, "$packageName.fileprovider", file)
            val intent = Intent(Intent.ACTION_VIEW)
                .setDataAndType(uri, "application/vnd.android.package-archive")
                .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_ACTIVITY_NEW_TASK)
            startActivity(intent)
            result.success(null)
        } catch (e: Exception) {
            result.error("INSTALL_FAILED", e.message, null)
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
                    "takeLaunchTab" -> result.success(MonitorConfig.takeTab(this))
                    "health" -> result.success(HealthSnapshot.write(this))
                    "adminActive" -> result.success(HealthSnapshot.isAdminActive(this))
                    "requestAdmin" -> {
                        requestAdmin()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    /** Abre a tela do sistema que pede para ativar o administrador do dispositivo. */
    private fun requestAdmin() {
        val intent = Intent(DevicePolicyManager.ACTION_ADD_DEVICE_ADMIN)
            .putExtra(DevicePolicyManager.EXTRA_DEVICE_ADMIN, HealthSnapshot.adminComponent(this))
            .putExtra(
                DevicePolicyManager.EXTRA_ADD_EXPLANATION,
                "Impede que o Guardião seja desinstalado sem avisar o responsável.",
            )
        startActivity(intent)
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

    private fun listInstalledApps(result: MethodChannel.Result, withIcons: Boolean) {
        // A consulta pode demorar com muitos apps; sai da thread principal.
        // Captura Throwable (não só Exception) para nunca deixar o Flutter
        // esperando uma resposta que não vem.
        Thread {
            try {
                val apps = queryLauncherApps(withIcons)
                runOnUiThread { result.success(apps) }
            } catch (e: Throwable) {
                runOnUiThread { result.error("LIST_FAILED", e.toString(), null) }
            }
        }.start()
    }

    private fun queryLauncherApps(withIcons: Boolean): List<Map<String, String>> {
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
            .map {
                val map = mutableMapOf(
                    "packageName" to it.activityInfo.packageName,
                    "name" to it.loadLabel(pm).toString(),
                )
                if (withIcons) iconBase64(it, pm)?.let { icon -> map["icon"] = icon }
                map
            }
            .distinctBy { it["packageName"] }
            .sortedBy { it["name"]?.lowercase() }
    }

    /**
     * Ícone do app em 96x96, WebP com perda, em base64 (uns 2 a 4 KB). Serve
     * para o responsável ver o mesmo ícone do menu do celular do filho. Se algo
     * falhar, devolve `null` e o responsável vê a letra inicial.
     */
    private fun iconBase64(info: ResolveInfo, pm: PackageManager): String? {
        return try {
            val drawable: Drawable = info.loadIcon(pm)
            val bitmap = Bitmap.createBitmap(ICON_SIZE, ICON_SIZE, Bitmap.Config.ARGB_8888)
            val canvas = Canvas(bitmap)
            drawable.setBounds(0, 0, ICON_SIZE, ICON_SIZE)
            drawable.draw(canvas)
            val out = ByteArrayOutputStream()
            val format = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                Bitmap.CompressFormat.WEBP_LOSSY
            } else {
                @Suppress("DEPRECATION")
                Bitmap.CompressFormat.WEBP
            }
            bitmap.compress(format, 80, out)
            bitmap.recycle()
            val text = Base64.encodeToString(out.toByteArray(), Base64.NO_WRAP)
            if (text.length > 30_000) null else text
        } catch (_: Throwable) {
            null
        }
    }

    private fun deviceName(): String {
        val maker = Build.MANUFACTURER.orEmpty().trim()
        val model = Build.MODEL.orEmpty().trim()
        return if (model.startsWith(maker, ignoreCase = true)) model else "$maker $model".trim()
    }

    companion object {
        const val CHANNEL = "br.edu.guardiaogamer/device"
        const val MONITOR = "br.edu.guardiaogamer/monitor"
        const val UPDATE = "br.edu.guardiaogamer/update"
        const val REQUEST_NOTIFICATIONS = 4712
        private const val ICON_SIZE = 96
    }
}
