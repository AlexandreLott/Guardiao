package br.edu.guardiaogamer.guardiao

import android.content.Context
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.Typeface
import android.provider.Settings
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.view.WindowManager
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView

/** Tela cheia "tempo esgotado" desenhada por cima do aplicativo bloqueado. */
class BlockOverlay(private val context: Context, private val onGoHome: () -> Unit) {
    private val windows = context.getSystemService(Context.WINDOW_SERVICE) as WindowManager
    private var view: View? = null
    private var shownFor: String? = null

    fun canShow(): Boolean = Settings.canDrawOverlays(context)

    fun show(appName: String, message: String) {
        if (!canShow()) return
        if (view != null && shownFor == appName) return
        hide()
        val density = context.resources.displayMetrics.density
        fun dp(v: Int) = (v * density).toInt()

        val title = TextView(context).apply {
            text = appName
            setTextColor(Color.WHITE)
            textSize = 22f
            typeface = Typeface.DEFAULT_BOLD
            gravity = Gravity.CENTER
        }
        val body = TextView(context).apply {
            text = message
            setTextColor(Color.parseColor("#D7DCE5"))
            textSize = 16f
            gravity = Gravity.CENTER
            setPadding(dp(32), dp(12), dp(32), dp(24))
        }
        val button = Button(context).apply {
            text = "Voltar ao início"
            setOnClickListener { onGoHome() }
        }
        val column = LinearLayout(context).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setBackgroundColor(Color.parseColor("#F2111827"))
            addView(title)
            addView(body)
            addView(button)
        }
        val params = WindowManager.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            ViewGroup.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
            WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE,
            PixelFormat.TRANSLUCENT,
        )
        try {
            windows.addView(column, params)
            view = column
            shownFor = appName
        } catch (_: Exception) {
            view = null
            shownFor = null
        }
    }

    fun hide() {
        val v = view ?: return
        try {
            windows.removeView(v)
        } catch (_: Exception) {
        }
        view = null
        shownFor = null
    }
}
