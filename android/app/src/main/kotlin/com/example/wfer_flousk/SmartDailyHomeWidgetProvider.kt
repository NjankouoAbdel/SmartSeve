package com.example.wfer_flousk

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

class SmartDailyHomeWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.smart_daily_widget)

            views.setTextViewText(
                R.id.widget_account,
                widgetData.getString("widget_account", "Main Wallet")
            )
            views.setTextViewText(
                R.id.widget_balance,
                widgetData.getString("widget_balance", "--")
            )
            views.setTextViewText(
                R.id.widget_spending,
                widgetData.getString("widget_spending", "--")
            )
            views.setTextViewText(
                R.id.widget_updated,
                widgetData.getString("widget_updated", "--:--")
            )

            val openIntent = HomeWidgetLaunchIntent.getActivity(
                context,
                MainActivity::class.java,
                Uri.parse("wferflousk://quick?action=open")
            )
            val expenseIntent = HomeWidgetLaunchIntent.getActivity(
                context,
                MainActivity::class.java,
                Uri.parse("wferflousk://quick?action=expense")
            )
            val incomeIntent = HomeWidgetLaunchIntent.getActivity(
                context,
                MainActivity::class.java,
                Uri.parse("wferflousk://quick?action=income")
            )
            val transferIntent = HomeWidgetLaunchIntent.getActivity(
                context,
                MainActivity::class.java,
                Uri.parse("wferflousk://quick?action=transfer")
            )
            views.setOnClickPendingIntent(R.id.widget_root, openIntent)
            views.setOnClickPendingIntent(R.id.widget_action_expense, expenseIntent)
            views.setOnClickPendingIntent(R.id.widget_action_income, incomeIntent)
            views.setOnClickPendingIntent(R.id.widget_action_transfer, transferIntent)

            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
