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
    /** "Sempre liberado": ignora o bloqueio geral e as rotinas. */
    val allowed: Boolean = false,
    /** games, videos, social, study ou other. */
    val category: String = "other",
)

/** Horário recorrente com uma regra especial (veja `Routine` no Dart). */
data class RoutineRule(
    val name: String,
    val startMinute: Int,
    val endMinute: Int,
    /** 1 = segunda ... 7 = domingo. */
    val days: Set<Int>,
    /** pause_all, study_only ou games_only. */
    val mode: String,
    val enabled: Boolean,
)

/** Tudo que o serviço precisa para decidir, guardado no aparelho. */
data class MonitorPlan(
    val apps: List<MonitoredApp>,
    val lockAll: Boolean = false,
    val routines: List<RoutineRule> = emptyList(),
    /** Dia (aaaa-mm-dd) a que vale [bonusMinutes], somado aos limites. */
    val bonusDay: String? = null,
    val bonusMinutes: Int = 0,
    /** Texto da tela de bloqueio escolhido pelo responsável. */
    val message: String = "",
)

/**
 * Guarda as regras no próprio aparelho para o serviço continuar bloqueando
 * mesmo com o app fechado ou sem internet.
 */
object MonitorConfig {
    private const val PREFS = "guardiao_monitor"
    private const val KEY_APPS = "apps"
    private const val KEY_ENABLED = "enabled"
    private const val KEY_TAB = "launch_tab"

    /** Aceita o formato antigo (só a lista de apps) e o novo (objeto). */
    fun parse(json: String): MonitorPlan {
        val trimmed = json.trim()
        if (trimmed.startsWith("[")) return MonitorPlan(parseApps(JSONArray(trimmed)))
        val root = JSONObject(trimmed)
        val routines = ArrayList<RoutineRule>()
        val rawRoutines = root.optJSONArray("routines") ?: JSONArray()
        for (i in 0 until rawRoutines.length()) {
            val o = rawRoutines.optJSONObject(i) ?: continue
            val days = HashSet<Int>()
            val rawDays = o.optJSONArray("days") ?: JSONArray()
            for (d in 0 until rawDays.length()) days.add(rawDays.optInt(d))
            routines.add(
                RoutineRule(
                    name = o.optString("name", ""),
                    startMinute = o.optInt("start", 0),
                    endMinute = o.optInt("end", 0),
                    days = if (days.isEmpty()) setOf(1, 2, 3, 4, 5, 6, 7) else days,
                    mode = o.optString("mode", "pause_all"),
                    enabled = o.optBoolean("enabled", true),
                ),
            )
        }
        return MonitorPlan(
            apps = parseApps(root.optJSONArray("apps") ?: JSONArray()),
            lockAll = root.optBoolean("lockAll", false),
            routines = routines,
            bonusDay = if (root.isNull("bonusDay")) null else root.optString("bonusDay"),
            bonusMinutes = root.optInt("bonusMinutes", 0),
            message = root.optString("message", ""),
        )
    }

    private fun parseApps(array: JSONArray): List<MonitoredApp> {
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
                    allowed = o.optBoolean("allowed", false),
                    category = o.optString("cat", "other"),
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

    fun load(context: Context): MonitorPlan {
        val json = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .getString(KEY_APPS, null) ?: return MonitorPlan(emptyList())
        return try {
            parse(json)
        } catch (_: Exception) {
            MonitorPlan(emptyList())
        }
    }

    /** A tela de bloqueio pediu uma aba do app ("credits"); vale uma vez. */
    fun requestTab(context: Context, tab: String) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
            .putString(KEY_TAB, tab).apply()
    }

    fun takeTab(context: Context): String? {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val tab = prefs.getString(KEY_TAB, null)
        if (tab != null) prefs.edit().remove(KEY_TAB).apply()
        return tab
    }
}
