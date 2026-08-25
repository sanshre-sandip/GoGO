package com.gogo.rides.automation

import android.content.Context
import android.content.Intent
import android.provider.Settings
import com.gogo.rides.ProviderLauncher
import com.gogo.rides.providers.ProviderRegistry
import com.gogo.rides.providers.TripContext
import org.json.JSONArray
import org.json.JSONObject

/**
 * The one place Flutter, the overlay and the accessibility service meet.
 * Everything it publishes is a snapshot of what actually happened — a provider
 * either has an extracted fare or a stated reason it has none.
 */
object AutomationController : ComparisonSession.Listener {

    private val listeners = mutableListOf<(JSONObject) -> Unit>()

    val isRunning: Boolean
        get() = SessionCoordinator.active?.let {
            it.state != SessionState.COMPLETED && it.state != SessionState.CANCELLED
        } ?: false

    fun start(context: Context, trip: TripContext): JSONObject {
        if (isRunning) return snapshot()

        val session = ComparisonSession(
            context = context.applicationContext,
            trip = trip,
            adapters = ProviderRegistry.all(),
            listener = this,
        )
        SessionCoordinator.active = session
        session.start()
        return snapshot()
    }

    fun cancel(note: String? = "Cancelled by you") {
        SessionCoordinator.active?.cancel(note)
    }

    override fun onSessionUpdate(session: ComparisonSession) = publish()

    override fun onSessionFinished(session: ComparisonSession) {
        publish()
    }

    fun addListener(listener: (JSONObject) -> Unit) {
        synchronized(listeners) { listeners += listener }
    }

    fun removeListener(listener: (JSONObject) -> Unit) {
        synchronized(listeners) { listeners -= listener }
    }

    private fun publish() {
        val snapshot = snapshot()
        synchronized(listeners) { listeners.toList() }.forEach { runCatching { it(snapshot) } }
    }

    /** Current session state as JSON, safe to hand to Flutter or the overlay. */
    fun snapshot(): JSONObject {
        val session = SessionCoordinator.active
        val json = JSONObject()
        json.put("sessionId", session?.id ?: "")
        json.put("state", (session?.state ?: SessionState.IDLE).name)
        json.put("running", isRunning)
        json.put("currentProvider", session?.currentAdapter?.providerId ?: JSONObject.NULL)
        json.put("best", session?.best?.let(::outcomeJson) ?: JSONObject.NULL)

        val providers = JSONArray()
        session?.results?.forEach { providers.put(outcomeJson(it)) }
        json.put("providers", providers)
        return json
    }

    private fun outcomeJson(outcome: ProviderOutcome) = JSONObject().apply {
        put("id", outcome.providerId)
        put("name", outcome.providerName)
        put("package", outcome.packageName)
        put("installed", outcome.installed)
        put("succeeded", outcome.succeeded)
        put("failure", outcome.failure?.name ?: JSONObject.NULL)
        put("note", outcome.note ?: JSONObject.NULL)
        outcome.fare?.let { fare ->
            put("status", fare.status.name)
            put("confidence", fare.confidence)
            put("timestamp", fare.timestamp)
            put("amount", fare.amount ?: JSONObject.NULL)
            put("currency", fare.currency ?: JSONObject.NULL)
            put("rawText", fare.rawText ?: JSONObject.NULL)
        }
    }

    /** For the debug screen: what is switched on, and what is installed. */
    fun diagnostics(context: Context): JSONObject = JSONObject().apply {
        put("accessibilityEnabled", GoGoAccessibilityService.isEnabled(context))
        put("accessibilityConnected", GoGoAccessibilityService.isConnected)
        val installed = JSONArray()
        ProviderRegistry.all().forEach { adapter ->
            installed.put(
                JSONObject()
                    .put("id", adapter.providerId)
                    .put("name", adapter.providerName)
                    .put("package", adapter.packageName)
                    .put("installed", ProviderLauncher.isInstalled(context, adapter.packageName)),
            )
        }
        put("providers", installed)
        put("session", snapshot())
    }

    fun logs(): JSONArray = JSONArray().apply {
        AutomationLog.snapshot().forEach { entry ->
            put(
                JSONObject()
                    .put("timestamp", entry.timestamp)
                    .put("session", entry.sessionId)
                    .put("provider", entry.provider ?: JSONObject.NULL)
                    .put("event", entry.event)
                    .put("detail", AutomationLog.redact(entry.detail)),
            )
        }
    }

    fun openAccessibilitySettings(context: Context) {
        context.startActivity(
            Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
        )
    }

    fun tripFrom(args: Map<*, *>): TripContext = TripContext(
        pickupLabel = args["pickupLabel"] as? String ?: "",
        pickupLat = (args["pickupLat"] as? Number)?.toDouble() ?: 0.0,
        pickupLon = (args["pickupLon"] as? Number)?.toDouble() ?: 0.0,
        destinationLabel = args["destinationLabel"] as? String ?: "",
        destinationLat = (args["destinationLat"] as? Number)?.toDouble() ?: 0.0,
        destinationLon = (args["destinationLon"] as? Number)?.toDouble() ?: 0.0,
        category = args["category"] as? String,
    )
}
