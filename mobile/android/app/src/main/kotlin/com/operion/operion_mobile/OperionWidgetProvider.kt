package com.operion.operion_mobile

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

/**
 * Phase 5A — "Today's KPIs" home-screen widget (dispatcher/manager role).
 *
 * Data is pushed from the Flutter side via
 * `HomeWidget.saveWidgetData(key, value)` + `HomeWidget.updateWidget(...)`
 * and read here from the home_widget shared preferences. Labels are
 * intentionally native-side fixed strings (no app-side l10n for widgets —
 * Phase 5A contract). The 15-minute refresh cadence is OS-clamped
 * (updatePeriodMillis) and the primary refresh path is the app-side push
 * (15-min Timer + push-triggered + after job/alert events).
 */
class OperionWidgetProvider : HomeWidgetProvider() {

  override fun onUpdate(
    context: Context,
    appWidgetManager: AppWidgetManager,
    appWidgetIds: IntArray,
    widgetData: SharedPreferences,
  ) {
    appWidgetIds.forEach { widgetId ->
      val views =
          RemoteViews(context.packageName, R.layout.operion_widget_layout).apply {
            // Tap the widget → open the app.
            val pendingIntent =
                HomeWidgetLaunchIntent.getActivity(
                    context, MainActivity::class.java)
            setOnClickPendingIntent(R.id.widget_root, pendingIntent)

            setTextViewText(
                R.id.widget_active_jobs,
                widgetData.getString("active_jobs", null)
                    ?: context.getString(R.string.widget_value_unavailable))
            setTextViewText(
                R.id.widget_open_alerts,
                widgetData.getString("open_alerts", null)
                    ?: context.getString(R.string.widget_value_unavailable))
            setTextViewText(
                R.id.widget_revenue,
                widgetData.getString("revenue_to_date", null)
                    ?: context.getString(R.string.widget_value_unavailable))
            setTextViewText(
                R.id.widget_updated,
                widgetData.getString("last_updated", null)
                    ?: context.getString(R.string.widget_not_updated))
          }

      appWidgetManager.updateAppWidget(widgetId, views)
    }
  }
}
