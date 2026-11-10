package br.edu.guardiaogamer.guardiao

import android.content.Context
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.provider.Settings
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.view.WindowManager
import android.widget.Button
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView

/** Atalho de app liberado mostrado em "Enquanto isso, que tal...". */
data class Suggestion(val pkg: String, val label: String, val hint: String)

/** O que a tela de bloqueio mostra. */
data class BlockInfo(
    val key: String,
    val pkg: String,
    val title: String,
    val message: String,
    val mission: String?,
    val suggestions: List<Suggestion>,
)

/**
 * Tela cheia de bloqueio desenhada por cima do aplicativo (design "Guardian":
 * título, contagem até liberar, missão para ganhar tempo e sugestões).
 */
class BlockOverlay(
    private val context: Context,
    private val onGoHome: () -> Unit,
    private val onOpenCredits: () -> Unit,
    private val onOpenApp: (String) -> Unit,
) {
    private val windows = context.getSystemService(Context.WINDOW_SERVICE) as WindowManager
    private var view: View? = null
    private var shownFor: String? = null
    private var hoursView: TextView? = null
    private var minutesView: TextView? = null
    private var secondsView: TextView? = null

    private val density = context.resources.displayMetrics.density
    private fun dp(v: Int) = (v * density).toInt()

    fun canShow(): Boolean = Settings.canDrawOverlays(context)

    private fun rounded(color: Int, radiusDp: Int, strokeColor: Int? = null): GradientDrawable =
        GradientDrawable().apply {
            setColor(color)
            cornerRadius = dp(radiusDp).toFloat()
            if (strokeColor != null) setStroke(dp(2), strokeColor)
        }

    private fun text(
        value: String,
        sizeSp: Float,
        color: Int,
        bold: Boolean = false,
        gravity: Int = Gravity.CENTER,
    ) = TextView(context).apply {
        text = value
        textSize = sizeSp
        setTextColor(color)
        this.gravity = gravity
        if (bold) typeface = Typeface.DEFAULT_BOLD
    }

    private fun button(label: String, bg: Int, fg: Int, onClick: () -> Unit) = Button(context).apply {
        text = label
        isAllCaps = false
        setTextColor(fg)
        typeface = Typeface.DEFAULT_BOLD
        textSize = 16f
        background = rounded(bg, 16)
        stateListAnimator = null
        setOnClickListener { onClick() }
        layoutParams = LinearLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT, dp(54),
        ).apply { topMargin = dp(12) }
    }

    private fun timeBox(label: String): Pair<LinearLayout, TextView> {
        val value = text("00", 26f, Color.parseColor("#2B59FF"), bold = true)
        val caption = text(label, 11f, Color.parseColor("#64748B"))
        val box = LinearLayout(context).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            background = rounded(Color.WHITE, 14)
            setPadding(dp(14), dp(8), dp(14), dp(8))
            minimumWidth = dp(66)
            addView(value)
            addView(caption)
            layoutParams = LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.WRAP_CONTENT,
            ).apply { marginStart = dp(4); marginEnd = dp(4) }
        }
        return box to value
    }

    fun show(info: BlockInfo, secondsLeft: Long) {
        if (!canShow()) return
        if (view != null && shownFor == info.key) {
            updateCountdown(secondsLeft)
            return
        }
        hide()
        val ink = Color.parseColor("#0F172A")
        val muted = Color.parseColor("#64748B")
        val orange = Color.parseColor("#FF7A1A")
        val blue = Color.parseColor("#2B59FF")

        val column = LinearLayout(context).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER_HORIZONTAL
            setPadding(dp(24), dp(48), dp(24), dp(24))
        }
        column.addView(text("Guardian", 15f, muted, bold = true))

        val icon = ImageView(context).apply {
            try {
                setImageDrawable(context.packageManager.getApplicationIcon(info.pkg))
            } catch (_: Exception) {
            }
            layoutParams = LinearLayout.LayoutParams(dp(76), dp(76)).apply {
                topMargin = dp(16); bottomMargin = dp(12)
            }
        }
        column.addView(icon)
        column.addView(text(info.title, 24f, ink, bold = true))
        column.addView(
            text(info.message, 15f, muted).apply { setPadding(dp(8), dp(8), dp(8), dp(16)) },
        )

        column.addView(text("LIBERA DE NOVO EM", 12f, muted, bold = true))
        val (hBox, h) = timeBox("horas")
        val (mBox, m) = timeBox("min")
        val (sBox, s) = timeBox("seg")
        hoursView = h; minutesView = m; secondsView = s
        column.addView(
            LinearLayout(context).apply {
                orientation = LinearLayout.HORIZONTAL
                gravity = Gravity.CENTER
                setPadding(0, dp(8), 0, dp(16))
                addView(hBox); addView(mBox); addView(sBox)
            },
        )
        updateCountdown(secondsLeft)

        if (info.mission != null) {
            val card = LinearLayout(context).apply {
                orientation = LinearLayout.VERTICAL
                background = rounded(Color.WHITE, 20, Color.parseColor("#FFD2B0"))
                setPadding(dp(16), dp(14), dp(16), dp(16))
                addView(text("MISSÃO PARA GANHAR MAIS TEMPO", 12f, Color.parseColor("#D95F00"), bold = true, gravity = Gravity.START))
                addView(text(info.mission, 17f, ink, bold = true, gravity = Gravity.START).apply { setPadding(0, dp(8), 0, dp(4)) })
                addView(button("Fiz a tarefa!", orange, Color.WHITE) { onOpenCredits() })
            }
            column.addView(card)
        }

        if (info.suggestions.isNotEmpty()) {
            column.addView(
                text("Enquanto isso, que tal...", 15f, ink, bold = true, gravity = Gravity.START)
                    .apply { setPadding(0, dp(20), 0, dp(8)) },
            )
            for (sug in info.suggestions) {
                val row = LinearLayout(context).apply {
                    orientation = LinearLayout.HORIZONTAL
                    gravity = Gravity.CENTER_VERTICAL
                    background = rounded(Color.WHITE, 16)
                    setPadding(dp(12), dp(10), dp(12), dp(10))
                    layoutParams = LinearLayout.LayoutParams(
                        ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT,
                    ).apply { bottomMargin = dp(8) }
                }
                val appIcon = ImageView(context).apply {
                    try {
                        setImageDrawable(context.packageManager.getApplicationIcon(sug.pkg))
                    } catch (_: Exception) {
                    }
                    layoutParams = LinearLayout.LayoutParams(dp(40), dp(40)).apply { marginEnd = dp(12) }
                }
                val labels = LinearLayout(context).apply {
                    orientation = LinearLayout.VERTICAL
                    layoutParams = LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f)
                    addView(text(sug.label, 15f, ink, bold = true, gravity = Gravity.START))
                    addView(text(sug.hint, 12.5f, muted, gravity = Gravity.START))
                }
                val open = text("Abrir", 13f, Color.parseColor("#027A48"), bold = true).apply {
                    background = rounded(Color.parseColor("#DDF5E8"), 12)
                    setPadding(dp(14), dp(7), dp(14), dp(7))
                    setOnClickListener { onOpenApp(sug.pkg) }
                }
                row.addView(appIcon); row.addView(labels); row.addView(open)
                column.addView(row)
            }
        }

        column.addView(button("Voltar ao início", blue, Color.WHITE) { onGoHome() })
        column.addView(
            text("Pedir mais tempo ao responsável", 14f, muted, bold = true).apply {
                setPadding(0, dp(16), 0, dp(8))
                setOnClickListener { onOpenCredits() }
            },
        )

        val scroll = ScrollView(context).apply {
            background = GradientDrawable(
                GradientDrawable.Orientation.TOP_BOTTOM,
                intArrayOf(Color.parseColor("#DCE4F5"), Color.parseColor("#F7F8FA")),
            )
            isFillViewport = true
            addView(column)
        }
        val params = WindowManager.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            ViewGroup.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
            WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
            PixelFormat.TRANSLUCENT,
        )
        try {
            windows.addView(scroll, params)
            view = scroll
            shownFor = info.key
        } catch (_: Exception) {
            view = null
            shownFor = null
        }
    }

    /** Atualiza a contagem regressiva sem redesenhar a tela. */
    fun updateCountdown(secondsLeft: Long) {
        val total = if (secondsLeft < 0) 0 else secondsLeft
        hoursView?.text = "%02d".format(total / 3600)
        minutesView?.text = "%02d".format((total % 3600) / 60)
        secondsView?.text = "%02d".format(total % 60)
    }

    fun hide() {
        val v = view ?: return
        try {
            windows.removeView(v)
        } catch (_: Exception) {
        }
        view = null
        shownFor = null
        hoursView = null; minutesView = null; secondsView = null
    }
}
