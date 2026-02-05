package com.example.vizora

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.BitmapDrawable
import android.os.Build
import android.os.Bundle
import android.util.Log
import android.widget.RemoteViews
import android.app.usage.UsageStatsManager
import android.content.pm.PackageManager

class UsageStatsWidget : AppWidgetProvider() {
    
    companion object {
        private const val TAG = "UsageStatsWidget"
        private const val ACTION_REFRESH = "com.example.vizora.REFRESH_WIDGET"
        private const val ACTION_OPEN_APP = "com.example.vizora.OPEN_APP"
        private const val MIN_USAGE_TIME = 180000L // 3 minutes - MUST match main app
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (appWidgetId in appWidgetIds) {
            updateAppWidget(context, appWidgetManager, appWidgetId)
        }
    }

    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: Bundle
    ) {
        Log.d(TAG, "Widget size changed")
        updateAppWidget(context, appWidgetManager, appWidgetId)
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        
        when (intent.action) {
            ACTION_REFRESH -> {
                Log.d(TAG, "Refresh button clicked")
                val appWidgetManager = AppWidgetManager.getInstance(context)
                val appWidgetIds = appWidgetManager.getAppWidgetIds(
                    android.content.ComponentName(context, UsageStatsWidget::class.java)
                )
                onUpdate(context, appWidgetManager, appWidgetIds)
            }
            ACTION_OPEN_APP -> {
                Log.d(TAG, "Widget clicked - opening app")
                val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)
                launchIntent?.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                context.startActivity(launchIntent)
            }
        }
    }

    private fun updateAppWidget(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int
    ) {
        try {
            // Determine widget size
            val options = appWidgetManager.getAppWidgetOptions(appWidgetId)
            val minWidth = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 0)
            val minHeight = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, 0)
            val maxWidth = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_WIDTH, 0)
            val maxHeight = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT, 0)
            
            Log.d(TAG, "Widget size - minW: $minWidth, minH: $minHeight, maxW: $maxWidth, maxH: $maxHeight")
            
            // Choose layout based on size
            val isSmall = minWidth < 150 && minHeight < 150
            val layoutId = if (isSmall) {
                Log.d(TAG, "Using small layout (1x1)")
                R.layout.usage_widget_small
            } else {
                Log.d(TAG, "Using large layout (2x2+)")
                R.layout.usage_widget
            }
            
            val views = RemoteViews(context.packageName, layoutId)
            
            // Get usage stats (with 3-minute filtering and ignored apps)
            val usageData = getUsageStats(context)
            
            Log.d(TAG, "Total time: ${formatTime(usageData.totalTime)}, Top apps: ${usageData.topApps.size}")
            
            // Update total time
            views.setTextViewText(R.id.total_time, formatTime(usageData.totalTime))
            
            // Update app list for large widgets
            if (!isSmall) {
                Log.d(TAG, "Updating app list for large widget")
                
                if (usageData.topApps.isNotEmpty()) {
                    Log.d(TAG, "App 1: ${usageData.topApps[0].name}")
                    updateAppItem(context, views, usageData.topApps[0], 1)
                    views.setInt(R.id.app1_container, "setVisibility", android.view.View.VISIBLE)
                } else {
                    Log.d(TAG, "No app 1")
                    views.setInt(R.id.app1_container, "setVisibility", android.view.View.GONE)
                }
                
                if (usageData.topApps.size > 1) {
                    Log.d(TAG, "App 2: ${usageData.topApps[1].name}")
                    updateAppItem(context, views, usageData.topApps[1], 2)
                    views.setInt(R.id.app2_container, "setVisibility", android.view.View.VISIBLE)
                } else {
                    Log.d(TAG, "No app 2")
                    views.setInt(R.id.app2_container, "setVisibility", android.view.View.GONE)
                }
                
                if (usageData.topApps.size > 2) {
                    Log.d(TAG, "App 3: ${usageData.topApps[2].name}")
                    updateAppItem(context, views, usageData.topApps[2], 3)
                    views.setInt(R.id.app3_container, "setVisibility", android.view.View.VISIBLE)
                } else {
                    Log.d(TAG, "No app 3")
                    views.setInt(R.id.app3_container, "setVisibility", android.view.View.GONE)
                }
            }
            
            // Set up refresh button
            val refreshIntent = Intent(context, UsageStatsWidget::class.java).apply {
                action = ACTION_REFRESH
            }
            val refreshPendingIntent = PendingIntent.getBroadcast(
                context, 0, refreshIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.refresh_button, refreshPendingIntent)
            
            // Set up click to open app
            val openAppIntent = Intent(context, UsageStatsWidget::class.java).apply {
                action = ACTION_OPEN_APP
            }
            val openAppPendingIntent = PendingIntent.getBroadcast(
                context, 1, openAppIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            
            // Set click listener based on widget size
            if (isSmall) {
                // For small widget, entire container is clickable
                views.setOnClickPendingIntent(R.id.widget_container, openAppPendingIntent)
            } else {
                // For large widget, entire container is clickable except refresh button
                views.setOnClickPendingIntent(R.id.widget_container, openAppPendingIntent)
            }
            
            appWidgetManager.updateAppWidget(appWidgetId, views)
            Log.d(TAG, "Widget updated successfully")
            
        } catch (e: Exception) {
            Log.e(TAG, "Error updating widget: ${e.message}", e)
        }
    }

    private fun updateAppItem(
        context: Context,
        views: RemoteViews,
        app: AppInfo,
        position: Int
    ) {
        val nameId = when (position) {
            1 -> R.id.app1_name
            2 -> R.id.app2_name
            else -> R.id.app3_name
        }
        val timeId = when (position) {
            1 -> R.id.app1_time
            2 -> R.id.app2_time
            else -> R.id.app3_time
        }
        val iconId = when (position) {
            1 -> R.id.app1_icon
            2 -> R.id.app2_icon
            else -> R.id.app3_icon
        }
        
        views.setTextViewText(nameId, app.name)
        views.setTextViewText(timeId, formatTime(app.time))
        
        // Try to load icon
        try {
            val icon = context.packageManager.getApplicationIcon(app.packageName)
            val bitmap = drawableToBitmap(icon)
            views.setImageViewBitmap(iconId, bitmap)
        } catch (e: Exception) {
            Log.w(TAG, "Could not load icon for ${app.packageName}")
        }
    }

    private fun getUsageStats(context: Context): UsageData {
        try {
            val usageStatsManager = context.getSystemService(Context.USAGE_STATS_SERVICE) 
                as UsageStatsManager
            
            // Get ignored packages from SharedPreferences (same storage as main app)
            val prefs = context.getSharedPreferences("usage_stats_prefs", Context.MODE_PRIVATE)
            val ignoredPackages = prefs.getStringSet("ignored_packages", setOf()) ?: setOf()
            Log.d(TAG, "Ignored packages: $ignoredPackages")
            
            // Auto-ignore default launcher
            val launcherPackage = getDefaultLauncherPackage(context)
            
            val calendar = java.util.Calendar.getInstance()
            calendar.set(java.util.Calendar.HOUR_OF_DAY, 0)
            calendar.set(java.util.Calendar.MINUTE, 0)
            calendar.set(java.util.Calendar.SECOND, 0)
            val start = calendar.timeInMillis
            val end = System.currentTimeMillis()
            
            val stats = usageStatsManager.queryUsageStats(
                UsageStatsManager.INTERVAL_DAILY,
                start,
                end
            )
            
            val appMap = mutableMapOf<String, Long>()
            var totalTimeFiltered = 0L  // Total of apps > 3 minutes (matching main app)
            
            for (stat in stats) {
                // Skip ignored packages and launcher
                if (ignoredPackages.contains(stat.packageName) || 
                    stat.packageName == launcherPackage) {
                    continue
                }
                
                // CRITICAL: Only include apps with >3 minutes usage (matching main app filter)
                if (stat.totalTimeInForeground >= MIN_USAGE_TIME) {
                    totalTimeFiltered += stat.totalTimeInForeground
                    
                    val existing = appMap[stat.packageName] ?: 0L
                    appMap[stat.packageName] = existing + stat.totalTimeInForeground
                }
            }
            
            Log.d(TAG, "Total time (apps >3min): ${formatTime(totalTimeFiltered)}")
            Log.d(TAG, "Found ${appMap.size} apps with >3min usage")
            
            // Get top 3 apps
            val topApps = appMap.entries
                .sortedByDescending { it.value }
                .take(3)
                .mapNotNull { entry ->
                    try {
                        val pm = context.packageManager
                        val appInfo = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                            pm.getApplicationInfo(
                                entry.key,
                                PackageManager.ApplicationInfoFlags.of(0)
                            )
                        } else {
                            @Suppress("DEPRECATION")
                            pm.getApplicationInfo(entry.key, 0)
                        }
                        val appName = pm.getApplicationLabel(appInfo).toString()
                        AppInfo(entry.key, appName, entry.value)
                    } catch (e: Exception) {
                        Log.w(TAG, "Could not get info for ${entry.key}")
                        null
                    }
                }
            
            Log.d(TAG, "Top apps retrieved: ${topApps.size}")
            topApps.forEachIndexed { index, app ->
                Log.d(TAG, "${index + 1}. ${app.name} - ${formatTime(app.time)}")
            }
            
            // Return total time of apps >3 minutes (matching main app behavior)
            return UsageData(totalTimeFiltered, topApps)
            
        } catch (e: Exception) {
            Log.e(TAG, "Error getting usage stats: ${e.message}", e)
            return UsageData(0L, emptyList())
        }
    }

    private fun getDefaultLauncherPackage(context: Context): String? {
        return try {
            val intent = Intent(Intent.ACTION_MAIN)
            intent.addCategory(Intent.CATEGORY_HOME)
            val resolveInfo = context.packageManager.resolveActivity(
                intent, 
                PackageManager.MATCH_DEFAULT_ONLY
            )
            resolveInfo?.activityInfo?.packageName
        } catch (e: Exception) {
            Log.e(TAG, "Error getting launcher package: ${e.message}")
            null
        }
    }

    private fun formatTime(milliseconds: Long): String {
        if (milliseconds <= 0) return "0m"
        
        val hours = milliseconds / (1000 * 60 * 60)
        val minutes = (milliseconds % (1000 * 60 * 60)) / (1000 * 60)
        
        return when {
            hours > 0 && minutes > 0 -> "${hours}h ${minutes}m"
            hours > 0 -> "${hours}h"
            else -> "${minutes}m"
        }
    }

    private fun drawableToBitmap(drawable: android.graphics.drawable.Drawable): Bitmap {
        if (drawable is BitmapDrawable && drawable.bitmap != null) {
            return drawable.bitmap
        }
        
        val width = if (drawable.intrinsicWidth > 0) drawable.intrinsicWidth else 96
        val height = if (drawable.intrinsicHeight > 0) drawable.intrinsicHeight else 96
        
        val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        drawable.setBounds(0, 0, canvas.width, canvas.height)
        drawable.draw(canvas)
        return bitmap
    }

    data class AppInfo(val packageName: String, val name: String, val time: Long)
    data class UsageData(val totalTime: Long, val topApps: List<AppInfo>)
}
