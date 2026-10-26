package com.splitex.`in`.app

import android.content.Context
import android.content.res.Configuration
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Typeface
import android.view.View
import android.view.ViewGroup
import android.widget.FrameLayout
import android.widget.ImageView
import android.widget.RemoteViews
import android.widget.TextView
import androidx.core.content.res.ResourcesCompat

/**
 * Launcher RemoteViews may inflate TextViews in a restricted context, which
 * prevents bundled fonts from loading. Apply the actual typefaces locally and
 * send the finished appearance as an image; keep native views for interaction
 * and accessibility underneath the non-interactive image.
 */
internal object WidgetFontRenderer {
    fun render(context: Context, views: RemoteViews, widthDp: Int, heightDp: Int, background: Bitmap): Bitmap {
        // Bound bitmap memory while preserving dp/sp layout and font scaling.
        val scale = context.resources.displayMetrics.density.coerceAtMost(2f)
        val configuration = Configuration(context.resources.configuration).apply {
            densityDpi = (160 * scale).toInt()
        }
        val renderContext = context.createConfigurationContext(configuration)
        val local = views.apply(renderContext, FrameLayout(renderContext))
        local.findViewById<ImageView>(R.id.widget_background).setImageBitmap(background)
        val regular = requireNotNull(ResourcesCompat.getFont(context, R.font.gilmer_regular))
        val medium = requireNotNull(ResourcesCompat.getFont(context, R.font.gilmer_medium))
        val bold = requireNotNull(ResourcesCompat.getFont(context, R.font.gilmer_bold))
        val heavy = requireNotNull(ResourcesCompat.getFont(context, R.font.gilmer_heavy))

        fun applyFonts(view: View) {
            if (view is TextView) {
                val font = when {
                    view.id == R.id.widget_balance -> heavy
                    view.id == R.id.widget_balance_label || view.id == R.id.widget_month -> medium
                    view.typeface?.isBold == true -> bold
                    else -> regular
                }
                view.setTypeface(font, Typeface.NORMAL)
                view.paint.isFakeBoldText = false
            }
            if (view is ViewGroup) {
                for (index in 0 until view.childCount) applyFonts(view.getChildAt(index))
            }
        }
        applyFonts(local)
        val appearance = NothingWidgetAppearance(renderContext)
        appearance.apply(local)
        val width = (widthDp * scale).toInt().coerceAtLeast(1)
        val height = (heightDp * scale).toInt().coerceAtLeast(1)
        local.measure(
            View.MeasureSpec.makeMeasureSpec(width, View.MeasureSpec.EXACTLY),
            View.MeasureSpec.makeMeasureSpec(height, View.MeasureSpec.EXACTLY),
        )
        local.layout(0, 0, width, height)
        return Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888).also {
            val canvas = Canvas(it)
            local.draw(canvas)
            appearance.drawHeading(local, canvas)
        }
    }
}
