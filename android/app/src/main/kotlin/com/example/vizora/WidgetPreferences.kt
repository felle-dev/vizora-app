package com.example.vizora

import android.content.Context
import android.content.SharedPreferences

object WidgetPreferences {
    private const val PREFS_NAME = "widget_prefs"
    private const val KEY_IGNORED_PACKAGES = "ignored_packages"
    
    fun getIgnoredPackages(context: Context): Set<String> {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        return prefs.getStringSet(KEY_IGNORED_PACKAGES, emptySet()) ?: emptySet()
    }
    
    fun setIgnoredPackages(context: Context, packages: Set<String>) {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        prefs.edit().putStringSet(KEY_IGNORED_PACKAGES, packages).apply()
    }
    
    fun addIgnoredPackage(context: Context, packageName: String) {
        val ignored = getIgnoredPackages(context).toMutableSet()
        ignored.add(packageName)
        setIgnoredPackages(context, ignored)
    }
    
    fun removeIgnoredPackage(context: Context, packageName: String) {
        val ignored = getIgnoredPackages(context).toMutableSet()
        ignored.remove(packageName)
        setIgnoredPackages(context, ignored)
    }
}