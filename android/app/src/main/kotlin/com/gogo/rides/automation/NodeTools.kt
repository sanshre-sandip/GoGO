package com.gogo.rides.automation

import android.os.Bundle
import android.view.accessibility.AccessibilityNodeInfo

/**
 * Safe reads and actions over an accessibility tree.
 *
 * Every traversal is depth-capped and node-capped: a provider's screen can be
 * huge, and this runs on the main thread inside an AccessibilityService, where
 * a slow pass shows up as jank in whatever app the user is looking at.
 */
object NodeTools {

    private const val MAX_DEPTH = 24
    private const val MAX_NODES = 1500

    /** Every visible string on screen, in traversal order, de-duplicated. */
    fun collectTexts(root: AccessibilityNodeInfo?): List<String> {
        val out = LinkedHashSet<String>()
        walk(root) { node ->
            node.text?.toString()?.trim()?.takeIf { it.isNotEmpty() }?.let { out += it }
            node.contentDescription?.toString()?.trim()?.takeIf { it.isNotEmpty() }?.let { out += it }
        }
        return out.toList()
    }

    /** Node ids present on screen — used to recognise which screen we are on. */
    fun collectViewIds(root: AccessibilityNodeInfo?): Set<String> {
        val out = mutableSetOf<String>()
        walk(root) { node ->
            node.viewIdResourceName?.let { out += it }
        }
        return out
    }

    fun findFirst(
        root: AccessibilityNodeInfo?,
        predicate: (AccessibilityNodeInfo) -> Boolean,
    ): AccessibilityNodeInfo? {
        var found: AccessibilityNodeInfo? = null
        walk(root) { node ->
            if (found == null && predicate(node)) found = node
        }
        return found
    }

    /** First editable field whose text, hint or id mentions one of [hints]. */
    fun findInput(root: AccessibilityNodeInfo?, hints: List<String>): AccessibilityNodeInfo? =
        findFirst(root) { node ->
            node.isEditable && node.isVisibleToUser && mentions(node, hints)
        } ?: findFirst(root) { it.isEditable && it.isVisibleToUser }

    fun findClickable(root: AccessibilityNodeInfo?, hints: List<String>): AccessibilityNodeInfo? =
        findFirst(root) { node ->
            node.isVisibleToUser && mentions(node, hints) && clickableSelfOrParent(node) != null
        }

    private fun mentions(node: AccessibilityNodeInfo, hints: List<String>): Boolean {
        val haystack = buildString {
            node.text?.let { append(it).append(' ') }
            node.contentDescription?.let { append(it).append(' ') }
            node.hintText?.let { append(it).append(' ') }
            node.viewIdResourceName?.let { append(it) }
        }.lowercase()
        return hints.any { haystack.contains(it.lowercase()) }
    }

    /** Clicks the node, or the nearest ancestor that actually accepts clicks. */
    fun click(node: AccessibilityNodeInfo?): Boolean {
        val target = clickableSelfOrParent(node ?: return false) ?: return false
        return target.performAction(AccessibilityNodeInfo.ACTION_CLICK)
    }

    fun setText(node: AccessibilityNodeInfo?, text: String): Boolean {
        val target = node ?: return false
        if (!target.isEditable) return false
        val args = Bundle().apply {
            putCharSequence(AccessibilityNodeInfo.ACTION_ARGUMENT_SET_TEXT_CHARSEQUENCE, text)
        }
        return target.performAction(AccessibilityNodeInfo.ACTION_SET_TEXT, args)
    }

    /**
     * The first row of a suggestion list: the topmost clickable node that has
     * its own text and lives inside a scrollable container. Providers label
     * these rows with the matched address, not with what was typed, so they
     * cannot be found by matching the query.
     */
    fun firstListItem(root: AccessibilityNodeInfo?, ignore: String? = null): AccessibilityNodeInfo? {
        val list = findFirst(root) { it.isScrollable && it.isVisibleToUser } ?: return null
        return findFirst(list) { node ->
            val label = node.text?.toString()?.trim().orEmpty()
            node.isVisibleToUser &&
                label.isNotEmpty() &&
                !label.equals(ignore, ignoreCase = true) &&
                clickableSelfOrParent(node) != null
        }
    }

    fun scrollForward(root: AccessibilityNodeInfo?): Boolean {
        val scrollable = findFirst(root) { it.isScrollable && it.isVisibleToUser } ?: return false
        return scrollable.performAction(AccessibilityNodeInfo.ACTION_SCROLL_FORWARD)
    }

    private fun clickableSelfOrParent(node: AccessibilityNodeInfo): AccessibilityNodeInfo? {
        var current: AccessibilityNodeInfo? = node
        var hops = 0
        while (current != null && hops < 6) {
            if (current.isClickable && current.isEnabled) return current
            current = current.parent
            hops++
        }
        return null
    }

    private fun walk(root: AccessibilityNodeInfo?, visit: (AccessibilityNodeInfo) -> Unit) {
        val start = root ?: return
        var visited = 0
        val queue = ArrayDeque<Pair<AccessibilityNodeInfo, Int>>()
        queue += start to 0

        while (queue.isNotEmpty() && visited < MAX_NODES) {
            val (node, depth) = queue.removeFirst()
            visited++
            runCatching { visit(node) }
            if (depth >= MAX_DEPTH) continue
            for (i in 0 until node.childCount) {
                val child = runCatching { node.getChild(i) }.getOrNull() ?: continue
                queue += child to depth + 1
            }
        }
    }
}
