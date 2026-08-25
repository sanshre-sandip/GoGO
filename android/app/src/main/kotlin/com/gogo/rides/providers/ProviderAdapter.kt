package com.gogo.rides.providers

import android.view.accessibility.AccessibilityNodeInfo
import com.gogo.rides.automation.AutomationLog
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

/** What the user wants to ride in. Providers name these differently. */
enum class RideCategory { ANY, BIKE, CAR }

data class TripContext(
    val pickupLabel: String,
    val pickupLat: Double,
    val pickupLon: Double,
    val destinationLabel: String,
    val destinationLat: Double,
    val destinationLon: Double,
    val category: RideCategory = RideCategory.ANY,
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

    /** Called before this provider's turn; [sessionId] is for logging. */
    fun reset(sessionId: String)
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

    /**
     * Wording each provider uses for a ride class. Unverified until seen in a
     * real run — a miss means GoGo takes whatever class the app defaulted to
     * and says so, rather than claiming a class it did not choose.
     */
    protected open val categoryHints: Map<RideCategory, List<String>> = mapOf(
        RideCategory.BIKE to listOf("bike", "moto"),
        RideCategory.CAR to listOf("car", "economy", "ride"),
    )

    private val parser = FareParser()
    private var typedDestination = false
    private var openedSearch = false
    private var sessionId = "-"

    /** The class GoGo actually managed to select, if any. */
    private var chosenClass: String? = null

    override fun reset(sessionId: String) {
        this.sessionId = sessionId
        typedDestination = false
        openedSearch = false
        chosenClass = null
    }

    private fun log(event: String, detail: String = "") =
        AutomationLog.log(sessionId, providerId, event, detail)

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

    /**
     * Types the destination into the provider's own search UI.
     *
     * Providers differ in whether the home screen has a real text field or a
     * "Where to?" button that opens a search screen, so this walks: open
     * search → type → pick the first suggestion → confirm. Every step is
     * logged, because these selectors are the part that has to be tuned
     * against each real app.
     */
    override fun enterTrip(root: AccessibilityNodeInfo?, trip: TripContext): TripEntryResult {
        if (root == null) return TripEntryResult.IN_PROGRESS

        val editable = NodeTools.findInput(root, destinationHints)?.takeIf { it.isEditable }

        if (!typedDestination) {
            if (editable == null) {
                // No field yet: tap whatever opens the search screen.
                val entry = NodeTools.findClickable(root, destinationHints)
                if (entry == null) {
                    log("trip_no_entry_point", NodeTools.collectTexts(root).take(12).joinToString(" | "))
                    return TripEntryResult.IN_PROGRESS
                }
                val clicked = NodeTools.click(entry)
                openedSearch = openedSearch || clicked
                log("trip_open_search", "clicked=$clicked")
                return TripEntryResult.IN_PROGRESS
            }

            val typed = NodeTools.setText(editable, trip.destinationLabel)
            log("trip_type", "ok=$typed text=${trip.destinationLabel}")
            if (!typed) return TripEntryResult.UNSUPPORTED
            typedDestination = true
            return TripEntryResult.IN_PROGRESS
        }

        // Typed: take the first suggestion the provider offers.
        val suggestion = NodeTools.firstListItem(root, ignore = trip.destinationLabel)
        if (suggestion != null) {
            val label = suggestion.text?.toString().orEmpty()
            val clicked = NodeTools.click(suggestion)
            log("trip_suggestion", "clicked=$clicked label=$label")
            if (clicked) return TripEntryResult.IN_PROGRESS
        }

        selectCategory(root, trip.category)

        val confirm = NodeTools.findClickable(root, confirmHints)
        if (confirm != null && NodeTools.click(confirm)) {
            log("trip_confirm", confirm.text?.toString().orEmpty())
            return TripEntryResult.DONE
        }

        // The destination is in; the provider may already be pricing it.
        return if (editable == null) TripEntryResult.DONE else TripEntryResult.IN_PROGRESS
    }

    /**
     * Taps the requested ride class if this provider shows one. Best effort:
     * when nothing matches, the provider's own default class stands and
     * [chosenClass] stays null so the fare is not labelled with a guess.
     */
    private fun selectCategory(root: AccessibilityNodeInfo?, category: RideCategory) {
        if (category == RideCategory.ANY || chosenClass != null) return
        val hints = categoryHints[category] ?: return

        val option = NodeTools.findClickable(root, hints) ?: return
        val label = option.text?.toString()?.trim()?.takeIf { it.isNotEmpty() }
            ?: option.contentDescription?.toString()?.trim()
        if (NodeTools.click(option)) {
            chosenClass = label ?: category.name.lowercase()
            log("category_selected", "${category.name} as ${chosenClass}")
        }
    }

    override fun extractFare(root: AccessibilityNodeInfo?): FareResult =
        parser
            .parse(providerId, NodeTools.collectTexts(root), fareHints, rejectHints)
            .copy(vehicleType = chosenClass)
}
