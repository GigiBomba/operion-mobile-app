package com.operion.operion_mobile

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

/**
 * Phase 5A — "Next stop / active trip" home-screen widget (driver role).
 *
 * Same home_widget data-push contract as [OperionWidgetProvider]; reads the
 * `next_stop` and `active_trip` keys written by the app-side
 * `WidgetDataService` for the driver role.
 */
class OperionDriverWidgetProvider : HomeWidgetProvider() {

  override fun onUpdate(
    context: Context,
    appWidgetManager: AppWidgetManager,
    appWidgetIds: IntArray,
    widgetData: SharedPreferences,
  ) {
    appWidgetIds.forEach { widgetId ->
      val views =
          RemoteViews(context.packageName, R.layout.operion_driver_widget_layout).apply {
            val pendingIntent =
                HomeWidgetLaunchIntent.getActivity(
                    context, MainActivity::class.java)
            setOnClickPendingIntent(R.id.widget_root, pendingIntent)

            setTextViewText(
                R.id.widget_active_trip,
                widgetData.getString("active_trip", null)
                    ?: context.getString(R.string.widget_no_active_trip))
            setTextViewText(
                R.id.widget_next_stop,
                widgetData.getString("next_stop", null)
                    ?: context.getString(R.string.widget_value_unavailable))
          }

      appWidgetManager.updateAppWidget(widgetId, views)
    }
  }
}
