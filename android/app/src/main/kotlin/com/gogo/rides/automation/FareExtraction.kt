package com.gogo.rides.automation

/** Why a provider did or did not yield a usable fare. */
enum class ExtractionStatus {
    ACCEPTED,
    LOW_CONFIDENCE,
    AMBIGUOUS,
    NO_CANDIDATES,
}

/** One number GoGo found on screen, before it is judged. */
data class FareCandidate(
    val rawText: String,
    val amount: Double,
    val currency: String,
    val confidence: Double,
    val reasons: List<String>,
)

/** The outcome of looking at one provider's screen. */
data class FareResult(
    val providerId: String,
    val status: ExtractionStatus,
    val amount: Double? = null,
    val currency: String? = null,
    val rawText: String? = null,
    val confidence: Double = 0.0,
    val timestamp: Long = System.currentTimeMillis(),
    val candidates: List<FareCandidate> = emptyList(),
) {
    val accepted get() = status == ExtractionStatus.ACCEPTED && amount != null
}

/**
 * Turns the text visible on a provider's screen into a fare, or into an honest
 * "no fare found".
 *
 * The pipeline is deliberately conservative: a number only becomes a candidate
 * if it carries a currency marker or sits next to fare wording, and the winner
 * must beat both an absolute confidence floor and the runner-up. Picking "the
 * first number on screen" would happily return an ETA, a rating or a discount.
 */
class FareParser(
    private val currencies: List<String> = listOf("NPR", "Rs.", "Rs", "रू", "रु", "₨"),
    private val minConfidence: Double = 0.55,
) {

    /**
     * [texts] is every visible string collected from the provider's window, in
     * traversal order. [fareHints] are provider-specific words that make a
     * number more likely to be the fare; [rejectHints] the opposite.
     */
    fun parse(
        providerId: String,
        texts: List<String>,
        fareHints: List<String> = DEFAULT_FARE_HINTS,
        rejectHints: List<String> = DEFAULT_REJECT_HINTS,
    ): FareResult {
        val candidates = texts
            .flatMap { candidatesIn(it, fareHints, rejectHints) }
            .sortedByDescending { it.confidence }

        if (candidates.isEmpty()) {
            return FareResult(providerId, ExtractionStatus.NO_CANDIDATES)
        }

        val best = candidates.first()
        if (best.confidence < minConfidence) {
            return FareResult(
                providerId = providerId,
                status = ExtractionStatus.LOW_CONFIDENCE,
                confidence = best.confidence,
                rawText = best.rawText,
                candidates = candidates,
            )
        }

        // Two different amounts that both look like the fare: refuse to guess.
        val rival = candidates.drop(1).firstOrNull { it.amount != best.amount }
        if (rival != null && best.confidence - rival.confidence < AMBIGUITY_MARGIN) {
            return FareResult(
                providerId = providerId,
                status = ExtractionStatus.AMBIGUOUS,
                confidence = best.confidence,
                rawText = "${best.rawText} / ${rival.rawText}",
                candidates = candidates,
            )
        }

        return FareResult(
            providerId = providerId,
            status = ExtractionStatus.ACCEPTED,
            amount = best.amount,
            currency = best.currency,
            rawText = best.rawText,
            confidence = best.confidence,
            candidates = candidates,
        )
    }

    private fun candidatesIn(
        text: String,
        fareHints: List<String>,
        rejectHints: List<String>,
    ): List<FareCandidate> {
        val lower = text.lowercase()
        val hasFareWord = fareHints.any { lower.contains(it) }
        val hasRejectWord = rejectHints.any { lower.contains(it) }

        return NUMBER.findAll(text).mapNotNull { match ->
            val amount = match.value.replace(",", "").toDoubleOrNull() ?: return@mapNotNull null
            val before = text.take(match.range.first)
            val after = text.substring(match.range.last + 1)
            val currency = currencyNear(before, after) ?: ""
            val reasons = mutableListOf<String>()

            // A bare number with no currency and no fare wording is noise.
            if (currency.isEmpty() && !hasFareWord) return@mapNotNull null

            var score = 0.0
            if (currency.isNotEmpty()) {
                score += 0.5
                reasons += "currency:$currency"
            }
            if (hasFareWord) {
                score += 0.3
                reasons += "fare-wording"
            }
            if (unitFollows(after)) {
                score -= 0.6
                reasons += "unit-suffix"
            }
            if (hasRejectWord) {
                score -= 0.4
                reasons += "reject-wording"
            }
            if (amount < MIN_PLAUSIBLE_FARE || amount > MAX_PLAUSIBLE_FARE) {
                score -= 0.5
                reasons += "implausible-amount"
            }
            // "-30%", "4.9 ★" and similar never look like a fare.
            if (after.trimStart().startsWith("%") || before.trimEnd().endsWith("%")) {
                score -= 0.6
                reasons += "percentage"
            }

            FareCandidate(
                rawText = text.trim(),
                amount = amount,
                currency = currency.ifEmpty { "" },
                confidence = score.coerceIn(0.0, 1.0),
                reasons = reasons,
            )
        }.toList()
    }

    private fun currencyNear(before: String, after: String): String? {
        val tailOfBefore = before.takeLast(8)
        val headOfAfter = after.take(8)
        return currencies.firstOrNull { c ->
            tailOfBefore.contains(c, ignoreCase = true) || headOfAfter.contains(c, ignoreCase = true)
        }
    }

    private fun unitFollows(after: String): Boolean =
        UNIT_SUFFIX.containsMatchIn(after.trimStart().take(12))

    companion object {
        /** 1,234 / 1234 / 1234.50 */
        private val NUMBER = Regex("""\d{1,3}(?:,\d{3})+(?:\.\d+)?|\d+(?:\.\d+)?""")

        /** Minutes, kilometres, seats, ratings — never a fare. */
        private val UNIT_SUFFIX = Regex(
            """^\s*(min|mins|minute|minutes|km|k\.m|m\b|meters|sec|s\b|★|star|seats?|%)""",
            RegexOption.IGNORE_CASE,
        )

        val DEFAULT_FARE_HINTS = listOf(
            "fare", "price", "total", "estimated", "estimate", "cost", "pay", "amount",
        )

        /** Wording that usually decorates a number that is *not* the fare. */
        val DEFAULT_REJECT_HINTS = listOf(
            "off", "discount", "promo", "coupon", "cashback", "wallet", "balance",
            "rating", "rated", "otp", "away", "eta", "arriv",
        )

        private const val MIN_PLAUSIBLE_FARE = 20.0
        private const val MAX_PLAUSIBLE_FARE = 100_000.0
        private const val AMBIGUITY_MARGIN = 0.15
    }
}
