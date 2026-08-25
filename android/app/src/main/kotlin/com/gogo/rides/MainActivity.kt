package com.gogo.rides

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import com.gogo.rides.automation.AutomationController
import io.flutter.plugin.common.EventChannel
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
                    "installedProviders" -> result.success(
                        call.argument<List<String>>("packages")
                            ?.filter { isInstalled(it) } ?: emptyList<String>()
                    )
                    "openProvider" -> result.success(
                        openProvider(call.argument("package"), call.argument("deepLink"))
                    )
                    "accessibilityStatus" ->
                        result.success(AutomationController.diagnostics(this).toString())
                    "openAccessibilitySettings" -> {
                        AutomationController.openAccessibilitySettings(this)
                        result.success(true)
                    }
                    "startComparison" -> {
                        val args = call.arguments as? Map<*, *> ?: emptyMap<String, Any>()
                        result.success(
                            AutomationController
                                .start(this, AutomationController.tripFrom(args))
                                .toString(),
                        )
                    }
                    "cancelComparison" -> {
                        AutomationController.cancel()
                        result.success(true)
                    }
                    "sessionSnapshot" -> result.success(AutomationController.snapshot().toString())
                    "automationLogs" -> result.success(AutomationController.logs().toString())
                    "consumePendingRequest" -> {
                        result.success(pendingPriorities)
                        pendingPriorities = null
                    }
                    else -> result.notImplemented()
                }
            }
        streamSessionUpdates(flutterEngine)
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

    /** Pushes every session update to Flutter as it happens. */
    private fun streamSessionUpdates(engine: FlutterEngine) {
        EventChannel(engine.dartExecutor.binaryMessenger, EVENTS).setStreamHandler(
            object : EventChannel.StreamHandler {
                private var forward: ((org.json.JSONObject) -> Unit)? = null

                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    val sink = events ?: return
                    val listener: (org.json.JSONObject) -> Unit = { snapshot ->
                        runOnUiThread { sink.success(snapshot.toString()) }
                    }
                    forward = listener
                    AutomationController.addListener(listener)
                    sink.success(AutomationController.snapshot().toString())
                }

                override fun onCancel(arguments: Any?) {
                    forward?.let(AutomationController::removeListener)
                    forward = null
                }
            },
        )
    }

    private fun openProvider(packageName: String?, deepLink: String?): String =
        ProviderLauncher.open(this, packageName, deepLink)

    private fun isInstalled(packageName: String) = ProviderLauncher.isInstalled(this, packageName)

    private companion object {
        const val CHANNEL = "gogo/overlay"
        const val EVENTS = "gogo/automation_events"
    }
}
