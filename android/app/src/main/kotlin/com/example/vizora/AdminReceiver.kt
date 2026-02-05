package com.example.vizora

import android.app.admin.DeviceAdminReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

class AdminReceiver : DeviceAdminReceiver() {
    
    private val TAG = "AdminReceiver"
    
    override fun onEnabled(context: Context, intent: Intent) {
        super.onEnabled(context, intent)
        Log.d(TAG, "Device Admin enabled")
    }
    
    override fun onDisabled(context: Context, intent: Intent) {
        super.onDisabled(context, intent)
        Log.d(TAG, "Device Admin disabled")
    }
    
    override fun onDisableRequested(context: Context, intent: Intent): CharSequence {
        Log.d(TAG, "Device Admin disable requested")
        return "Disabling device admin will allow app uninstallation"
    }
}