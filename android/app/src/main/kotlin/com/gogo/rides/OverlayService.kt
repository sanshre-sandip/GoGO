package com.gogo.rides

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.os.IBinder
import android.view.ContextThemeWrapper
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.ViewConfiguration
import android.view.WindowManager
import android.widget.Button
import android.widget.CheckBox
import android.widget.LinearLayout
import android.widget.ProgressBar
import android.widget.ScrollView
import android.widget.TextView
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugins.GeneratedPluginRegistrant
import kotlin.math.abs
import org.json.JSONObject

/**
 * Foreground service that shows GoGo's floating button over other apps.
 *
 * It only ever draws GoGo's own UI — it never reads or records what is on the
 * screen underneath.
 */
class OverlayService : Service() {

    private lateinit var windowManager: WindowManager
    private var bubble: View? = null
    private var panel: View? = null
    private var results: LinearLayout? = null
    private val selected = linkedSetOf("cheapest", "nearest")

    /** Headless engine that runs the same comparison code as the app. */
    private var engine: FlutterEngine? = null
    private var worker: MethodChannel? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        windowManager = getSystemService(Context.WINDOW_SERVICE) as WindowManager
        startForegroundNotification()
        startWorkerEngine()
        showBubble()
        isRunning = true
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            stopSelf()
            return START_NOT_STICKY
        }
        // Restart if Android kills us so the assistant survives memory pressure.
        return START_STICKY
    }

    override fun onDestroy() {
        engine?.destroy()
        engine = null
        worker = null
        removePanel()
        bubble?.let { runCatching { windowManager.removeView(it) } }
        bubble = null
        isRunning = false
        super.onDestroy()
    }

    // --- Floating button -----------------------------------------------------

    private fun showBubble() {
        val size = dp(56)
        val view = TextView(themed()).apply {
            text = "🚗"
            textSize = 22f
            gravity = Gravity.CENTER
            contentDescription = "GoGo"
            background = GradientDrawable().apply {
                shape = GradientDrawable.OVAL
                setColor(BRAND)
            }
            elevation = dp(6).toFloat()
        }

        val params = layoutParams().apply {
            width = size
            height = size
            gravity = Gravity.TOP or Gravity.START
            x = dp(12)
            y = dp(220)
        }

        view.setOnTouchListener(DragToMove(params) { togglePanel() })
        runCatching { windowManager.addView(view, params) }
            .onFailure { stopSelf() } // permission revoked while running
        bubble = view
    }

    /** Moves the window with the finger; a tap that barely moves counts as a click. */
    private inner class DragToMove(
        private val params: WindowManager.LayoutParams,
        private val onClick: () -> Unit,
    ) : View.OnTouchListener {
        private val slop = ViewConfiguration.get(this@OverlayService).scaledTouchSlop
        private var startX = 0
        private var startY = 0
        private var touchX = 0f
        private var touchY = 0f
        private var dragged = false

        override fun onTouch(view: View, event: MotionEvent): Boolean {
            when (event.action) {
                MotionEvent.ACTION_DOWN -> {
                    startX = params.x
                    startY = params.y
                    touchX = event.rawX
                    touchY = event.rawY
                    dragged = false
                }
                MotionEvent.ACTION_MOVE -> {
                    val dx = (event.rawX - touchX).toInt()
                    val dy = (event.rawY - touchY).toInt()
                    if (abs(dx) > slop || abs(dy) > slop) dragged = true
                    params.x = startX + dx
                    params.y = startY + dy
                    runCatching { windowManager.updateViewLayout(view, params) }
                }
                MotionEvent.ACTION_UP -> if (!dragged) {
                    view.performClick()
                    onClick()
                }
            }
            return true
        }
    }

    // --- Compact GoGo panel --------------------------------------------------

    private fun togglePanel() = if (panel == null) showPanel() else removePanel()

    private fun showPanel() {
        val context = themed()
        val list = LinearLayout(context).apply { orientation = LinearLayout.VERTICAL }
        results = list

        val content = LinearLayout(context).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(16), dp(16), dp(16), dp(16))
            background = GradientDrawable().apply {
                cornerRadius = dp(18).toFloat()
                setColor(Color.WHITE)
            }
            elevation = dp(8).toFloat()

            addView(TextView(context).apply {
                text = "🚗 GoGo"
                textSize = 18f
                setTextColor(Color.BLACK)
            })

            PRIORITIES.forEach { (key, label) ->
                addView(CheckBox(context).apply {
                    text = label
                    setTextColor(Color.BLACK)
                    isChecked = key in selected
                    setOnCheckedChangeListener { _, checked ->
                        if (checked) selected.add(key) else selected.remove(key)
                    }
                })
            }

            addView(Button(context).apply {
                text = "Compare"
                setOnClickListener { compare() }
            })
            addView(ScrollView(context).apply {
                layoutParams = LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.MATCH_PARENT,
                    dp(260),
                )
                addView(list)
            })
            addView(Button(context).apply {
                text = "Open GoGo"
                setOnClickListener { openApp() }
            })
            addView(Button(context).apply {
                text = "Close"
                setOnClickListener { removePanel() }
            })
        }

        val params = layoutParams().apply {
            width = dp(300)
            gravity = Gravity.TOP or Gravity.START
            x = dp(12)
            y = dp(90)
        }
        runCatching { windowManager.addView(content, params) }.onSuccess { panel = content }
    }

    private fun removePanel() {
        panel?.let { runCatching { windowManager.removeView(it) } }
        panel = null
        results = null
    }

    /**
     * Runs the real comparison in the headless engine and draws the answer in
     * the overlay, so the app underneath keeps running and stays visible.
     */
    private fun compare() {
        val list = results ?: return
        val channel = worker
        list.removeAllViews()

        if (channel == null) {
            list.addView(note("GoGo's comparison engine isn't running. Reopen the assistant."))
            return
        }

        list.addView(ProgressBar(themed()))
        val installed = PROVIDER_PACKAGES.filter { ProviderLauncher.isInstalled(this, it) }

        channel.invokeMethod(
            "compare",
            mapOf("priorities" to selected.toList(), "installed" to installed),
            object : MethodChannel.Result {
                override fun success(result: Any?) = render(result as? String)
                override fun error(code: String, message: String?, details: Any?) =
                    renderError(message ?: "Comparison failed.")
                override fun notImplemented() = renderError("Comparison unavailable.")
            },
        )
    }

    private fun render(json: String?) {
        val list = results ?: return
        list.removeAllViews()
        if (json == null) return renderError("No answer from GoGo.")

        val body = runCatching { JSONObject(json) }.getOrNull()
            ?: return renderError("Couldn't read the result.")

        body.optString("error").takeIf { it.isNotEmpty() }?.let { return renderError(it) }

        val destination = body.optString("destination")
        if (destination.isNotEmpty()) list.addView(note("To $destination"))
        val best = body.optString("best")

        val providers = body.optJSONArray("providers") ?: return
        for (i in 0 until providers.length()) {
            val p = providers.optJSONObject(i) ?: continue
            val price = p.optString("price")
            val line = buildString {
                if (p.optString("id") == best) append("🏆 ")
                append(p.optString("name"))
                if (price.isNotEmpty()) {
                    append("  ").append(price)
                    p.optString("eta").takeIf { it.isNotEmpty() }?.let { append("  ").append(it) }
                } else {
                    append(" — ").append(p.optString("message"))
                }
            }

            list.addView(TextView(themed()).apply {
                text = line
                setTextColor(Color.BLACK)
                setPadding(0, dp(8), 0, dp(2))
            })
            list.addView(Button(themed()).apply {
                text = if (p.optBoolean("installed")) "Open ${p.optString("name")}"
                else "Install ${p.optString("name")}"
                setOnClickListener {
                    ProviderLauncher.open(this@OverlayService, p.optString("package"), null)
                }
            })
        }
    }

    private fun renderError(message: String) {
        val list = results ?: return
        list.removeAllViews()
        list.addView(note(message))
    }

    private fun note(message: String) = TextView(themed()).apply {
        text = message
        setTextColor(Color.DKGRAY)
        setPadding(0, dp(8), 0, dp(4))
    }

    /** Opens the full app — used only when the user asks for it. */
    private fun openApp() {
        removePanel()
        startActivity(
            Intent(this, MainActivity::class.java)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
                .putStringArrayListExtra(EXTRA_PRIORITIES, ArrayList(selected))
        )
    }

    // --- Plumbing ------------------------------------------------------------

    private fun layoutParams() = WindowManager.LayoutParams(
        WindowManager.LayoutParams.WRAP_CONTENT,
        WindowManager.LayoutParams.WRAP_CONTENT,
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        else
            @Suppress("DEPRECATION") WindowManager.LayoutParams.TYPE_PHONE,
        WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
            WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
        PixelFormat.TRANSLUCENT,
    )

    private fun startWorkerEngine() {
        val loader = FlutterInjector.instance().flutterLoader()
        loader.startInitialization(applicationContext)
        loader.ensureInitializationComplete(applicationContext, null)

        val created = FlutterEngine(applicationContext)
        created.dartExecutor.executeDartEntrypoint(
            DartExecutor.DartEntrypoint(loader.findAppBundlePath(), OVERLAY_ENTRYPOINT),
        )
        GeneratedPluginRegistrant.registerWith(created)
        engine = created
        worker = MethodChannel(created.dartExecutor.binaryMessenger, WORKER_CHANNEL)
    }

    private fun startForegroundNotification() {
        val manager = getSystemService(NotificationManager::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            manager.createNotificationChannel(
                NotificationChannel(CHANNEL_ID, "Floating Assistant", NotificationManager.IMPORTANCE_LOW)
            )
        }

        val stop = PendingIntent.getService(
            this,
            0,
            Intent(this, OverlayService::class.java).setAction(ACTION_STOP),
            PendingIntent.FLAG_IMMUTABLE,
        )

        val notification: Notification = Notification.Builder(this, CHANNEL_ID)
            .setContentTitle("GoGo floating assistant")
            .setContentText("Tap the GoGo button to compare rides anywhere.")
            .setSmallIcon(android.R.drawable.ic_menu_directions)
            .setOngoing(true)
            .addAction(Notification.Action.Builder(null, "Stop", stop).build())
            .build()

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(
                NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE,
            )
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }

    private fun themed() = ContextThemeWrapper(this, android.R.style.Theme_DeviceDefault_Light)

    private fun dp(value: Int) = (value * resources.displayMetrics.density).toInt()

    companion object {
        const val EXTRA_PRIORITIES = "gogo.priorities"
        const val ACTION_STOP = "gogo.action.STOP"

        private const val CHANNEL_ID = "gogo_overlay"
        private const val NOTIFICATION_ID = 42
        private const val BRAND = 0xFF4F46E5.toInt()
        private const val OVERLAY_ENTRYPOINT = "overlayMain"
        private const val WORKER_CHANNEL = "gogo/overlay_worker"

        /** Kept in step with kProviders in lib/services/quote_service.dart. */
        private val PROVIDER_PACKAGES = listOf(
            "com.pathao.user",
            "sinet.startup.inDriver",
            "com.yandex.yango",
            "com.ubercab",
        )

        // key must match Dart's Priority enum names
        private val PRIORITIES = listOf(
            "cheapest" to "Cheapest",
            "nearest" to "Nearest",
            "fastest" to "Fastest",
        )

        @Volatile
        var isRunning: Boolean = false
            internal set
    }
}
