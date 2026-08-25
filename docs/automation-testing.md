# Testing the comparison automation on a real phone

Nothing in the automation path can be trusted from a green build. The adapters
drive other companies' UIs, and those UIs are the one thing this repo cannot
test for you. Every provider adapter is **unverified** until it has been run
through this procedure and its log inspected.

## Setup

1. Enable Developer options and USB debugging on the phone.
2. `flutter install --debug -d <device-id>`
3. Open GoGo → Settings → turn on **Floating Assistant** (grants the overlay
   permission).
4. Settings → **Automation debug** → *Open Accessibility settings* → enable
   **GoGo ride comparison**.
5. Grant location when GoGo asks.
6. Sign in to each provider app you want compared, and let each one have
   location. A logged-out app reports `BLOCKED_SCREEN` — by design.

## Run a comparison

1. Home → pick a destination → **COMPARE RIDES**.
2. Watch the phone: GoGo brings each installed provider to the front in turn.
3. Watch the log at the same time:

```bash
adb logcat -c && adb logcat -s GoGoAutomation:D
```

Each provider produces a trace like:

```
[a1b2c3d4] state PREPARING_PROVIDER
[a1b2c3d4] [pathao] launch opened
[a1b2c3d4] [pathao] screen TRIP_INPUT
[a1b2c3d4] [pathao] trip_entered Kathmandu Durbar Square
[a1b2c3d4] [pathao] screen FARE_VISIBLE
[a1b2c3d4] [pathao] fare_accepted raw=Rs. 350 confidence=0.92
```

## What to check

For every provider, compare the log against what the screen actually showed:

| Check | Why it matters |
|---|---|
| `screen` transitions match reality | Wrong `detectScreen` wording means the adapter never types the trip |
| `trip_entered` uses your destination | If absent, the field selector missed — the adapter needs that app's hints |
| `fare_accepted` amount == the number on screen | The whole point. A mismatch is a parser bug, report it with the `raw=` text |
| `fare_low_confidence` / `fare_ambiguous` | Tune `fareHints` / `rejectHints` for that adapter |
| `timeout` | The budget (25s) or the screen detection is wrong for that app |

Any mismatch between an extracted fare and the visible fare is a **bug, not a
tuning issue** — GoGo must show only what the provider displayed.

## Refining an adapter

The word lists in `providers/Adapters.kt` are the tuning surface. To see what a
provider's screen actually exposes, run a comparison and read the
`GoGoAutomation` log — `screen` and `fare_*` lines carry the collected text in
debug builds (release builds redact it).

## Known limits

- Providers that require a price *offer* rather than quoting one (inDrive) may
  surface a suggested amount rather than a firm fare. It is labelled by the
  adapter's own wording and still only reported if actually on screen.
- Deep links do not pre-fill trips (see `provider-verification.md`), so each
  adapter types the destination into the app's own search field.
- The session drives one provider at a time in the foreground. Android gives no
  supported way to price these apps in the background.
