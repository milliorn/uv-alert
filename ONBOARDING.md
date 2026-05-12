# UV Alert - Developer Onboarding

## What Is This?

UV Alert is a Flutter app that monitors the UV index at your location and sends
notifications when exposure risk is high. It targets Android (API 21+) and
Linux desktop.

The app fetches UV data from a Vercel proxy API using GPS coordinates or a
manually entered location, caches responses for 24 hours, and surfaces hourly
and daily UV forecasts.

**Current state (v1.1.0):** Core infrastructure is complete - models, API
client, cache, preferences, Riverpod scaffold, and a full unit test suite. The
UI screens (`dashboard_screen`, `settings_screen`, `onboarding_screen`) and
background service implementations are stubs. The app renders a `Placeholder`
as its home widget.

## Prerequisites

| Tool    | Version        |
| ------- | -------------- |
| Flutter | stable channel |
| Dart    | ^3.11.4        |
| Android | API 21+        |

Install Flutter from [flutter.dev](https://flutter.dev/docs/get-started/install)
and confirm you are on the stable channel:

```sh
flutter channel stable
flutter upgrade
flutter doctor
```

## Getting the Code

```sh
git clone https://github.com/milliorn/uv-alert.git
cd uv-alert
flutter pub get
```

There is a companion repo, `uv-alert-proxy`, which is the Vercel proxy the app
calls. You do not need it to run the Flutter app locally, but you will need it
if you are working on the API layer.

## Running the App

```sh
# On a connected Android device or emulator
flutter run

# On Linux desktop
flutter run -d linux
```

## Running Tests

```sh
# All tests with coverage
flutter test --coverage

# A single test file
flutter test test/cache_test.dart
```

CI enforces **100% line coverage** on every pull request. New code must ship
with tests that maintain full coverage - no exceptions.

## Linting and Analysis

```sh
flutter analyze
```

This project uses
[very_good_analysis](https://pub.dev/packages/very_good_analysis) (`^10.2.0`).
Strict inference, strict casts, and strict raw types are all enabled. All
analysis warnings are treated as errors - CI fails on any lint violation,
including infos (`--fatal-infos`).

Documentation links are also validated:

```sh
dart doc --validate-links
```

## Codebase Layout

```text
lib/
  api/
    uv_api.dart          # HTTP client; cache-first fetch; throws UvApiException
  models/
    uv_model.dart        # UvData and UvForecastEntry; JSON serialization
  storage/
    cache.dart           # 24-hour SharedPreferences cache; isValid = !isEmpty && !isStale
    preferences.dart     # Typed wrapper for all SharedPreferences keys (prefix: uvalert_)
  constants.dart         # Shared compile-time constants (msPerSecond, etc.)
  app.dart               # Root MaterialApp widget; Material 3 theme
  main.dart              # Entry point; ProviderScope; zone error hooks

test/
  cache_test.dart
  preferences_test.dart
  uv_api_test.dart
  uv_model_test.dart
  widget_test.dart
```

## How the Data Flows

1. A caller invokes `UvApi.fetch(lat, lon, uuid)`.
2. `UvApi` checks the cache first (`Cache.isValid`). If valid, returns the
   cached `UvData` without a network call.
3. If stale or empty, it hits the proxy: `GET /api/uv?lat=…&lon=…` with an
   `X-Device-ID` header containing the device UUID.
4. The response is parsed into `UvData`, stored in `Cache` (keyed on the
   server-provided `fetchedAt` timestamp), and returned.

State management is [Riverpod](https://riverpod.dev). The app is wrapped in
`ProviderScope` in `main.dart`. Widgets that need data extend `ConsumerWidget`
and read from providers in `lib/providers/` (stubs right now).

## Key Behaviors to Know

- **Cache TTL:** 24 hours, keyed to the server's `fetchedAt` timestamp, not
  `DateTime.now()`. If the server timestamp lags real time, the cache expires
  sooner - this is intentional.
- **Cache staleness:** `isStale` has no `.abs()` call. Data fetched in the
  future (clock skew) appears fresh, not stale.
- **HTTP client ownership:** `UvApi` owns its `http.Client` by default and
  closes it on `dispose()`. Pass your own client to share or mock it - it will
  not be closed by `dispose()`.
- **Error handling:** `UvApiException` is thrown on any non-200 response or
  parse failure. Two separate error hooks live in `main.dart` - `FlutterError.onError`
  for framework errors and `runZonedGuarded` for async errors. They must stay
  separate; both have a TODO to wire up crash reporting.
- **Preferences keys:** All `SharedPreferences` keys are prefixed `uvalert_`.
  See `lib/storage/preferences.dart` for the full list.

## Making Changes

Branch off `main`, commit with
[Conventional Commits](https://www.conventionalcommits.org/), and open a PR
against `main`.

```sh
git checkout -b feat/your-feature
# ... make changes ...
git commit -m "feat: describe what you added"
```

Common prefixes: `feat:`, `fix:`, `chore:`, `docs:`, `test:`, `refactor:`.

CI runs automatically on every PR:

1. `flutter analyze --fatal-infos` - must pass with zero issues
2. `dart doc --validate-links` - docs must be valid
3. `flutter test --coverage` - all tests must pass
4. 100% line coverage gate - no regressions

Dependabot keeps pub, Gradle, and GitHub Actions dependencies up to date
monthly. Patch and minor Dependabot PRs are auto-merged once CI passes.
Releases are managed by Release Please and cut automatically on pushes to
`main`.

## Open Work

The following are known stubs waiting to be implemented:

- `lib/screens/` - `dashboard_screen`, `settings_screen`, `onboarding_screen`
- `lib/providers/` - Riverpod providers wiring API and preferences to UI
- `lib/services/` - `workmanager` background refresh and
  `flutter_local_notifications` alert dispatch
- Crash reporting - TODO comments in `main.dart` mark where Sentry or
  Firebase Crashlytics should be wired in
- Manual location - stored as a raw string; needs migration to a structured
  lat/lon type when the location feature lands
- Retry logic - `UvApi.fetch` has a TODO for exponential backoff on
  `TimeoutException`
