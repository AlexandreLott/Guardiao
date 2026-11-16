package br.edu.guardiaogamer.guardiao

import android.animation.ValueAnimator
import android.content.Context
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.ColorFilter
import android.graphics.ColorMatrix
import android.graphics.ColorMatrixColorFilter
import android.graphics.Outline
import android.graphics.Paint
import android.graphics.PixelFormat
import android.graphics.RectF
import android.graphics.Typeface
import android.graphics.drawable.Drawable
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.view.ViewOutlineProvider
import android.view.WindowManager
import android.view.animation.DecelerateInterpolator
import android.view.animation.OvershootInterpolator
import android.widget.FrameLayout
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView

/**
 * Sugestão mostrada em "Enquanto isso, que tal...". Com [pkg], é um app
 * liberado e ganha o botão Abrir; sem [pkg], é uma ideia para fazer fora do
 * celular.
 */
data class Suggestion(val pkg: String, val label: String, val hint: String)

/** O que a tela de bloqueio mostra. */
data class BlockInfo(
    val key: String,
    val pkg: String,
    val title: String,
    val message: String,
    val mission: String?,
    val suggestions: List<Suggestion>,
    /** Minutos de crédito que a criança tem para usar. */
    val credits: Int = 0,
    /** Falso quando não há hora para liberar (app bloqueado pelo responsável). */
    val showClock: Boolean = true,
)

/** Cadeado desenhado à mão; [lift] levanta a haste (1 = aberto, 0 = trancado). */
private class LockDrawable(private val color: Int) : Drawable() {
    var lift = 0f
        set(value) {
            field = value
            invalidateSelf()
        }
    private val fill = Paint(Paint.ANTI_ALIAS_FLAG).apply { style = Paint.Style.FILL }
    private val stroke = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.STROKE
        strokeCap = Paint.Cap.ROUND
    }

    override fun draw(canvas: Canvas) {
        val b = bounds
        val u = b.width() / 24f
        fill.color = color
        stroke.color = color
        stroke.strokeWidth = 2.4f * u
        val dy = -5f * u * lift
        canvas.save()
        canvas.rotate(-18f * lift, b.left + 16f * u, b.top + 11f * u)
        // haste: sobe e gira quando o cadeado está aberto
        canvas.drawArc(
            RectF(b.left + 8f * u, b.top + 4f * u + dy, b.left + 16f * u, b.top + 12f * u + dy),
            180f, 180f, false, stroke,
        )
        canvas.drawLine(b.left + 8f * u, b.top + 8f * u + dy, b.left + 8f * u, b.top + 11f * u, stroke)
        canvas.drawLine(b.left + 16f * u, b.top + 8f * u + dy, b.left + 16f * u, b.top + 11f * u + dy, stroke)
        canvas.restore()
        canvas.drawRoundRect(
            RectF(b.left + 5f * u, b.top + 11f * u, b.left + 19f * u, b.top + 21f * u),
            2.5f * u, 2.5f * u, fill,
        )
    }

    override fun setAlpha(alpha: Int) {}
    override fun setColorFilter(filter: ColorFilter?) {}

    @Deprecated("Deprecated in Java")
    override fun getOpacity(): Int = PixelFormat.TRANSLUCENT
}

/**
 * Tela cheia de bloqueio desenhada por cima do aplicativo, no desenho do
 * Guardian: cadeado que tranca na entrada, contagem até liberar, missão para
 * ganhar tempo, créditos e sugestões. Fica na tela até a criança tocar em um
 * dos botões.
 */
class BlockOverlay(
    private val context: Context,
    private val onGoHome: () -> Unit,
    private val onOpenCredits: () -> Unit,
    private val onOpenApp: (String) -> Unit,
) {
    private val windows = context.getSystemService(Context.WINDOW_SERVICE) as WindowManager
    private val main = Handler(Looper.getMainLooper())
    private var view: View? = null
    private var shownFor: String? = null
    private var hoursView: TextView? = null
    private var minutesView: TextView? = null
    private var secondsView: TextView? = null
    private var endAt = 0L

    private val density = context.resources.displayMetrics.density
    private fun dp(v: Int) = (v * density).toInt()

    private val ink = Color.parseColor("#0F172A")
    private val muted = Color.parseColor("#64748B")
    private val orange = Color.parseColor("#FF7A1A")
    private val blue = Color.parseColor("#2B59FF")

    /** Lexend, a fonte do app (embutida nos arquivos do Flutter). */
    private val lexend: Typeface? = try {
        Typeface.createFromAsset(context.assets, "flutter_assets/assets/fonts/Lexend.ttf")
    } catch (_: Exception) {
        null
    }

    private fun face(bold: Boolean): Typeface {
        val base = lexend ?: return if (bold) Typeface.DEFAULT_BOLD else Typeface.DEFAULT
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            Typeface.create(base, if (bold) 700 else 400, false)
        } else {
            Typeface.create(base, if (bold) Typeface.BOLD else Typeface.NORMAL)
        }
    }

    /** A contagem anda a cada segundo, sem depender do serviço. */
    private val everySecond = object : Runnable {
        override fun run() {
            if (view == null) return
            updateCountdown((endAt - System.currentTimeMillis()) / 1000)
            main.postDelayed(this, 1000)
        }
    }

    val isShowing: Boolean get() = view != null

    fun canShow(): Boolean = Settings.canDrawOverlays(context)

    private fun rounded(color: Int, radiusDp: Int, strokeColor: Int? = null): GradientDrawable =
        GradientDrawable().apply {
            setColor(color)
            cornerRadius = dp(radiusDp).toFloat()
            if (strokeColor != null) setStroke(dp(2), strokeColor)
        }

    private fun circle(color: Int, strokeColor: Int? = null, strokeDp: Int = 0): GradientDrawable =
        GradientDrawable().apply {
            shape = GradientDrawable.OVAL
            setColor(color)
            if (strokeColor != null) setStroke(dp(strokeDp), strokeColor)
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
        typeface = face(bold)
    }

    /** Botão em forma de pílula; encolhe um pouco enquanto o dedo está nele. */
    private fun button(label: String, bg: Int, fg: Int, onClick: () -> Unit) =
        text(label, 16f, fg, bold = true).apply {
            background = rounded(bg, 27)
            isClickable = true
            setOnClickListener { onClick() }
            setOnTouchListener { v, e ->
                when (e.actionMasked) {
                    android.view.MotionEvent.ACTION_DOWN ->
                        v.animate().scaleX(0.96f).scaleY(0.96f).setDuration(90).start()
                    android.view.MotionEvent.ACTION_UP, android.view.MotionEvent.ACTION_CANCEL ->
                        v.animate().scaleX(1f).scaleY(1f).setDuration(220).start()
                }
                false
            }
            layoutParams = LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, dp(54),
            ).apply { topMargin = dp(12) }
        }

    private fun appIcon(pkg: String, sizeDp: Int, radiusDp: Int, gray: Boolean = false) =
        ImageView(context).apply {
            try {
                setImageDrawable(context.packageManager.getApplicationIcon(pkg))
            } catch (_: Exception) {
            }
            if (gray) {
                colorFilter = ColorMatrixColorFilter(ColorMatrix().apply { setSaturation(0.35f) })
                alpha = 0.9f
            }
            val r = dp(radiusDp).toFloat()
            outlineProvider = object : ViewOutlineProvider() {
                override fun getOutline(v: View, outline: Outline) {
                    outline.setRoundRect(0, 0, v.width, v.height, r)
                }
            }
            clipToOutline = true
            layoutParams = LinearLayout.LayoutParams(dp(sizeDp), dp(sizeDp))
        }

    private fun timeBox(label: String): Pair<LinearLayout, TextView> {
        val value = text("00", 26f, blue, bold = true)
        val caption = text(label, 11f, muted)
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
        endAt = System.currentTimeMillis() + secondsLeft * 1000
        if (view != null && shownFor == info.key) {
            updateCountdown(secondsLeft)
            return
        }
        hide()

        val column = LinearLayout(context).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER_HORIZONTAL
            setPadding(dp(24), dp(44), dp(24), dp(24))
        }

        // topo: logo e nome
        column.addView(
            LinearLayout(context).apply {
                orientation = LinearLayout.HORIZONTAL
                gravity = Gravity.CENTER
                addView(
                    ImageView(context).apply {
                        try {
                            setImageDrawable(context.packageManager.getApplicationIcon(context.packageName))
                        } catch (_: Exception) {
                        }
                        layoutParams = LinearLayout.LayoutParams(dp(24), dp(24)).apply { marginEnd = dp(8) }
                    },
                )
                addView(text("Guardian", 15f, ink, bold = true).apply { alpha = 0.75f })
            },
        )

        // ícone do app, sem cor, com o cadeado azul no canto
        val badge = FrameLayout(context).apply {
            layoutParams = LinearLayout.LayoutParams(dp(92), dp(92)).apply {
                topMargin = dp(18); bottomMargin = dp(12)
            }
            addView(
                appIcon(info.pkg, 76, 24, gray = true).apply {
                    layoutParams = FrameLayout.LayoutParams(dp(76), dp(76), Gravity.TOP or Gravity.START)
                },
            )
            addView(
                ImageView(context).apply {
                    background = circle(blue, Color.parseColor("#F3F6FB"), 4)
                    setImageDrawable(LockDrawable(Color.WHITE))
                    setPadding(dp(11), dp(10), dp(11), dp(11))
                    layoutParams = FrameLayout.LayoutParams(dp(40), dp(40), Gravity.BOTTOM or Gravity.END)
                },
            )
        }
        column.addView(badge)
        column.addView(text(info.title, 23f, ink, bold = true))
        column.addView(
            text(info.message, 15f, muted).apply { setPadding(dp(8), dp(8), dp(8), dp(16)) },
        )

        if (info.showClock) {
            column.addView(text("LIBERA DE NOVO EM", 12f, muted, bold = true).apply { letterSpacing = 0.06f })
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
        }

        // o cartão da missão aparece sempre: é por ele que se ganha tempo
        run {
            val card = LinearLayout(context).apply {
                orientation = LinearLayout.VERTICAL
                background = rounded(Color.WHITE, 22, Color.parseColor("#FFD2B0"))
                setPadding(dp(16), dp(14), dp(16), dp(14))
            }
            val mission = info.mission ?: "Faça uma missão da família e ganhe tempo extra!"
            run {
                card.addView(
                    text("MISSÃO PARA GANHAR MAIS TEMPO", 12f, Color.parseColor("#D95F00"), bold = true, gravity = Gravity.START)
                        .apply { letterSpacing = 0.05f },
                )
                card.addView(
                    LinearLayout(context).apply {
                        orientation = LinearLayout.HORIZONTAL
                        gravity = Gravity.CENTER_VERTICAL
                        setPadding(0, dp(10), 0, dp(2))
                        addView(
                            text("★", 20f, orange, bold = true).apply {
                                background = rounded(Color.parseColor("#FFEBDC"), 14)
                                layoutParams = LinearLayout.LayoutParams(dp(46), dp(46)).apply { marginEnd = dp(12) }
                            },
                        )
                        addView(
                            text(mission, 16.5f, ink, bold = true, gravity = Gravity.START).apply {
                                layoutParams = LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f)
                            },
                        )
                    },
                )
                card.addView(
                    button(if (info.mission != null) "Fiz a tarefa!" else "Ver as missões", orange, Color.WHITE) {
                        onOpenCredits()
                    },
                )
            }
            // linha dos créditos
            card.addView(
                LinearLayout(context).apply {
                    orientation = LinearLayout.HORIZONTAL
                    gravity = Gravity.CENTER_VERTICAL
                    setPadding(0, dp(14), 0, 0)
                    addView(
                        text("☆  Seus créditos: ", 14f, muted, gravity = Gravity.START),
                    )
                    addView(
                        text(minutesLabel(info.credits), 14f, ink, bold = true, gravity = Gravity.START).apply {
                            layoutParams = LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f)
                        },
                    )
                    addView(
                        text("Usar crédito", 13.5f, blue, bold = true).apply {
                            background = rounded(Color.parseColor("#E8EDFF"), 18)
                            setPadding(dp(16), dp(9), dp(16), dp(9))
                            alpha = if (info.credits > 0) 1f else 0.5f
                            setOnClickListener { onOpenCredits() }
                        },
                    )
                },
            )
            column.addView(card)
        }

        if (info.suggestions.isNotEmpty()) {
            column.addView(
                text("Enquanto isso, que tal...", 15f, ink, bold = true, gravity = Gravity.START).apply {
                    setPadding(dp(2), dp(20), 0, dp(8))
                    layoutParams = LinearLayout.LayoutParams(
                        ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT,
                    )
                },
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
                val icon: View = if (sug.pkg.isNotEmpty()) {
                    appIcon(sug.pkg, 40, 12).apply {
                        (layoutParams as LinearLayout.LayoutParams).marginEnd = dp(12)
                    }
                } else {
                    text("★", 18f, Color.parseColor("#027A48"), bold = true).apply {
                        background = rounded(Color.parseColor("#DDF5E8"), 12)
                        layoutParams = LinearLayout.LayoutParams(dp(40), dp(40)).apply { marginEnd = dp(12) }
                    }
                }
                val labels = LinearLayout(context).apply {
                    orientation = LinearLayout.VERTICAL
                    layoutParams = LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f)
                    addView(text(sug.label, 15f, ink, bold = true, gravity = Gravity.START))
                    addView(text(sug.hint, 12.5f, muted, gravity = Gravity.START))
                }
                val open = text("Abrir", 13f, Color.parseColor("#027A48"), bold = true).apply {
                    background = rounded(Color.parseColor("#DDF5E8"), 14)
                    setPadding(dp(14), dp(7), dp(14), dp(7))
                    setOnClickListener { onOpenApp(sug.pkg) }
                }
                row.addView(icon); row.addView(labels)
                if (sug.pkg.isNotEmpty()) row.addView(open)
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
            isFillViewport = true
            addView(column)
        }

        // o momento do bloqueio: um cadeado grande no centro, que tranca
        val bigLock = LockDrawable(Color.WHITE).apply { lift = 1f }
        val lockView = ImageView(context).apply {
            background = circle(blue)
            setImageDrawable(bigLock)
            setPadding(dp(24), dp(22), dp(24), dp(24))
            scaleX = 0f; scaleY = 0f
            layoutParams = FrameLayout.LayoutParams(dp(96), dp(96), Gravity.CENTER)
        }
        val root = FrameLayout(context).apply {
            background = GradientDrawable(
                GradientDrawable.Orientation.TOP_BOTTOM,
                intArrayOf(Color.parseColor("#DCE4F5"), Color.parseColor("#F7F8FA")),
            )
            addView(scroll)
            addView(lockView)
            alpha = 0f
        }

        val params = WindowManager.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            ViewGroup.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
            WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
            PixelFormat.TRANSLUCENT,
        )
        try {
            windows.addView(root, params)
            view = root
            shownFor = info.key
        } catch (_: Exception) {
            view = null
            shownFor = null
            return
        }
        main.removeCallbacks(everySecond)
        main.postDelayed(everySecond, 1000)
        playEntrance(root, column, lockView, bigLock)
    }

    /**
     * Entrada: o fundo aparece, o cadeado surge no centro, a haste encaixa, o
     * cadeado sobe e some, e o conteúdo entra peça por peça.
     */
    private fun playEntrance(root: View, column: LinearLayout, lockView: View, lock: LockDrawable) {
        for (i in 0 until column.childCount) column.getChildAt(i).alpha = 0f
        root.animate().alpha(1f).setDuration(320).start()
        lockView.animate().scaleX(1f).scaleY(1f).setStartDelay(260).setDuration(520)
            .setInterpolator(OvershootInterpolator(2.2f)).start()
        main.postDelayed({
            ValueAnimator.ofFloat(1f, 0f).apply {
                duration = 240
                interpolator = OvershootInterpolator(3f)
                addUpdateListener { lock.lift = it.animatedValue as Float }
                start()
            }
            lockView.animate().scaleX(0.9f).scaleY(0.9f).setStartDelay(0).setDuration(110)
                .setInterpolator(DecelerateInterpolator())
                .withEndAction {
                    lockView.animate().scaleX(1f).scaleY(1f).setDuration(200).start()
                }.start()
        }, 1150)
        main.postDelayed({
            lockView.animate().translationY(-dp(240).toFloat()).scaleX(0.4f).scaleY(0.4f).alpha(0f)
                .setStartDelay(0).setDuration(460).setInterpolator(DecelerateInterpolator(1.4f))
                .withEndAction { lockView.visibility = View.GONE }.start()
            for (i in 0 until column.childCount) {
                column.getChildAt(i).apply {
                    translationY = dp(22).toFloat()
                    animate().alpha(1f).translationY(0f).setStartDelay(80L + i * 60L).setDuration(520)
                        .setInterpolator(DecelerateInterpolator(1.8f)).start()
                }
            }
        }, 1750)
    }

    private fun minutesLabel(minutes: Int): String {
        val h = minutes / 60
        val m = minutes % 60
        return when {
            minutes <= 0 -> "0 min"
            h == 0 -> "$m min"
            m == 0 -> "$h h"
            else -> "$h h $m min"
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
        main.removeCallbacksAndMessages(null)
        view = null
        shownFor = null
        hoursView = null; minutesView = null; secondsView = null
        // some com um esmaecer curto
        v.animate().alpha(0f).setDuration(180).withEndAction {
            try {
                windows.removeView(v)
            } catch (_: Exception) {
            }
        }.start()
    }
}
