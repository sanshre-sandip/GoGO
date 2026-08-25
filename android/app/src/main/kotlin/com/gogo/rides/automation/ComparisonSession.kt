package com.gogo.rides.automation

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.view.accessibility.AccessibilityNodeInfo
import com.gogo.rides.ProviderLauncher
import com.gogo.rides.providers.ProviderAdapter
import com.gogo.rides.providers.ScreenState
import com.gogo.rides.providers.TripContext
import com.gogo.rides.providers.TripEntryResult
import java.util.UUID

enum class SessionState {
    IDLE,
    PREPARING_PROVIDER,
    LAUNCHING_PROVIDER,
    WAITING_FOR_UI,
    ENTERING_TRIP_DATA,
    WAITING_FOR_FARE,
    FARE_DETECTED,
    PROVIDER_FAILED,
    NEXT_PROVIDER,
    COMPARING,
    COMPLETED,
    CANCELLED,
}

/** Why a provider produced no fare. Never replaced by a number. */
enum class FailureReason {
    APP_NOT_INSTALLED,
    ACCESSIBILITY_UNAVAILABLE,
    LAUNCH_FAILED,
    BLOCKED_SCREEN,
    TRIP_ENTRY_UNAVAILABLE,
    FARE_NOT_FOUND,
    LOW_CONFIDENCE,
    AMBIGUOUS,
    TIMEOUT,
    CANCELLED,
}

data class ProviderOutcome(
    val providerId: String,
    val providerName: String,
    val packageName: String,
    val installed: Boolean,
    val fare: FareResult? = null,
    val failure: FailureReason? = null,
    val note: String? = null,
) {
    val succeeded get() = fare?.accepted == true
}

/**
 * Drives one comparison from start to finish: for each provider in turn, open
 * it, wait for its UI, enter the trip, wait for the app's own fare, read it,
 * then move on. Progress is event-driven — accessibility events advance the
 * machine, and timers only exist to give up.
 *
 * Nothing here can invent a fare: a provider either yields an accepted
 * [FareResult] or a [FailureReason].
 */
class ComparisonSession(
    private val context: Context,
    private val trip: TripContext,
    private val adapters: List<ProviderAdapter>,
    private val listener: Listener,
    private val clock: Handler = Handler(Looper.getMainLooper()),
) {

    interface Listener {
        fun onSessionUpdate(session: ComparisonSession)
        fun onSessionFinished(session: ComparisonSession)
    }

    val id: String = UUID.randomUUID().toString().take(8)

    var state: SessionState = SessionState.IDLE
        private set

    private val outcomes = LinkedHashMap<String, ProviderOutcome>()
    private var index = -1
    private var lastTripEntryAttempt = 0L
    private var lastScreen: ScreenState? = null
    private var lastScreenLog = 0L
    private var lastTextDump = 0L
    private var timeoutToken: Runnable? = null

    val currentAdapter: ProviderAdapter? get() = adapters.getOrNull(index)
    val currentPackage: String? get() = currentAdapter?.packageName
    val results: List<ProviderOutcome> get() = outcomes.values.toList()

    /** Cheapest accepted fare, or null when nothing was extracted. */
    val best: ProviderOutcome?
        get() = results.filter { it.succeeded }.minByOrNull { it.fare!!.amount!! }

    fun start() {
        AutomationLog.log(id, null, "session_start", "providers=${adapters.size}")
        adapters.forEach { adapter ->
            outcomes[adapter.providerId] = ProviderOutcome(
                providerId = adapter.providerId,
                providerName = adapter.providerName,
                packageName = adapter.packageName,
                installed = ProviderLauncher.isInstalled(context, adapter.packageName),
            )
        }
        if (!GoGoAccessibilityService.isConnected) {
            failAll(FailureReason.ACCESSIBILITY_UNAVAILABLE)
            finish(SessionState.COMPLETED)
            return
        }
        nextProvider()
    }

    fun cancel(note: String? = null) {
        if (state == SessionState.COMPLETED || state == SessionState.CANCELLED) return
        clearTimeout()
        currentAdapter?.let { adapter ->
            record(adapter.providerId) { it.copy(failure = FailureReason.CANCELLED, note = note) }
        }
        AutomationLog.log(id, currentAdapter?.providerId, "session_cancelled", note ?: "")
        finish(SessionState.CANCELLED)
    }

    // --- state machine -------------------------------------------------------

    private fun nextProvider() {
        clearTimeout()
        transition(SessionState.NEXT_PROVIDER)
        index++

        val adapter = currentAdapter
        if (adapter == null) {
            transition(SessionState.COMPARING)
            AutomationLog.log(id, null, "comparing", "accepted=${results.count { it.succeeded }}")
            finish(SessionState.COMPLETED)
            return
        }

        adapter.reset(id)
        transition(SessionState.PREPARING_PROVIDER)

        if (!ProviderLauncher.isInstalled(context, adapter.packageName)) {
            AutomationLog.log(id, adapter.providerId, "not_installed", adapter.packageName)
            record(adapter.providerId) { it.copy(failure = FailureReason.APP_NOT_INSTALLED) }
            nextProvider()
            return
        }

        transition(SessionState.LAUNCHING_PROVIDER)
        val launch = ProviderLauncher.open(context, adapter.packageName, null)
        AutomationLog.log(id, adapter.providerId, "launch", launch)
        if (launch != "opened") {
            record(adapter.providerId) { it.copy(failure = FailureReason.LAUNCH_FAILED) }
            nextProvider()
            return
        }

        transition(SessionState.WAITING_FOR_UI)
        armTimeout(PROVIDER_BUDGET_MS) {
            AutomationLog.log(id, adapter.providerId, "timeout", state.name)
            record(adapter.providerId) {
                it.copy(failure = FailureReason.TIMEOUT, note = "Timed out in ${state.name}")
            }
            transition(SessionState.PROVIDER_FAILED)
            nextProvider()
        }
    }

    /** Called by the accessibility service for the provider we are driving. */
    fun onProviderScreenChanged(root: AccessibilityNodeInfo?) {
        val adapter = currentAdapter ?: return
        if (state == SessionState.COMPLETED || state == SessionState.CANCELLED) return

        val screen = adapter.detectScreen(root)
        val now = System.currentTimeMillis()

        // Providers fire content-change events constantly; log a screen only
        // when it changes, or once in a while so a stall is still visible.
        if (screen != lastScreen || now - lastScreenLog > SCREEN_LOG_INTERVAL_MS) {
            AutomationLog.log(id, adapter.providerId, "screen", screen.name)
            lastScreen = screen
            lastScreenLog = now
        }

        // When GoGo cannot place a screen, the words on it are the only way to
        // teach the adapter. Debug builds keep them; release redacts them.
        if (screen == ScreenState.UNKNOWN && now - lastTextDump > TEXT_DUMP_INTERVAL_MS) {
            lastTextDump = now
            AutomationLog.log(
                id,
                adapter.providerId,
                "screen_texts",
                NodeTools.collectTexts(root).take(25).joinToString(" | "),
            )
        }

        when (screen) {
            ScreenState.BLOCKED -> {
                record(adapter.providerId) {
                    it.copy(
                        failure = FailureReason.BLOCKED_SCREEN,
                        note = "The app needs you to sign in or grant a permission first.",
                    )
                }
                transition(SessionState.PROVIDER_FAILED)
                nextProvider()
            }

            ScreenState.FARE_VISIBLE -> readFare(adapter, root)

            ScreenState.TRIP_INPUT -> enterTrip(adapter, root)

            ScreenState.QUOTING -> {
                transition(SessionState.WAITING_FOR_FARE)
                readFare(adapter, root, quietly = true)
            }

            ScreenState.LOADING, ScreenState.UNKNOWN -> {
                // Still settling — the provider timeout is what gives up.
                if (state == SessionState.WAITING_FOR_UI) enterTrip(adapter, root)
            }
        }
    }

    private fun enterTrip(adapter: ProviderAdapter, root: AccessibilityNodeInfo?) {
        val now = System.currentTimeMillis()
        if (now - lastTripEntryAttempt < TRIP_ENTRY_THROTTLE_MS) return
        lastTripEntryAttempt = now

        transition(SessionState.ENTERING_TRIP_DATA)
        when (adapter.enterTrip(root, trip)) {
            TripEntryResult.DONE -> {
                AutomationLog.log(id, adapter.providerId, "trip_entered", trip.destinationLabel)
                transition(SessionState.WAITING_FOR_FARE)
            }

            TripEntryResult.IN_PROGRESS -> Unit

            TripEntryResult.UNSUPPORTED -> {
                AutomationLog.log(id, adapter.providerId, "trip_entry_unavailable")
                record(adapter.providerId) {
                    it.copy(
                        failure = FailureReason.TRIP_ENTRY_UNAVAILABLE,
                        note = "Trip entry unavailable",
                    )
                }
                transition(SessionState.PROVIDER_FAILED)
                nextProvider()
            }
        }
    }

    private fun readFare(
        adapter: ProviderAdapter,
        root: AccessibilityNodeInfo?,
        quietly: Boolean = false,
    ) {
        val fare = adapter.extractFare(root)
        AutomationLog.log(
            id,
            adapter.providerId,
            "fare_${fare.status.name.lowercase()}",
            "raw=${fare.rawText ?: "-"} confidence=${"%.2f".format(fare.confidence)}",
        )

        when (fare.status) {
            ExtractionStatus.ACCEPTED -> {
                record(adapter.providerId) { it.copy(fare = fare, failure = null, note = null) }
                transition(SessionState.FARE_DETECTED)
                nextProvider()
            }

            // Keep waiting: the screen may still be rendering the real number.
            ExtractionStatus.LOW_CONFIDENCE,
            ExtractionStatus.AMBIGUOUS,
            ExtractionStatus.NO_CANDIDATES,
            -> if (!quietly) {
                record(adapter.providerId) {
                    it.copy(
                        fare = fare,
                        failure = when (fare.status) {
                            ExtractionStatus.LOW_CONFIDENCE -> FailureReason.LOW_CONFIDENCE
                            ExtractionStatus.AMBIGUOUS -> FailureReason.AMBIGUOUS
                            else -> FailureReason.FARE_NOT_FOUND
                        },
                    )
                }
            }
        }
    }

    private fun failAll(reason: FailureReason) {
        outcomes.keys.toList().forEach { key -> record(key) { it.copy(failure = reason) } }
    }

    private fun record(providerId: String, update: (ProviderOutcome) -> ProviderOutcome) {
        outcomes[providerId]?.let { outcomes[providerId] = update(it) }
        listener.onSessionUpdate(this)
    }

    private fun transition(next: SessionState) {
        if (state == next) return
        state = next
        AutomationLog.log(id, currentAdapter?.providerId, "state", next.name)
        listener.onSessionUpdate(this)
    }

    private fun finish(end: SessionState) {
        clearTimeout()
        state = end
        AutomationLog.log(id, null, "session_end", end.name)
        listener.onSessionFinished(this)
    }

    private fun armTimeout(delayMs: Long, action: () -> Unit) {
        clearTimeout()
        val token = Runnable { action() }
        timeoutToken = token
        clock.postDelayed(token, delayMs)
    }

    private fun clearTimeout() {
        timeoutToken?.let { clock.removeCallbacks(it) }
        timeoutToken = null
    }

    companion object {
        /** How long any one provider gets, start to fare. */
        private const val PROVIDER_BUDGET_MS = 25_000L

        /** Providers re-render constantly; don't retype on every event. */
        private const val TRIP_ENTRY_THROTTLE_MS = 1_200L

        /** A stalled provider still gets a heartbeat line. */
        private const val SCREEN_LOG_INTERVAL_MS = 5_000L
        private const val TEXT_DUMP_INTERVAL_MS = 3_000L
    }
}

/** Holds the one session that may be running, so the service can find it. */
object SessionCoordinator {
    @Volatile
    var active: ComparisonSession? = null
}
