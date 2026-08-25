package com.gogo.rides.providers

import com.gogo.rides.automation.FareParser

/**
 * Per-provider wording. Package ids were verified on a physical device (see
 * docs/provider-verification.md); the screen wording below is a starting point
 * to be confirmed per app from the automation logs on hardware.
 */

class PathaoAdapter : BaseAdapter("pathao", "Pathao", "com.pathao.user") {
    override val destinationHints =
        listOf("where to", "destination", "search location", "drop off", "drop-off")
    override val fareHints = FareParser.DEFAULT_FARE_HINTS + listOf("fare", "estimated fare")
    override val confirmHints = listOf("confirm", "confirm pickup", "next", "continue")
    override val categoryHints = mapOf(
        RideCategory.BIKE to listOf("bike", "moto"),
        RideCategory.CAR to listOf("car", "cab", "ride"),
    )
}

/**
 * inDrive asks the passenger to *offer* a price rather than quoting one, so a
 * "fare" may be a suggested offer instead of a firm price. It is reported like
 * any other detected number, with its own wording.
 */
class InDriveAdapter : BaseAdapter("indrive", "inDrive", "sinet.startup.inDriver") {
    override val destinationHints = listOf("where to", "destination", "to", "search")
    override val fareHints =
        FareParser.DEFAULT_FARE_HINTS + listOf("your price", "offer", "recommended")
    override val confirmHints = listOf("next", "continue", "confirm", "order")
    override val categoryHints = mapOf(
        RideCategory.BIKE to listOf("moto", "bike"),
        RideCategory.CAR to listOf("city", "car"),
    )
}

class YangoAdapter : BaseAdapter("yango", "Yango", "com.yandex.yango") {
    override val destinationHints = listOf("where to", "destination", "search", "address")
    override val fareHints = FareParser.DEFAULT_FARE_HINTS + listOf("from rs", "from npr", "ride")
    override val confirmHints = listOf("select service classes", "order", "confirm", "next")

    // Seen on the device: Yango lists Fastest / Bike / Economy / Comfort.
    override val categoryHints = mapOf(
        RideCategory.BIKE to listOf("bike"),
        RideCategory.CAR to listOf("economy", "comfort", "fastest"),
    )
}

class UberAdapter : BaseAdapter("uber", "Uber", "com.ubercab") {
    override val destinationHints = listOf("where to", "destination", "enter destination")
    override val confirmHints = listOf("confirm", "request", "next", "choose")
    override val categoryHints = mapOf(
        RideCategory.BIKE to listOf("moto", "bike"),
        RideCategory.CAR to listOf("uberx", "uber go", "go", "car"),
    )
}

object ProviderRegistry {
    /** Order the session walks through. */
    fun all(): List<ProviderAdapter> =
        listOf(PathaoAdapter(), InDriveAdapter(), YangoAdapter(), UberAdapter())

    fun byId(id: String): ProviderAdapter? = all().firstOrNull { it.providerId == id }
}
