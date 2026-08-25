package com.gogo.rides.automation

import android.util.Log
import com.gogo.rides.BuildConfig

/**
 * Structured, in-memory log of what the automation did, so a run can be
 * inspected from the debug screen as well as from logcat.
 *
 * Screen text from a provider's app is only kept in debug builds — in release
 * it is summarised, never stored verbatim.
 */
object AutomationLog {

    const val TAG = "GoGoAutomation"
    private const val CAPACITY = 300

    data class Entry(
        val timestamp: Long,
        val sessionId: String,
        val provider: String?,
        val event: String,
        val detail: String,
    )

    private val entries = ArrayDeque<Entry>()
    private val listeners = mutableListOf<(Entry) -> Unit>()

    @Synchronized
    fun log(sessionId: String, provider: String?, event: String, detail: String = "") {
        val entry = Entry(System.currentTimeMillis(), sessionId, provider, event, detail)
        entries.addLast(entry)
        while (entries.size > CAPACITY) entries.removeFirst()
        Log.d(TAG, "[$sessionId]${provider?.let { " [$it]" } ?: ""} $event ${redact(detail)}")
        listeners.toList().forEach { runCatching { it(entry) } }
    }

    /** Screen text is developer-only; release builds keep the shape, not the content. */
    fun redact(detail: String): String =
        if (BuildConfig.DEBUG) detail else "${detail.length} chars"

    @Synchronized
    fun snapshot(): List<Entry> = entries.toList()

    @Synchronized
    fun clear() = entries.clear()

    @Synchronized
    fun addListener(listener: (Entry) -> Unit) {
        listeners += listener
    }

    @Synchronized
    fun removeListener(listener: (Entry) -> Unit) {
        listeners -= listener
    }
}
