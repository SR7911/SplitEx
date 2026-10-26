package com.splitex.`in`.app

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.res.Configuration
import android.widget.RemoteViews
import android.view.View
import android.os.Bundle
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

class ExpensesWidget : AppWidgetProvider() {
    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        if (intent.action == Intent.ACTION_CONFIGURATION_CHANGED) refresh(context)
    }
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        ids.forEach { render(context, manager, it) }
    }
    override fun onAppWidgetOptionsChanged(context: Context, manager: AppWidgetManager, id: Int, options: Bundle) {
        render(context, manager, id)
    }
    companion object {
        const val CHANNEL = "com.splitex.in.app/expenses_widget"
        fun refresh(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            manager.getAppWidgetIds(ComponentName(context, ExpensesWidget::class.java)).forEach { render(context, manager, it) }
        }
        private fun render(context: Context, manager: AppWidgetManager, id: Int) {
            val prefs = context.getSharedPreferences("expenses_widget", Context.MODE_PRIVATE)
            val nothing = prefs.getString("widgetStyle", "nothing") == "nothing"
            val views = RemoteViews(context.packageName, if (nothing) R.layout.expenses_widget_nothing else R.layout.expenses_widget)
            val valid = prefs.getInt("schemaVersion", 0) == 2 &&
                prefs.getString("monthKey", "") == SimpleDateFormat("yyyy-MM", Locale.US).format(Date())
            val state = prefs.getString("state", "loading")
            val hideAmounts = prefs.getInt("widgetHideAmounts", 0) == 1
            fun money(key: String): String? {
                if (!valid) return "—"
                if (hideAmounts) return "••••"
                val amount = prefs.getString(key, "—") ?: "—"
                return if (prefs.getInt("widgetDecimals", 1) == 1) amount else prefs.getString("${key}Whole", amount.substringBeforeLast('.'))
            }
            views.setTextViewText(R.id.widget_month, SimpleDateFormat("MMM yyyy", Locale.getDefault()).format(Date()))
            views.setTextViewText(R.id.widget_spent, money("spent"))
            views.setTextViewText(R.id.widget_income, money("income"))
            views.setTextViewText(R.id.widget_balance, money("balance"))
            val overspent = valid && prefs.getInt("overIncome", 0) == 1
            views.setTextViewText(R.id.widget_balance_label, if (!valid || hideAmounts) "Your monthly balance" else if (overspent) "Overspent by" else "Remaining balance")
            views.setTextColor(R.id.widget_balance, 0xFFFFFFFF.toInt())
            views.setViewVisibility(R.id.widget_details, if (valid) View.VISIBLE else View.GONE)
            views.setViewVisibility(R.id.widget_progress, if (valid && !hideAmounts && prefs.getInt("widgetProgress", 1) == 1 && prefs.getInt("hasIncome", 0) == 1) View.VISIBLE else View.GONE)
            views.setTextViewText(R.id.widget_budget, when {
                state == "signedOut" -> "Sign in to see your expenses"
                state == "error" -> "Couldn't refresh · Tap to retry in app"
                valid && hideAmounts -> "Amounts hidden"
                valid && prefs.getInt("widgetProgress", 1) == 0 -> "Income minus expenses"
                valid -> prefs.getString("budget", "")
                else -> "Open SplitEx to load this month"
            })
            views.setProgressBar(R.id.widget_progress, 100, if (valid) prefs.getInt("progress", 0) else 0, false)
            // Render the rounded gradient as a bitmap; RemoteViews cannot set a GradientDrawable.
            val dark = when (prefs.getString("themeMode", "system")) {
                "dark", "deepDark" -> true
                "light" -> false
                else -> context.resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK == Configuration.UI_MODE_NIGHT_YES
            }
            val key = (if (overspent) "negative" else "positive") + (if (dark) "Dark" else "Light")
            val fallback = if (overspent) {
                if (dark) intArrayOf(0xFF7F1D1D.toInt(), 0xFF831843.toInt())
                else intArrayOf(0xFFDC2626.toInt(), 0xFFDB2777.toInt())
            } else {
                if (dark) intArrayOf(0xFF064E3B.toInt(), 0xFF065F46.toInt())
                else intArrayOf(0xFF059669.toInt(), 0xFF0D9488.toInt())
            }
            val start = prefs.getInt("${key}Start", fallback[0])
            val end = prefs.getInt("${key}End", fallback[1])
            val options = manager.getAppWidgetOptions(id)
            val width = (options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 300).coerceAtLeast(250) * 2).coerceAtMost(1200)
            val height = (options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, 150).coerceAtLeast(150) * 2).coerceAtMost(800)
            val bitmap = android.graphics.Bitmap.createBitmap(width, height, android.graphics.Bitmap.Config.ARGB_8888)
            val paint = android.graphics.Paint(android.graphics.Paint.ANTI_ALIAS_FLAG)
            val appearance = NothingWidgetAppearance(context)
            if (appearance.enabled) paint.color = appearance.background
            else paint.shader = android.graphics.LinearGradient(0f, 0f, width.toFloat(), height.toFloat(), start, end, android.graphics.Shader.TileMode.CLAMP)
            val canvas = android.graphics.Canvas(bitmap)
            val clip = android.graphics.Path().apply {
                addRoundRect(0f, 0f, width.toFloat(), height.toFloat(), 56f, 56f, android.graphics.Path.Direction.CW)
            }
            canvas.clipPath(clip)
            canvas.drawPaint(paint)
            paint.shader = null
            if (appearance.enabled && appearance.dots) {
                paint.color = if (appearance.dark) 0xFF303030.toInt() else 0xFFDADADA.toInt()
                var x = width * .7f
                while (x < width) {
                    var y = 0f
                    while (y < height) { canvas.drawCircle(x, y, 1.2f, paint); y += 16 }
                    x += 16
                }
            } else if (!appearance.enabled) {
                paint.color = 0x0CFFFFFF
                canvas.drawCircle(width * .92f, height * .05f, height * .65f, paint)
                paint.color = 0x0DFFFFFF
                canvas.drawCircle(width * .02f, height * .95f, height * .4f, paint)
            }
            views.setOnClickPendingIntent(R.id.widget_root, launch(context, "transactions"))
            views.setOnClickPendingIntent(R.id.widget_budget, launch(context, "transactions"))
            views.setOnClickPendingIntent(R.id.widget_add, launch(context, "add"))
            val landscape = context.resources.configuration.orientation == Configuration.ORIENTATION_LANDSCAPE
            val renderWidth = options.getInt(
                if (landscape) AppWidgetManager.OPTION_APPWIDGET_MAX_WIDTH else AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH,
                300,
            ).coerceIn(250, 600)
            val renderHeight = options.getInt(
                if (landscape) AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT else AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT,
                160,
            ).coerceIn(160, 400)
            views.setImageViewBitmap(R.id.widget_rendered, WidgetFontRenderer.render(context, views, renderWidth, renderHeight, bitmap))
            // Transmit one composed bitmap, rather than a second background copy.
            views.setViewVisibility(R.id.widget_background, View.INVISIBLE)
            manager.updateAppWidget(id, views)
        }
        private fun launch(context: Context, action: String): PendingIntent {
            val intent = Intent(context, MainActivity::class.java).apply {
                putExtra("expenses_widget_action", action)
                flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
                this.action = "com.splitex.widget.$action"
            }
            return PendingIntent.getActivity(context, action.hashCode(), intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        }
    }
}

