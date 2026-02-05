package com.example.vizora

import android.app.Service
import android.content.Context
import android.content.Intent
import android.graphics.PixelFormat
import android.os.Build
import android.os.IBinder
import android.util.Log
import android.view.Gravity
import android.view.LayoutInflater
import android.view.View
import android.view.WindowManager
import android.widget.Button
import android.widget.TextView

class BlockOverlayService : Service() {
    
    private val TAG = "BlockOverlayService"
    private var windowManager: WindowManager? = null
    private var overlayView: View? = null
    
    override fun onBind(intent: Intent?): IBinder? = null
    
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val packageName = intent?.getStringExtra("packageName") ?: ""
        
        Log.d(TAG, "Showing block overlay for $packageName")
        
        showOverlay(packageName)
        
        // Auto-dismiss after 3 seconds
        overlayView?.postDelayed({
            removeOverlay()
            stopSelf()
        }, 3000)
        
        return START_NOT_STICKY
    }
    
    private fun showOverlay(packageName: String) {
        try {
            windowManager = getSystemService(Context.WINDOW_SERVICE) as WindowManager
            
            val layoutType = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
            } else {
                @Suppress("DEPRECATION")
                WindowManager.LayoutParams.TYPE_PHONE
            }
            
            val params = WindowManager.LayoutParams(
                WindowManager.LayoutParams.MATCH_PARENT,
                WindowManager.LayoutParams.MATCH_PARENT,
                layoutType,
                WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                        WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
                PixelFormat.TRANSLUCENT
            )
            
            params.gravity = Gravity.CENTER
            
            overlayView = LayoutInflater.from(this).inflate(R.layout.block_overlay, null)
            
            // Get app name
            val appName = try {
                val pm = packageManager
                val appInfo = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                    pm.getApplicationInfo(packageName, android.content.pm.PackageManager.ApplicationInfoFlags.of(0))
                } else {
                    @Suppress("DEPRECATION")
                    pm.getApplicationInfo(packageName, 0)
                }
                pm.getApplicationLabel(appInfo).toString()
            } catch (e: Exception) {
                packageName.split('.').last()
            }
            
            // Get timer limit
            val timerPrefs = getSharedPreferences("app_timers", Context.MODE_PRIVATE)
            val limitMinutes = timerPrefs.getInt(packageName, 0)
            
            // Update UI
            overlayView?.findViewById<TextView>(R.id.block_title)?.text = "Time's Up!"
            overlayView?.findViewById<TextView>(R.id.block_message)?.text = 
                "You've reached your $limitMinutes minute limit for $appName today."
            
            overlayView?.findViewById<Button>(R.id.btn_ok)?.setOnClickListener {
                removeOverlay()
                stopSelf()
            }
            
            windowManager?.addView(overlayView, params)
            Log.d(TAG, "Overlay shown")
            
        } catch (e: Exception) {
            Log.e(TAG, "Error showing overlay: ${e.message}", e)
            stopSelf()
        }
    }
    
    private fun removeOverlay() {
        try {
            if (overlayView != null) {
                windowManager?.removeView(overlayView)
                overlayView = null
                Log.d(TAG, "Overlay removed")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error removing overlay: ${e.message}")
        }
    }
    
    override fun onDestroy() {
        super.onDestroy()
        removeOverlay()
    }
}