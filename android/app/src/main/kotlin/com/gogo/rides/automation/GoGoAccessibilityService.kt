package com.gogo.rides.automation

import android.accessibilityservice.AccessibilityService
import android.provider.Settings
import android.content.Context
import android.text.TextUtils
import android.view.accessibility.AccessibilityEvent

/**
 * The eyes and hands of a comparison session.
 *
 * Scope is deliberately narrow: events are filtered to the supported ride apps
 * by the service config, and this class drops everything unless a comparison
 * the user started is actually running. Nothing is read, stored or forwarded
 * outside that window.
 */
class GoGoAccessibilityService : AccessibilityService() {

    override fun onServiceConnected() {
        super.onServiceConnected()
        instance = this
        AutomationLog.log("service", null, "accessibility_connected")
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        val session = SessionCoordinator.active ?: return
        val packageName = event?.packageName?.toString() ?: return
        if (packageName != session.currentPackage) return

        when (event.eventType) {
            AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED,
            AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED,
            -> session.onProviderScreenChanged(rootInActiveWindow)
        }
    }

    override fun onInterrupt() {
        AutomationLog.log("service", null, "accessibility_interrupted")
    }

    override fun onUnbind(intent: android.content.Intent?): Boolean {
        instance = null
        SessionCoordinator.active?.cancel("Accessibility service was turned off")
        AutomationLog.log("service", null, "accessibility_disconnected")
        return super.onUnbind(intent)
    }

    companion object {
        @Volatile
        var instance: GoGoAccessibilityService? = null
            private set

        val isConnected get() = instance != null

        /**
         * Whether the user has enabled GoGo in Settings › Accessibility. Read
         * from secure settings so the answer is right even before the service
         * has bound.
         */
        fun isEnabled(context: Context): Boolean {
            val expected = "${context.packageName}/${GoGoAccessibilityService::class.java.name}"
            val enabled = Settings.Secure.getString(
                context.contentResolver,
                Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES,
            ) ?: return false

            val splitter = TextUtils.SimpleStringSplitter(':')
            splitter.setString(enabled)
            for (item in splitter) {
                if (item.equals(expected, ignoreCase = true)) return true
            }
            return false
        }
    }
}
