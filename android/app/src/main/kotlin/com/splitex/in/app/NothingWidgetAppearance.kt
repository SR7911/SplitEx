package com.splitex.`in`.app

import android.content.Context
import android.content.res.ColorStateList
import android.content.res.Configuration
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.drawable.GradientDrawable
import android.view.View
import android.view.ViewGroup
import android.widget.ProgressBar
import android.widget.TextView

internal class NothingWidgetAppearance(context: Context) {
    private val prefs = context.getSharedPreferences("expenses_widget", Context.MODE_PRIVATE)
    val enabled = prefs.getString("widgetStyle", "nothing") == "nothing"
    val dark = when (prefs.getString("widgetTone", "dark")) {
        "dark" -> true
        "light" -> false
        else -> context.resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK == Configuration.UI_MODE_NIGHT_YES
    }
    val dots = prefs.getInt("widgetDots", 1) == 1
    private val red = prefs.getInt("widgetRedAccent", 1) == 1
    val background = if (dark) 0xFF101010.toInt() else 0xFFF5F5F5.toInt()
    private val foreground = if (dark) Color.WHITE else 0xFF141414.toInt()
    private val muted = if (dark) 0xFFE0E0E0.toInt() else 0xFF333333.toInt()
    private val accent = if (red) 0xFFCC2222.toInt() else foreground

    private val labels = mutableListOf<Pair<TextView, Int>>()
    fun apply(root: View) {
        if (!enabled) return
        val density = root.resources.displayMetrics.density
        fun recolor(view: View) {
            if (view is TextView) {
                view.setTextColor(if (view.id in intArrayOf(R.id.widget_balance, R.id.widget_income, R.id.widget_spent, R.id.widget_title)) foreground else muted)
            }
            if (view is ViewGroup) for (i in 0 until view.childCount) recolor(view.getChildAt(i))
        }
        recolor(root)
        for (id in intArrayOf(R.id.widget_income_card, R.id.widget_spent_card)) {
            root.findViewById<View>(id).background = null
        }
        root.findViewById<TextView>(R.id.widget_add).apply {
            text = "+"
            setTextColor(if (red || !dark) Color.WHITE else Color.BLACK)
            background = GradientDrawable().apply { shape = GradientDrawable.OVAL; setColor(accent) }
            layoutParams = layoutParams.apply { width = (36 * density).toInt(); height = (36 * density).toInt() }
        }
        if (prefs.getInt("overIncome", 0) == 1 && prefs.getInt("widgetHideAmounts", 0) == 0) {
            root.findViewById<TextView>(R.id.widget_balance).setTextColor(accent)
        }
        root.findViewById<ProgressBar>(R.id.widget_progress).apply {
            progressTintList = ColorStateList.valueOf(accent)
            progressBackgroundTintList = ColorStateList.valueOf(if (dark) 0xFF333333.toInt() else 0xFFD5D5D5.toInt())
        }

        capture(root)
        root.findViewById<ProgressBar>(R.id.widget_progress).alpha = 0f
    }

    private fun capture(view: View) {
        if (view.visibility != View.VISIBLE) return
        if (view is TextView) {
            labels.add(view to view.currentTextColor)
            view.setTextColor(Color.TRANSPARENT)
        }
        if (view is ViewGroup) for (i in 0 until view.childCount) capture(view.getChildAt(i))
    }

    fun drawHeading(root: View, canvas: Canvas) {
        if (!enabled) return
        fun origin(view: View): Pair<Float, Float> {
            var x = view.left.toFloat()
            var y = view.top.toFloat()
            var parent = view.parent
            while (parent is View && parent !== root) {
                x += parent.left
                y += parent.top
                parent = parent.parent
            }
            return x to y
        }
        val paint = Paint(Paint.ANTI_ALIAS_FLAG)
        for ((view, color) in labels) {
            val text = view.text.toString().uppercase(java.util.Locale.ROOT)
            if (text.isEmpty()) continue
            val (left, top) = origin(view)
            val availableWidth = (view.width - view.paddingLeft - view.paddingRight).coerceAtLeast(1)
            val availableHeight = (view.height - view.paddingTop - view.paddingBottom).coerceAtLeast(1)
            val step = minOf(view.textSize / 7f, availableWidth / (text.length * 6f - 1), availableHeight / 7f)
            val textWidth = (text.length * 6 - 1) * step
            val alignment = view.gravity and android.view.Gravity.HORIZONTAL_GRAVITY_MASK
            val x = left + view.paddingLeft + when (alignment) {
                android.view.Gravity.RIGHT -> availableWidth - textWidth
                android.view.Gravity.CENTER_HORIZONTAL -> (availableWidth - textWidth) / 2
                else -> 0f
            }
            val y = top + view.paddingTop + (availableHeight - step * 7) / 2
            paint.color = color
            text.forEachIndexed { index, letter ->
                val glyph = DotMatrixGlyphs.glyphs[letter] ?: DotMatrixGlyphs.glyphs.getValue('?')
                for (row in 0..6) for (col in 0..4) {
                    // Larger dots add weight without closing the matrix gaps.
                    if (glyph[row * 5 + col] == '1') canvas.drawCircle(x + (index * 6 + col + .5f) * step, y + (row + .5f) * step, step * .45f, paint)
                }
            }
        }
        val progress = root.findViewById<ProgressBar>(R.id.widget_progress)
        if (progress.visibility == View.VISIBLE) {
            val (left, top) = origin(progress)
            val columns = (progress.width / (4 * root.resources.displayMetrics.density)).toInt().coerceAtLeast(1)
            val step = progress.width.toFloat() / columns
            val radius = minOf(step * .29f, progress.height / 6f)
            for (col in 0 until columns) {
                paint.color = if ((col + .5f) / columns <= progress.progress / 100f) accent else if (dark) 0xFF505050.toInt() else 0xFFB8B8B8.toInt()
                for (row in 0..1) canvas.drawCircle(left + (col + .5f) * step, top + progress.height * (row + 1) / 3f, radius, paint)
            }
        }
    }
}



