package com.gogo.rides.providers

import android.view.accessibility.AccessibilityNodeInfo
import com.gogo.rides.automation.FareParser
import com.gogo.rides.automation.FareResult
import com.gogo.rides.automation.NodeTools

/** Where a provider's app currently is, as far as GoGo can tell. */
enum class ScreenState {
    UNKNOWN,
    LOADING,
    /** Ready to accept a destination. */
    TRIP_INPUT,
    /** Destination entered, provider is working out a price. */
    QUOTING,
    /** A fare is on screen. */
    FARE_VISIBLE,
    /** Something GoGo cannot drive: login, OTP, permission prompt, error. */
    BLOCKED,
}

/** Outcome of trying to type the trip into a provider's own UI. */
enum class TripEntryResult {
    DONE,
    IN_PROGRESS,
    /** This provider's flow cannot be driven — report it, never fake a fare. */
    UNSUPPORTED,
}

data class TripContext(
    val pickupLabel: String,
    val pickupLat: Double,
    val pickupLon: Double,
    val destinationLabel: String,
    val destinationLat: Double,
    val destinationLon: Double,
    val category: String? = null,
)

/**
 * One ride app's automation logic. Everything provider-specific lives behind
 * this interface so the session manager stays provider-agnostic and new
 * providers can be added without touching it.
 */
interface ProviderAdapter {
    val providerId: String
    val providerName: String
    val packageName: String

    fun detectScreen(root: AccessibilityNodeInfo?): ScreenState
    fun enterTrip(root: AccessibilityNodeInfo?, trip: TripContext): TripEntryResult
    fun extractFare(root: AccessibilityNodeInfo?): FareResult
    fun reset()
}

/**
 * Shared heuristics: recognise screens by the words on them, type the
 * destination into the first plausible search field, and read the fare with
 * the shared parser using provider-specific wording.
 *
 * The word lists below are the part that must be confirmed against each real
 * app on a device — see `docs/automation-testing.md`. Until then every adapter
 * is expected to report failures honestly rather than approximate a fare.
 */
abstract class BaseAdapter(
    override val providerId: String,
    override val providerName: String,
    override val packageName: String,
) : ProviderAdapter {

    protected open val destinationHints =
        listOf("where to", "destination", "search", "drop", "going to", "enter location")
    protected open val quotingHints = listOf("finding", "searching", "loading", "calculating")
    protected open val blockedHints =
        listOf("log in", "login", "sign in", "otp", "verify", "no internet", "try again", "allow")
    protected open val fareHints = FareParser.DEFAULT_FARE_HINTS
    protected open val rejectHints = FareParser.DEFAULT_REJECT_HINTS
    protected open val confirmHints = listOf("confirm", "search", "done", "next", "continue")

    private val parser = FareParser()
    private var typedDestination = false

    override fun reset() {
        typedDestination = false
    }

    override fun detectScreen(root: AccessibilityNodeInfo?): ScreenState {
        if (root == null) return ScreenState.UNKNOWN
        val texts = NodeTools.collectTexts(root).map { it.lowercase() }
        if (texts.isEmpty()) return ScreenState.LOADING

        fun any(hints: List<String>) = texts.any { t -> hints.any { t.contains(it) } }

        return when {
            any(blockedHints) -> ScreenState.BLOCKED
            parser.parse(providerId, NodeTools.collectTexts(root), fareHints, rejectHints)
                .accepted -> ScreenState.FARE_VISIBLE
            any(quotingHints) -> ScreenState.QUOTING
            any(destinationHints) -> ScreenState.TRIP_INPUT
            else -> ScreenState.UNKNOWN
        }
    }

    override fun enterTrip(root: AccessibilityNodeInfo?, trip: TripContext): TripEntryResult {
        if (root == null) return TripEntryResult.IN_PROGRESS

        if (!typedDestination) {
            val field = NodeTools.findInput(root, destinationHints)
                ?: NodeTools.findClickable(root, destinationHints)?.also { NodeTools.click(it) }
                ?: return TripEntryResult.IN_PROGRESS

            if (field.isEditable) {
                if (!NodeTools.setText(field, trip.destinationLabel)) {
                    return TripEntryResult.UNSUPPORTED
                }
                typedDestination = true
            }
            return TripEntryResult.IN_PROGRESS
        }

        // Destination typed: take the first suggestion, then any confirm button.
        val suggestion = NodeTools.findClickable(root, listOf(trip.destinationLabel.take(12)))
        if (suggestion != null && NodeTools.click(suggestion)) return TripEntryResult.IN_PROGRESS

        val confirm = NodeTools.findClickable(root, confirmHints)
        if (confirm != null && NodeTools.click(confirm)) return TripEntryResult.DONE

        return TripEntryResult.IN_PROGRESS
    }

    override fun extractFare(root: AccessibilityNodeInfo?): FareResult =
        parser.parse(providerId, NodeTools.collectTexts(root), fareHints, rejectHints)
}
