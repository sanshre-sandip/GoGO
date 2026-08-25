package com.gogo.rides

import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.net.Uri

/**
 * Opens a provider's own app. Shared by the Flutter UI and the floating
 * assistant so both behave identically. GoGo never books a ride itself.
 */
object ProviderLauncher {

    /** "opened", "store" or "unavailable". */
    fun open(context: Context, packageName: String?, deepLink: String?): String {
        // A deep link is pinned to the provider's package so it cannot be
        // hijacked by a browser or another app.
        if (deepLink != null && launch(
                context,
                Intent(Intent.ACTION_VIEW, Uri.parse(deepLink)).apply {
                    if (packageName != null) setPackage(packageName)
                },
            )
        ) {
            return "opened"
        }

        if (packageName == null) return "unavailable"

        context.packageManager.getLaunchIntentForPackage(packageName)?.let {
            if (launch(context, it)) return "opened"
        }

        val store = Intent(Intent.ACTION_VIEW, Uri.parse("market://details?id=$packageName"))
        val web = Intent(
            Intent.ACTION_VIEW,
            Uri.parse("https://play.google.com/store/apps/details?id=$packageName"),
        )
        return if (launch(context, store) || launch(context, web)) "store" else "unavailable"
    }

    fun isInstalled(context: Context, packageName: String): Boolean =
        context.packageManager.getLaunchIntentForPackage(packageName) != null

    private fun launch(context: Context, intent: Intent): Boolean = try {
        context.startActivity(intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
        true
    } catch (_: ActivityNotFoundException) {
        false
    }
}
