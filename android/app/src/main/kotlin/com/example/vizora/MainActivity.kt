package com.example.vizora

import android.app.AppOpsManager
import android.app.admin.DevicePolicyManager
import android.app.usage.UsageStatsManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.BitmapDrawable
import android.graphics.drawable.Drawable
import android.os.Build
import android.os.Environment
import android.provider.Settings
import android.util.Log
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.io.File
import java.io.FileWriter
import java.text.SimpleDateFormat
import java.util.*

class MainActivity: FlutterActivity() {
    private val CHANNEL = "usage_stats"
    private val TAG = "UsageStatsDebug"

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler {
            call, result ->
            when (call.method) {
                // ===== PERMISSION 1: Usage Stats =====
                "hasPermission" -> {
                    result.success(hasUsageStatsPermission())
                }
                "requestPermission" -> {
                    openUsageAccessSettings()
                    result.success(null)
                }
                
                // ===== PERMISSION 2: Accessibility Service =====
                "hasAccessibilityPermission" -> {
                    result.success(isAccessibilityServiceEnabled())
                }
                "requestAccessibilityPermission" -> {
                    openAccessibilitySettings()
                    result.success(null)
                }
                
                // ===== PERMISSION 3: Display Over Other Apps =====
                "hasOverlayPermission" -> {
                    result.success(Settings.canDrawOverlays(this))
                }
                "requestOverlayPermission" -> {
                    openOverlaySettings()
                    result.success(null)
                }
                
                // ===== PERMISSION 4: Device Admin =====
                "hasDeviceAdminPermission" -> {
                    result.success(isDeviceAdminActive())
                }
                "requestDeviceAdminPermission" -> {
                    requestDeviceAdmin()
                    result.success(null)
                }
                
                // ===== Usage Stats Methods =====
                "getStatsByTimestamps" -> {
                    val start = call.argument<Long>("start") ?: 0
                    val end = call.argument<Long>("end") ?: System.currentTimeMillis()
                    result.success(getUsageStats(start, end))
                }
                "getEarliestDataTimestamp" -> {
                    result.success(getEarliestDataTimestamp())
                }
                "getAppInfo" -> {
                    val packageName = call.argument<String>("packageName")
                    result.success(if (packageName != null) getAppInfo(packageName) else null)
                }
                "setIgnoredPackages" -> {
                    val packages = call.argument<List<String>>("packages")
                    if (packages != null) {
                        val prefs = getSharedPreferences("usage_stats_prefs", Context.MODE_PRIVATE)
                        prefs.edit().putStringSet("ignored_packages", packages.toSet()).apply()
                        result.success(null)
                    } else {
                        result.error("INVALID_ARGUMENT", "packages cannot be null", null)
                    }
                }
                "exportData" -> {
                    val startDate = call.argument<Long>("startDate") ?: 0L
                    val endDate = call.argument<Long>("endDate") ?: System.currentTimeMillis()
                    result.success(exportUsageData(startDate, endDate))
                }
                else -> result.notImplemented()
            }
        }
    }

    // ========================================================================
    // PERMISSION 1: Usage Stats Permission
    // ========================================================================
    
    private fun hasUsageStatsPermission(): Boolean {
        val appOps = getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
        val mode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            appOps.unsafeCheckOpNoThrow(
                AppOpsManager.OPSTR_GET_USAGE_STATS,
                android.os.Process.myUid(),
                packageName
            )
        } else {
            appOps.checkOpNoThrow(
                AppOpsManager.OPSTR_GET_USAGE_STATS,
                android.os.Process.myUid(),
                packageName
            )
        }
        return mode == AppOpsManager.MODE_ALLOWED
    }

    private fun openUsageAccessSettings() {
        startActivity(Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS))
    }

    // ========================================================================
    // PERMISSION 2: Accessibility Service
    // ========================================================================
    
    private fun isAccessibilityServiceEnabled(): Boolean {
        val serviceName = ComponentName(this, AppBlockerAccessibilityService::class.java).flattenToString()
        val enabledServices = Settings.Secure.getString(
            contentResolver,
            Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES
        ) ?: return false
        val isEnabled = Settings.Secure.getInt(
            contentResolver,
            Settings.Secure.ACCESSIBILITY_ENABLED,
            0
        )
        return isEnabled == 1 && enabledServices.contains(serviceName)
    }

    private fun openAccessibilitySettings() {
        startActivity(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS))
    }

    // ========================================================================
    // PERMISSION 3: Display Over Other Apps
    // ========================================================================
    
    private fun openOverlaySettings() {
        val intent = Intent(
            Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
            android.net.Uri.parse("package:$packageName")
        )
        startActivity(intent)
    }

    // ========================================================================
    // PERMISSION 4: Device Admin
    // ========================================================================
    
    private fun isDeviceAdminActive(): Boolean {
        val dpm = getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager
        val componentName = ComponentName(this, AdminReceiver::class.java)
        return dpm.isAdminActive(componentName)
    }

    private fun requestDeviceAdmin() {
        val intent = Intent(DevicePolicyManager.ACTION_ADD_DEVICE_ADMIN)
        val componentName = ComponentName(this, AdminReceiver::class.java)
        intent.putExtra(DevicePolicyManager.EXTRA_DEVICE_ADMIN, componentName)
        intent.putExtra(
            DevicePolicyManager.EXTRA_ADD_EXPLANATION,
            "Enable admin to prevent app uninstallation"
        )
        startActivity(intent)
    }

    // ========================================================================
    // Usage Stats Methods
    // ========================================================================

    private fun getUsageStats(start: Long, end: Long): List<Map<String, Any>> {
        try {
            val usageStatsManager = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
            
            // Get ignored packages from SharedPreferences
            val prefs = getSharedPreferences("usage_stats_prefs", Context.MODE_PRIVATE)
            val ignoredPackages = prefs.getStringSet("ignored_packages", setOf()) ?: setOf()
            
            // Auto-ignore the default launcher app
            val launcherPackage = getDefaultLauncherPackage()
            
            // Step 1: Get daily aggregated stats
            val stats = usageStatsManager.queryUsageStats(
                UsageStatsManager.INTERVAL_DAILY,
                start,
                end
            )

            if (stats == null || stats.isEmpty()) {
                return emptyList()
            }

            // Step 2: Aggregate by package (excluding ignored & launcher)
            val aggregatedStats = mutableMapOf<String, MutableMap<String, Any>>()

            for (stat in stats) {
                if (stat.totalTimeInForeground > 0) {
                    val packageName = stat.packageName
                    
                    // Skip ignored packages and launcher
                    if (packageName in ignoredPackages || packageName == launcherPackage) {
                        continue
                    }
                    
                    if (aggregatedStats.containsKey(packageName)) {
                        val existing = aggregatedStats[packageName]!!
                        val totalTime = existing["totalTime"] as Long
                        existing["totalTime"] = totalTime + stat.totalTimeInForeground
                    } else {
                        aggregatedStats[packageName] = mutableMapOf(
                            "packageName" to packageName,
                            "totalTime" to stat.totalTimeInForeground,
                            "startTimes" to mutableListOf<Long>()
                        )
                    }
                }
            }

            // Step 3: Query events for accurate session tracking
            try {
                val events = usageStatsManager.queryEvents(start, end)
                val sessionStarts = mutableMapOf<String, MutableList<Long>>()
                
                while (events.hasNextEvent()) {
                    val event = android.app.usage.UsageEvents.Event()
                    events.getNextEvent(event)
                    
                    if (event.eventType == android.app.usage.UsageEvents.Event.MOVE_TO_FOREGROUND) {
                        if (!sessionStarts.containsKey(event.packageName)) {
                            sessionStarts[event.packageName] = mutableListOf()
                        }
                        sessionStarts[event.packageName]?.add(event.timeStamp)
                    }
                }

                // Update start times with event data
                for ((packageName, starts) in sessionStarts) {
                    if (aggregatedStats.containsKey(packageName)) {
                        aggregatedStats[packageName]!!["startTimes"] = starts
                    }
                }
            } catch (e: Exception) {
                Log.e(TAG, "Error querying events: ${e.message}")
            }

            return aggregatedStats.values.toList()
            
        } catch (e: Exception) {
            Log.e(TAG, "Error getting usage stats: ${e.message}")
            return emptyList()
        }
    }

    private fun getDefaultLauncherPackage(): String? {
        return try {
            val intent = Intent(Intent.ACTION_MAIN)
            intent.addCategory(Intent.CATEGORY_HOME)
            val resolveInfo = packageManager.resolveActivity(intent, PackageManager.MATCH_DEFAULT_ONLY)
            resolveInfo?.activityInfo?.packageName
        } catch (e: Exception) {
            Log.e(TAG, "Error getting launcher package: ${e.message}")
            null
        }
    }

    private fun getEarliestDataTimestamp(): Long {
        try {
            val usageStatsManager = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
            val now = System.currentTimeMillis()
            val thirtyDaysAgo = now - (30L * 24 * 60 * 60 * 1000)
            
            val stats = usageStatsManager.queryUsageStats(
                UsageStatsManager.INTERVAL_DAILY,
                thirtyDaysAgo,
                now
            )

            var earliest = now
            for (stat in stats) {
                if (stat.firstTimeStamp > 0 && stat.firstTimeStamp < earliest) {
                    earliest = stat.firstTimeStamp
                }
            }

            return if (earliest < now) earliest else thirtyDaysAgo
        } catch (e: Exception) {
            return System.currentTimeMillis() - (7L * 24 * 60 * 60 * 1000)
        }
    }

    private fun getAppInfo(packageName: String): Map<String, Any>? {
        return try {
            val pm = packageManager
            
            val appInfo = try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                    pm.getApplicationInfo(packageName, PackageManager.ApplicationInfoFlags.of(0))
                } else {
                    @Suppress("DEPRECATION")
                    pm.getApplicationInfo(packageName, 0)
                }
            } catch (e: PackageManager.NameNotFoundException) {
                return null
            }
            
            val appName = try {
                pm.getApplicationLabel(appInfo).toString()
            } catch (e: Exception) {
                packageName.split('.').last()
            }
            
            val iconBytes = try {
                val icon = pm.getApplicationIcon(packageName)
                drawableToByteArray(icon)
            } catch (e: Exception) {
                ByteArray(0)
            }
            
            mapOf(
                "appName" to appName,
                "icon" to iconBytes
            )
        } catch (e: Exception) {
            null
        }
    }

    private fun drawableToByteArray(drawable: Drawable): ByteArray {
        try {
            val size = 192
            
            val bitmap = if (drawable is BitmapDrawable && drawable.bitmap != null) {
                val sourceBitmap = drawable.bitmap
                if (sourceBitmap.width != size || sourceBitmap.height != size) {
                    Bitmap.createScaledBitmap(sourceBitmap, size, size, true)
                } else {
                    sourceBitmap
                }
            } else {
                val width = if (drawable.intrinsicWidth > 0) drawable.intrinsicWidth else size
                val height = if (drawable.intrinsicHeight > 0) drawable.intrinsicHeight else size
                
                val bitmap = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
                val canvas = Canvas(bitmap)
                
                val scale = minOf(size.toFloat() / width, size.toFloat() / height)
                val scaledWidth = (width * scale).toInt()
                val scaledHeight = (height * scale).toInt()
                val left = (size - scaledWidth) / 2
                val top = (size - scaledHeight) / 2
                
                drawable.setBounds(left, top, left + scaledWidth, top + scaledHeight)
                drawable.draw(canvas)
                bitmap
            }

            val stream = ByteArrayOutputStream()
            bitmap.compress(Bitmap.CompressFormat.PNG, 100, stream)
            return stream.toByteArray()
        } catch (e: Exception) {
            return ByteArray(0)
        }
    }

    // ========================================================================
    // Export Data
    // ========================================================================

    private fun exportUsageData(startDate: Long, endDate: Long): String? {
        try {
            val usageStats = getUsageStats(startDate, endDate)
            
            if (usageStats.isEmpty()) {
                Log.w(TAG, "No usage data to export")
                return null
            }

            // Create CSV content
            val csv = StringBuilder()
            csv.append("Package Name,App Name,Total Time (ms),Total Time (formatted),Sessions,Start Times\n")

            for (stat in usageStats) {
                val packageName = stat["packageName"] as String
                val totalTime = stat["totalTime"] as Long
                val startTimes = stat["startTimes"] as List<*>
                
                val appInfo = getAppInfo(packageName)
                val appName = appInfo?.get("appName") as? String ?: packageName.split('.').last()
                val formattedTime = formatTime(totalTime)
                val sessions = startTimes.size
                
                val startTimesStr = startTimes.joinToString(";") { time ->
                    SimpleDateFormat("yyyy-MM-dd HH:mm:ss", Locale.getDefault())
                        .format(Date(time as Long))
                }
                
                csv.append("\"$packageName\",\"$appName\",$totalTime,\"$formattedTime\",$sessions,\"$startTimesStr\"\n")
            }

            // Save to Downloads folder
            val downloadsDir = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS)
            val fileName = "usage_stats_${SimpleDateFormat("yyyyMMdd_HHmmss", Locale.getDefault()).format(Date())}.csv"
            val file = File(downloadsDir, fileName)

            FileWriter(file).use { writer ->
                writer.write(csv.toString())
            }

            Log.d(TAG, "Data exported to: ${file.absolutePath}")
            return file.absolutePath

        } catch (e: Exception) {
            Log.e(TAG, "Error exporting data: ${e.message}", e)
            return null
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
}
