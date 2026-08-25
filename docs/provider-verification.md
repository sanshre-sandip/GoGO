# Provider verification

Everything in `kProviders` (`lib/services/quote_service.dart`) was read off a
physical Android 16 device on 2026-08-25, not guessed. Re-run these when adding
a provider — a wrong package id silently degrades to "not installed", and a
wrong scheme silently falls back to a plain app launch.

## Installed packages

```
$ adb shell pm list packages | grep -iE "pathao|indrive|yango|uber"
package:com.yandex.yango
package:com.pathao.user
package:sinet.startup.inDriver
```

`com.ubercab` was not installed on the test device; the id is confirmed from its
Play Store listing only, so its handoff path (store fallback) is the one
exercised here.

## URI schemes

Read from the apps' own intent filters, then resolved:

```
$ adb shell dumpsys package com.yandex.yango | grep -oE 'Scheme: "[a-z0-9.+-]+"'
$ adb shell cmd package resolve-activity --brief -a android.intent.action.VIEW -d "<uri>"

pathao://        -> com.pathao.user/.ui.core.deeplink.DeeplinkTransparentActivity
indrive://open   -> sinet.startup.inDriver/.ui.deeplink.DeeplinkActivity
yandexyango://   -> com.yandex.yango/ru.yandex.taxi.activity.MainActivity
```

Note `indrive://` alone does **not** resolve — the filters require a host, hence
`indrive://open`. Yango's scheme is `yandexyango://`, not `yango://`.

## Route pre-fill

Yango documents `https://yango.go.link/route?start-lat=…&end-lat=…` for opening
the app on a specific trip. Tested on device: the app opens, but the trip is
**not** pre-filled without a partner `ref`/tracker of our own. Until GoGo has
one, handoff opens the app at its own start screen.

## Live pricing

| Provider | Status | Why |
|---|---|---|
| Yango | Official API, implemented | `taxi-routeinfo.taxi.yandex.net/taxi_info`, needs `clid` + `apikey` from integration-support@yango.com |
| Pathao | None | No public fare API for third parties |
| inDrive | None | Fares are passenger offers; there is nothing to quote |
| Uber | Not permitted | `/v1.2/estimates/price` needs approval **and** their API terms forbid using it to compare against competing services |
