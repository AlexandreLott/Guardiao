package br.edu.guardiaogamer.guardiao_child

import android.content.Intent
import android.content.pm.PackageManager
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
 */
class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "listInstalledApps" -> listInstalledApps(result)
                    "deviceName" -> result.success(deviceName())
                    else -> result.notImplemented()
                }
            }
    }

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
    }
}
