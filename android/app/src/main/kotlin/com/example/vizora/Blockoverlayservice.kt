package com.example.vizora

import android.app.Service
import android.content.Context
import android.content.Intent
import android.graphics.PixelFormat
import android.os.Build
import android.os.IBinder
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.View
import android.view.WindowManager

class BlockOverlayService : Service() {
    
    private val TAG = "BlockOverlayService"
    private var windowManager: WindowManager? = null
    private var overlayView: View? = null
    private var dismissHandler: Handler? = null
    private var dismissRunnable: Runnable? = null
    
    override fun onBind(intent: Intent?): IBinder? = null
    
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val packageName = intent?.getStringExtra("packageName") ?: ""
        
        Log.d(TAG, "Showing block overlay for $packageName")
        
        // Remove any existing overlay first
        removeOverlay()
        
        showOverlay(packageName)
        
        // Auto-dismiss after 5 seconds to prevent overlay from staying if user navigates elsewhere
        dismissHandler = Handler(Looper.getMainLooper())
        dismissRunnable = Runnable {
            removeOverlay()
            stopSelf()
        }
        dismissHandler?.postDelayed(dismissRunnable!!, 5000)
        
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
            
            params.gravity = android.view.Gravity.CENTER
            
            // Create overlay view programmatically for dynamic theming
            overlayView = createOverlayView(packageName)
            
            windowManager?.addView(overlayView, params)
            Log.d(TAG, "Overlay shown")
            
        } catch (e: Exception) {
            Log.e(TAG, "Error showing overlay: ${e.message}", e)
            stopSelf()
        }
    }
    
    private fun createOverlayView(packageName: String): android.view.View {
        val context = this
        
        // Get Material 3 colors from system
        val surfaceColor = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            getColor(android.R.color.system_neutral1_10)
        } else {
            0xFFFFFFFF.toInt()
        }
        
        val primaryColor = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            getColor(android.R.color.system_accent1_600)
        } else {
            0xFF6750A4.toInt()
        }
        
        val errorContainerColor = 0xFFF9DEDC.toInt() // Material 3 error container
        
        val onSurfaceColor = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            getColor(android.R.color.system_neutral1_900)
        } else {
            0xFF1C1B1F.toInt()
        }
        
        val onSurfaceVariantColor = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            getColor(android.R.color.system_neutral2_700)
        } else {
            0xFF49454F.toInt()
        }
        
        // Get app info
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
        
        val timerPrefs = getSharedPreferences("app_timers", Context.MODE_PRIVATE)
        val limitMinutes = timerPrefs.getInt(packageName, 0)
        
        // Root frame with scrim
        val rootFrame = android.widget.FrameLayout(context).apply {
            layoutParams = android.view.ViewGroup.LayoutParams(
                android.view.ViewGroup.LayoutParams.MATCH_PARENT,
                android.view.ViewGroup.LayoutParams.MATCH_PARENT
            )
            setBackgroundColor(0xE6000000.toInt())
            isClickable = true
            isFocusable = true
        }
        
        // Card container
        val cardContainer = android.widget.LinearLayout(context).apply {
            orientation = android.widget.LinearLayout.VERTICAL
            val dp24 = (24 * resources.displayMetrics.density).toInt()
            val dp32 = (32 * resources.displayMetrics.density).toInt()
            layoutParams = android.widget.FrameLayout.LayoutParams(
                android.widget.FrameLayout.LayoutParams.MATCH_PARENT,
                android.widget.FrameLayout.LayoutParams.WRAP_CONTENT,
                android.view.Gravity.CENTER
            ).apply {
                setMargins(dp24, 0, dp24, 0)
            }
            setPadding(dp32, dp32, dp32, dp32)
            setBackgroundColor(surfaceColor)
            elevation = (6 * resources.displayMetrics.density)
            
            // Rounded corners
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                outlineProvider = object : android.view.ViewOutlineProvider() {
                    override fun getOutline(view: android.view.View, outline: android.graphics.Outline) {
                        outline.setRoundRect(
                            0, 0, view.width, view.height,
                            (28 * resources.displayMetrics.density)
                        )
                    }
                }
                clipToOutline = true
            }
        }
        
        // Title
        val title = android.widget.TextView(context).apply {
            text = "Time's Up!"
            textSize = 28f
            setTextColor(onSurfaceColor)
            typeface = android.graphics.Typeface.DEFAULT_BOLD
            gravity = android.view.Gravity.CENTER
            layoutParams = android.widget.LinearLayout.LayoutParams(
                android.widget.LinearLayout.LayoutParams.WRAP_CONTENT,
                android.widget.LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply {
                gravity = android.view.Gravity.CENTER_HORIZONTAL
                bottomMargin = (12 * resources.displayMetrics.density).toInt()
            }
        }
        
       // Message - Digital Detox Style with app name
val message = android.widget.TextView(context).apply {
    // Choose one of these messages:
    
    // Option 1: Gentle encouragement
    text = "You've spent $limitMinutes minutes on $appName today.\n\nTime to step away and recharge! ☕ Go grab a coffee, stretch, or enjoy the world around you."
    
    // Option 2: More direct
    // text = "That's $limitMinutes minutes on $appName today—time for a digital detox! 🌿\n\nStep outside, hydrate, move around. Your body and mind need a real-world break."
    
    // Option 3: Motivational
    // text = "$limitMinutes minutes on $appName is enough for today! ✨\n\nYour future self will thank you for this pause. Time to reconnect with the physical world—stretch, breathe, live!"
    
    // Option 4: Friendly but firm
    // text = "You've hit your $limitMinutes minute limit on $appName! 👋\n\nYour eyes, posture, and mental health deserve better. Go do something that energizes you."
    
    // Option 5: Wellness-focused
    // text = "$limitMinutes minutes on $appName today—time to unplug! 🔋\n\nConstant scrolling isn't self-care. Take a real break—sip some coffee, call a friend, or just be present."
    
    textSize = 16f
    setTextColor(onSurfaceVariantColor)
    gravity = android.view.Gravity.CENTER
    setLineSpacing((6 * resources.displayMetrics.density), 1f)
    layoutParams = android.widget.LinearLayout.LayoutParams(
        android.widget.LinearLayout.LayoutParams.MATCH_PARENT,
        android.widget.LinearLayout.LayoutParams.WRAP_CONTENT
    ).apply {
        bottomMargin = (32 * resources.displayMetrics.density).toInt()
    }
}
        
        // OK Button
        val button = android.widget.Button(context).apply {
            text = "OK"
            textSize = 16f
            setTextColor(0xFFFFFFFF.toInt())
            setBackgroundColor(primaryColor)
            typeface = android.graphics.Typeface.DEFAULT_BOLD
            val dp56 = (56 * resources.displayMetrics.density).toInt()
            layoutParams = android.widget.LinearLayout.LayoutParams(
                android.widget.LinearLayout.LayoutParams.MATCH_PARENT,
                dp56
            )
            
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                outlineProvider = object : android.view.ViewOutlineProvider() {
                    override fun getOutline(view: android.view.View, outline: android.graphics.Outline) {
                        outline.setRoundRect(
                            0, 0, view.width, view.height,
                            (16 * resources.displayMetrics.density)
                        )
                    }
                }
                clipToOutline = true
            }
            
            setOnClickListener {
                // Just dismiss the overlay
                // The app is already blocked by accessibility service
                removeOverlay()
                stopSelf()
            }
        }
        
        // Assemble
        cardContainer.addView(title)
        cardContainer.addView(message)
        cardContainer.addView(button)
        rootFrame.addView(cardContainer)
        
        return rootFrame
    }
    
    private fun removeOverlay() {
        try {
            // Cancel auto-dismiss
            dismissRunnable?.let { dismissHandler?.removeCallbacks(it) }
            
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
        dismissHandler = null
        dismissRunnable = null
    }
}