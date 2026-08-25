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
- `lib/services/quote_service.dart` — the provider registry and quote fan-out.
  Each provider has a `ProviderConnector`: a real API client where one exists,
  otherwise a handoff-only connector that reports why there is no price.
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

## Live pricing

GoGo never invents a fare. Each provider is either quoted through an official
API or explicitly reported as having no live price — see
[docs/provider-verification.md](docs/provider-verification.md).

Yango is the one provider with an official fare API. Supply credentials at build
time; without them the app says "Needs credentials" instead of showing a number:

```bash
flutter build apk --release \
  --dart-define=YANGO_CLID=your_clid \
  --dart-define=YANGO_API_KEY=your_key
```

## Known limits

