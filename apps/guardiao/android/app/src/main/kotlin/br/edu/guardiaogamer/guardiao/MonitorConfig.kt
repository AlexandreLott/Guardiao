package br.edu.guardiaogamer.guardiao

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject

/** Regra de um aplicativo, como o Flutter manda. */
data class MonitoredApp(
    val pkg: String,
    val name: String,
    val limitMinutes: Int?,
    val blocked: Boolean,
)

/**
 * Guarda as regras no próprio aparelho para o serviço continuar bloqueando
 * mesmo com o app fechado ou sem internet.
 */
object MonitorConfig {
    private const val PREFS = "guardiao_monitor"
    private const val KEY_APPS = "apps"
    private const val KEY_ENABLED = "enabled"

    fun parse(json: String): List<MonitoredApp> {
        val array = JSONArray(json)
        val out = ArrayList<MonitoredApp>(array.length())
        for (i in 0 until array.length()) {
            val o: JSONObject = array.getJSONObject(i)
            val pkg = o.optString("pkg", "")
            if (pkg.isEmpty()) continue
            out.add(
                MonitoredApp(
                    pkg = pkg,
                    name = o.optString("name", pkg),
                    limitMinutes = if (o.isNull("limit")) null else o.optInt("limit"),
                    blocked = o.optBoolean("blocked", false),
                ),
            )
        }
        return out
    }

    fun save(context: Context, json: String, enabled: Boolean) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
            .putString(KEY_APPS, json)
            .putBoolean(KEY_ENABLED, enabled)
            .apply()
    }

    fun setEnabled(context: Context, enabled: Boolean) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
            .putBoolean(KEY_ENABLED, enabled)
            .apply()
    }

    fun isEnabled(context: Context): Boolean =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getBoolean(KEY_ENABLED, false)

    fun load(context: Context): List<MonitoredApp> {
        val json = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .getString(KEY_APPS, null) ?: return emptyList()
        return try {
            parse(json)
        } catch (_: Exception) {
            emptyList()
        }
    }
}
