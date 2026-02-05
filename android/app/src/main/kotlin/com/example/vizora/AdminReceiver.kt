package com.example.vizora

import android.app.admin.DeviceAdminReceiver
import android.app.admin.DevicePolicyManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.util.Log
import android.widget.Toast

class AdminReceiver : DeviceAdminReceiver() {
    
    private val TAG = "AdminReceiver"
    
    override fun onEnabled(context: Context, intent: Intent) {
        super.onEnabled(context, intent)
        Log.d(TAG, "Device Admin enabled")
        Toast.makeText(context, "Vizora protection enabled", Toast.LENGTH_SHORT).show()
        
        // Lock the app to prevent uninstallation
        lockApp(context, true)
    }
    
    override fun onDisabled(context: Context, intent: Intent) {
        super.onDisabled(context, intent)
        Log.d(TAG, "Device Admin disabled")
        Toast.makeText(context, "Vizora protection disabled", Toast.LENGTH_SHORT).show()
        
        // Unlock the app
        lockApp(context, false)
    }
    
    override fun onDisableRequested(context: Context, intent: Intent): CharSequence {
        Log.d(TAG, "Device Admin disable requested")
        return "Disabling device admin will allow the app to be uninstalled. " +
               "This will remove all usage tracking and app timers."
    }
    
    private fun lockApp(context: Context, lock: Boolean) {
        try {
            val dpm = context.getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager
            val componentName = ComponentName(context, AdminReceiver::class.java)
            
            if (dpm.isAdminActive(componentName)) {
                // Set package as uninstallable/installable
                val packages = arrayOf(context.packageName)
                if (lock) {
                    dpm.setUninstallBlocked(componentName, context.packageName, true)
                    Log.d(TAG, "App locked - uninstall blocked")
                } else {
                    dpm.setUninstallBlocked(componentName, context.packageName, false)
                    Log.d(TAG, "App unlocked - uninstall allowed")
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error locking/unlocking app: ${e.message}")
        }
    }
    
    override fun onPasswordChanged(context: Context, intent: Intent) {
        super.onPasswordChanged(context, intent)
        Log.d(TAG, "Password changed")
    }
    
    override fun onPasswordFailed(context: Context, intent: Intent) {
        super.onPasswordFailed(context, intent)
        Log.d(TAG, "Password failed")
    }
    
    override fun onPasswordSucceeded(context: Context, intent: Intent) {
        super.onPasswordSucceeded(context, intent)
        Log.d(TAG, "Password succeeded")
    }
}