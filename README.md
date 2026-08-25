# GoGo — Find your better ride.

Local-first ride-comparison assistant. Pick a destination, choose what matters
(cheapest / nearest driver / fastest pickup), and GoGo ranks the available
options and explains its recommendation. No backend, no paid AI.

## Run

```bash
flutter pub get
flutter run                 # debug
flutter test                # unit tests for the comparison engine + models
flutter build apk --release # release APK
```

## How it works

- `lib/services/comparison_service.dart` — the ranking engine. Min–max
  normalizes price, driver distance and ETA (lower is better → higher score),
  weights them by the selected priorities, and picks the highest total.
  Deterministic and fully unit-tested.
- `lib/services/provider_service.dart` — **mock** ride quotes. Replace
  `MockProviderService` with a real implementation of `ProviderService` when a
  legitimate provider integration exists; nothing else changes.
- `lib/services/preference_interpreter.dart` — rule-based natural-language
  priorities. A Gemini-backed implementation can drop in later; the MVP never
  requires it.
- `android/.../OverlayService.kt` — the floating assistant: a foreground
  service drawing GoGo's own bubble and a compact priority panel over other
  apps. It never reads the screen underneath. Tapping *Compare* launches the
  app with the chosen priorities.

## Privacy

Location is used only to estimate driver distance and never leaves the device.
Priorities and recent destinations are stored in SharedPreferences. GoGo never
books a ride — the user finishes in the provider's own app.

## Known MVP limits

- Ride data is simulated; the results screen and every card say so. Only the
  handoff to the provider's app is real.
- Provider package names in `provider_service.dart` must be verified on a real
  device — a wrong one silently degrades to "not installed".
- Destination search is a local place list plus free text (no geocoding API).
- No map view, and the default Flutter launcher icon is still in place.
