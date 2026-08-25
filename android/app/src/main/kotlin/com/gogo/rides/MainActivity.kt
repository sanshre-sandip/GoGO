package com.gogo.rides

import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    /** Priorities the floating overlay asked us to compare, waiting for Flutter to pick up. */
    private var pendingPriorities: ArrayList<String>? = null

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)
        readPending(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        readPending(intent)
    }

    private fun readPending(intent: Intent?) {
        intent?.getStringArrayListExtra(OverlayService.EXTRA_PRIORITIES)?.let {
            pendingPriorities = it
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "hasPermission" -> result.success(canDrawOverlays())
                    "requestPermission" -> result.success(requestOverlayPermission())
                    "isRunning" -> result.success(OverlayService.isRunning)
                    "start" -> result.success(startOverlay())
                    "stop" -> {
                        stopService(Intent(this, OverlayService::class.java))
                        result.success(true)
                    }
                    "openProvider" -> result.success(
                        openProvider(call.argument("package"), call.argument("deepLink"))
                    )
                    "consumePendingRequest" -> {
                        result.success(pendingPriorities)
                        pendingPriorities = null
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun canDrawOverlays() =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.M || Settings.canDrawOverlays(this)

    private fun requestOverlayPermission(): Boolean {
        if (canDrawOverlays()) return true
        startActivity(
            Intent(
                Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                Uri.parse("package:$packageName"),
            ).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        )
        return false // the user grants it in system settings; Flutter re-checks on resume
    }

    private fun startOverlay(): Boolean {
        if (!canDrawOverlays()) return false
        val intent = Intent(this, OverlayService::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(intent)
        } else {
            startService(intent)
        }
        return true
    }

    /**
     * Hands the user over to a provider's own app. Never books anything —
     * it just opens the app (or its store page if it isn't installed).
     * Returns "opened", "store" or "unavailable".
     */
    private fun openProvider(packageName: String?, deepLink: String?): String {
        // A deep link is pinned to the provider's package so it can't be
        // hijacked by a browser or another app.
        if (deepLink != null && launch(Intent(Intent.ACTION_VIEW, Uri.parse(deepLink)).apply {
                if (packageName != null) setPackage(packageName)
            })
        ) {
            return "opened"
        }

        if (packageName == null) return "unavailable"

        packageManager.getLaunchIntentForPackage(packageName)?.let {
            if (launch(it)) return "opened"
        }

        val store = Intent(Intent.ACTION_VIEW, Uri.parse("market://details?id=$packageName"))
        val web = Intent(
            Intent.ACTION_VIEW,
            Uri.parse("https://play.google.com/store/apps/details?id=$packageName"),
        )
        return if (launch(store) || launch(web)) "store" else "unavailable"
    }

    private fun launch(intent: Intent): Boolean = try {
        startActivity(intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
        true
    } catch (_: ActivityNotFoundException) {
        false
    }

    private companion object {
        const val CHANNEL = "gogo/overlay"
    }
}
