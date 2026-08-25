package com.gogo.rides

import com.gogo.rides.automation.ExtractionStatus
import com.gogo.rides.automation.FareParser
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * These strings are the shapes a ride app's screen text takes. They are test
 * fixtures for the parser only — no fare here is ever shown in the app.
 */
class FareParserTest {

    private val parser = FareParser()

    @Test
    fun `accepts a fare with a currency marker`() {
        val result = parser.parse("pathao", listOf("Estimated fare", "Rs. 350"))
        assertEquals(ExtractionStatus.ACCEPTED, result.status)
        assertEquals(350.0, result.amount!!, 0.001)
        assertEquals("Rs.", result.currency)
    }

    @Test
    fun `ignores ETA and distance next to the fare`() {
        val result = parser.parse(
            "yango",
            listOf("4 min away", "4.2 km", "Total NPR 420", "4.9 ★"),
        )
        assertEquals(ExtractionStatus.ACCEPTED, result.status)
        assertEquals(420.0, result.amount!!, 0.001)
    }

    @Test
    fun `ignores discount percentages`() {
        val result = parser.parse("yango", listOf("-30% off your ride", "Fare Rs 250"))
        assertEquals(250.0, result.amount!!, 0.001)
    }

    @Test
    fun `a bare number with no currency and no fare wording is not a candidate`() {
        val result = parser.parse("indrive", listOf("3", "Home", "Work"))
        assertEquals(ExtractionStatus.NO_CANDIDATES, result.status)
        assertNull(result.amount)
    }

    @Test
    fun `two competing fares are ambiguous, not a guess`() {
        val result = parser.parse("indrive", listOf("Fare NPR 300", "Fare NPR 380"))
        assertEquals(ExtractionStatus.AMBIGUOUS, result.status)
        assertNull(result.amount)
    }

    @Test
    fun `thousands separators parse`() {
        val result = parser.parse("uber", listOf("Estimated total Rs. 1,250"))
        assertEquals(1250.0, result.amount!!, 0.001)
    }

    @Test
    fun `implausible amounts are rejected`() {
        val result = parser.parse("pathao", listOf("Rs. 2"))
        assertTrue(result.status != ExtractionStatus.ACCEPTED)
        assertNull(result.amount)
    }

    @Test
    fun `wallet balance is not a fare`() {
        val result = parser.parse("pathao", listOf("Wallet balance Rs. 900"))
        assertTrue(result.status != ExtractionStatus.ACCEPTED)
    }

    @Test
    fun `empty screen yields no candidates`() {
        assertEquals(ExtractionStatus.NO_CANDIDATES, parser.parse("pathao", emptyList()).status)
    }

    @Test
    fun `candidates are reported even when nothing is accepted`() {
        val result = parser.parse("pathao", listOf("Wallet balance Rs. 900"))
        assertTrue(result.candidates.isNotEmpty())
    }
}
