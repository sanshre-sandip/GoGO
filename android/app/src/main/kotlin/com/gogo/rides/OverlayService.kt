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
import android.widget.TextView
import kotlin.math.abs

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
    private val selected = linkedSetOf("cheapest", "nearest")

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        windowManager = getSystemService(Context.WINDOW_SERVICE) as WindowManager
        startForegroundNotification()
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
                setOnClickListener { openApp() }
            })
            addView(Button(context).apply {
                text = "Close"
                setOnClickListener { removePanel() }
            })
        }

        val params = layoutParams().apply {
            width = dp(240)
            gravity = Gravity.TOP or Gravity.START
            x = dp(12)
            y = dp(120)
        }
        runCatching { windowManager.addView(content, params) }.onSuccess { panel = content }
    }

    private fun removePanel() {
        panel?.let { runCatching { windowManager.removeView(it) } }
        panel = null
    }

    /** Hands the chosen priorities to the Flutter UI. GoGo never books anything itself. */
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
