# GoGo

Find your better ride. GoGo compares fare quotes from multiple ride providers (prices in NPR), ranks them against what you care about — cheapest, nearest driver, or fastest pickup — and explains why the winner wins.

## How it works

1. Set a pickup point (auto-detected via GPS) and destination.
2. Pick priorities: 💰 cheapest / 📍 nearest driver / ⚡ fastest pickup, optionally capped at "within X min".
3. Providers are quoted and scored via weighted min-max normalization; the app ranks every option and generates a plain-language explanation of the winner's trade-offs.

Everything runs locally and deterministically: comparison, ranking, and text interpretation need no network.

## Status

The engine is complete; the UI is not wired yet.

- **Done**: models, `ComparisonService` (ranking + explanations), `ProviderService` (mocked quotes with seeded RNG), `LocationService` (permission flow + haversine distance), `PreferenceInterpreter` (rule-based text → priorities, LLM-swappable), `StorageService` (onboarding flag, preferences, recents), Riverpod state (`SearchNotifier`, `FloatingAssistantNotifier`).
- **WIP**: screens/routing (`go_router` added but unused), deep links to provider apps (`url_launcher` added but unused), native Android floating-assistant overlay.
- Quotes currently come from simulated mock providers; the service interface is ready for real APIs.

## Getting started

```sh
flutter pub get
flutter run
```

Requires Flutter with Dart SDK ^3.13.1.

## Project layout

```
lib/
  core/       providers
  features/   floating_assistant/ (Android overlay)
  models/     data types
  services/   location, providers, comparison, preferences, storage
```
