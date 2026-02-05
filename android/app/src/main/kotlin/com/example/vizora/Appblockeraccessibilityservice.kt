package com.example.vizora

import android.accessibilityservice.AccessibilityService
import android.content.Context
import android.content.Intent
import android.util.Log
import android.view.accessibility.AccessibilityEvent

class AppBlockerAccessibilityService : AccessibilityService() {
    
    private val TAG = "AppBlockerService"
    
    // Track last block time for each app to prevent spam
    private val lastBlockTimes = mutableMapOf<String, Long>()
    private val BLOCK_COOLDOWN_MS = 5000L // 5 seconds cooldown between blocks
    
    // Track if we recently performed home action
    private var lastHomeActionTime = 0L
    private val HOME_ACTION_COOLDOWN_MS = 2000L // 2 seconds
    
    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event == null) return
        
        when (event.eventType) {
            AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED -> {
                val packageName = event.packageName?.toString()
                if (packageName != null && packageName != "com.example.vizora") {
                    Log.d(TAG, "App opened: $packageName")
                    
                    // Check cooldown period
                    val now = System.currentTimeMillis()
                    val lastBlockTime = lastBlockTimes[packageName] ?: 0L
                    
                    // Skip if we recently blocked this app
                    if (now - lastBlockTime < BLOCK_COOLDOWN_MS) {
                        Log.d(TAG, "Skipping $packageName - still in cooldown period")
                        return
                    }
                    
                    // Check if app has timer and if limit exceeded
                    if (isAppLimitExceeded(packageName)) {
                        Log.d(TAG, "Limit exceeded for $packageName, showing block overlay")
                        lastBlockTimes[packageName] = now
                        showBlockOverlay(packageName)
                    }
                }
            }
        }
    }
    
    private fun isAppLimitExceeded(packageName: String): Boolean {
        try {
            // Get app timer limit
            val timerPrefs = getSharedPreferences("app_timers", Context.MODE_PRIVATE)
            val limitMinutes = timerPrefs.getInt(packageName, -1)
            
            if (limitMinutes <= 0) {
                return false // No limit set
            }
            
            // Get today's usage
            val usageMs = getTodayUsage(packageName)
            val usageMinutes = usageMs / (1000 * 60)
            
            Log.d(TAG, "$packageName - Limit: ${limitMinutes}min, Used: ${usageMinutes}min")
            
            return usageMinutes >= limitMinutes
        } catch (e: Exception) {
            Log.e(TAG, "Error checking limit: ${e.message}")
            return false
        }
    }
    
    private fun getTodayUsage(packageName: String): Long {
        try {
            val usageStatsManager = getSystemService(Context.USAGE_STATS_SERVICE) 
                as android.app.usage.UsageStatsManager
            
            val calendar = java.util.Calendar.getInstance()
            calendar.set(java.util.Calendar.HOUR_OF_DAY, 0)
            calendar.set(java.util.Calendar.MINUTE, 0)
            calendar.set(java.util.Calendar.SECOND, 0)
            val start = calendar.timeInMillis
            val end = System.currentTimeMillis()
            
            val stats = usageStatsManager.queryUsageStats(
                android.app.usage.UsageStatsManager.INTERVAL_DAILY,
                start,
                end
            )
            
            var totalTime = 0L
            for (stat in stats) {
                if (stat.packageName == packageName) {
                    totalTime += stat.totalTimeInForeground
                }
            }
            
            return totalTime
        } catch (e: Exception) {
            Log.e(TAG, "Error getting usage: ${e.message}")
            return 0L
        }
    }
    
    private fun showBlockOverlay(packageName: String) {
        val intent = Intent(this, BlockOverlayService::class.java)
        intent.putExtra("packageName", packageName)
        startService(intent)
        
        // Go back to home with cooldown check
        val now = System.currentTimeMillis()
        if (now - lastHomeActionTime > HOME_ACTION_COOLDOWN_MS) {
            performGlobalAction(GLOBAL_ACTION_HOME)
            lastHomeActionTime = now
            Log.d(TAG, "Performed home action")
        }
    }
    
    override fun onInterrupt() {
        Log.d(TAG, "Service interrupted")
    }
    
    override fun onServiceConnected() {
        super.onServiceConnected()
        Log.d(TAG, "Accessibility service connected")
    }
    
    override fun onDestroy() {
        super.onDestroy()
        Log.d(TAG, "Service destroyed")
        // Clear tracking maps
        lastBlockTimes.clear()
    }
}