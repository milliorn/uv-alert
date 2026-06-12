# UV Alert

A Flutter app that monitors the UV index at your location and alerts you
when exposure risk is high. Targets Android.

## Features

- Real-time UV index fetched from a Vercel serverless proxy using your GPS
  coordinates (GPS permission not yet wired on Android) or a manually
  entered location
- Local notifications when UV levels reach configurable thresholds (planned)
- Background refresh via WorkManager so data stays current without keeping
  the app open (planned)
- 24-hour response cache keyed to the server-provided fetch timestamp,
  reducing unnecessary network requests
- Hourly and daily UV forecast with sunrise/sunset awareness and cloud cover
- Persistent user preferences: theme (light/dark/system), notification
  toggle, and GPS vs. manual location
- Material 3 design with an orange seed color palette
- Anonymous per-install UUID used for per-device request tracking

## Requirements

| Tool     | Version        |
| -------- | -------------- |
| Flutter  | stable channel |
| Dart SDK | ^3.11.4        |
| Android  | API 21+        |

## Getting Started

```sh
# Install dependencies
flutter pub get

# Run on a connected device or emulator
flutter run
```

## Commands

```sh
flutter pub get                       # Install dependencies
flutter analyze                       # Lint (very_good_analysis)
flutter test                          # Run all tests
flutter test test/foo_test.dart       # Run a single test file
flutter pub global run dartdoc        # Generate and validate API docs
flutter build apk                     # Android APK
flutter build appbundle               # Android App Bundle
```

CI runs `flutter analyze --fatal-infos` and `dart doc --validate-links`
as required gates. Run both locally before any PR.

## Architecture

**Target:** Android only. iOS is deferred; Linux desktop is not a target.

**State management:** Riverpod (`flutter_riverpod`). `main.dart` wraps
the app in `ProviderScope`. UI uses `ConsumerWidget` / `Consumer`.
All providers are in `lib/providers/`.

```text
lib/
  api/          # UvApi, GeocodingApi: HTTP clients with timeout/error handling
  models/       # UvData, UvForecastEntry: immutable, JSON-serializable value types
  providers/    # Riverpod notifiers and providers
  storage/      # Cache (24h TTL); Preferences (SharedPrefs wrapper)
  app.dart      # Root widget; Material 3 theme with light/dark/system ThemeMode
  constants.dart # App-wide constants
  main.dart     # Entry point with Riverpod ProviderScope and zone error hooks
```

**Data flow:**

1. `lib/api/uv_api.dart` -- fetches UV index from the Vercel proxy
   (`$proxyBaseUrl/api/uv`); sends `lat`, `lon`, and `X-Device-ID`
   (UUID); 10 s timeout; returns `UvData`
2. `lib/api/geocoding_api.dart` -- forward/reverse geocoding via
   `$proxyBaseUrl/api/geo`; same timeout pattern
3. `lib/storage/cache.dart` -- 24-hour `SharedPreferences` cache keyed
   on server-provided `fetchedAt` timestamp;
   `isValid = !isEmpty && !isStale`
4. `lib/storage/preferences.dart` -- typed `SharedPreferences` wrapper;
   all keys prefixed `uvalert_`
5. `lib/models/uv_model.dart` -- `UvData` and `UvForecastEntry`;
   immutable; JSON via factory constructors; epoch-seconds helpers

**Proxy:** The OWM API key is never bundled in the app. All requests go
through a Vercel serverless proxy (`uvwatch-proxy`) that protects the
key and caches responses in Upstash Redis. `proxyBaseUrl` is injected
via `--dart-define=PROXY_BASE_URL=...` at build time.

State management uses [Riverpod](https://riverpod.dev). Dependency
injection is constructor-based so every layer is independently testable
without mocks leaking across boundaries.

### Provider graph (`lib/providers/`)

- `preferencesProvider` `FutureProvider<Preferences>` -- foundation;
  all others depend on it
- `deviceIdProvider` `FutureProvider<String>` -- reads/generates UUID
  via `preferencesProvider`
- `proxyBaseUrlProvider` `Provider<String>` -- reads `proxyBaseUrl`
  constant; overridable in tests
- `cacheProvider` `FutureProvider<Cache>` -- backed by
  `preferencesProvider`
- `uvApiProvider` `FutureProvider<UvApi>` -- owns the HTTP client;
  registers `ref.onDispose(api.dispose)`
- `locationProvider`
  `NotifierProvider<LocationNotifier, LocationState>` --
  GPS via `GeolocatorPlatform`; `fetchGps()` / `setManual(lat, lon)`;
  `LocationState = ({double lat, double lon})?`
- `settingsProvider`
  `NotifierProvider<SettingsNotifier, AsyncValue<SettingsState>>` --
  theme, GPS pref, manual location, notifications toggle.
  Uses `Notifier<AsyncValue<...>>` **not** `AsyncNotifier` to avoid
  loading-state flicker on every mutation. Do not refactor to
  `AsyncNotifier`.
- `uvProvider`
  `NotifierProvider<UvNotifier, AsyncValue<UvData>>` -- watches
  `locationProvider`; generation-counter stale-fetch guard in
  `_fetchWith` prevents superseded requests from landing

### Key invariants

- Always check `ref.mounted` after every `await` inside a Notifier to
  prevent mutations after disposal.
- `Notifier.build()` must be synchronous; use `Future.microtask()` to
  kick off async initialization.
- Unawaited `Navigator` push calls must be wrapped in `unawaited()`
  (required by `unawaited_futures` + `discarded_futures` lint rules).

### Screens (`lib/screens/`)

- `onboarding_screen.dart` -- splash shown at every cold launch; routes
  to `ThemeOnboardingScreen`, `LocationOnboardingScreen`, or
  `DashboardScreen` based on `isFirstLaunch` / `isThemeStepDone`
- `theme_onboarding_screen.dart` -- step 1: theme selection; calls
  `prefs.setThemeStepDone()`; does NOT call `setFirstLaunchDone()`
- `location_onboarding_screen.dart` -- step 2: GPS or manual entry via
  geocoding; calls `setFirstLaunchDone()` after all data is written
- `dashboard_screen.dart` -- placeholder only
- `onboarding_progress_dots.dart` -- shared progress indicator widget

### Not yet implemented

- Onboarding step 3 (notifications, issue #15) -- when added, move
  `setFirstLaunchDone()` there and bump `totalOnboardingSteps` to 3
- Real dashboard screen and settings screen
- `lib/services/` (background polling via `workmanager`, local
  notifications via `flutter_local_notifications`)
- Runtime GPS permission request on Android (manifest entries planned)

## Models

`UvData` fields: `currentUvi`, `sunrise`, `sunset`, `clouds`, `hourly`,
`daily`, `timezone`, `timezoneOffset`, `fetchedAt`. All `DateTime`
values are UTC.

`UvForecastEntry` fields: `time` (UTC `DateTime`), `uvi` (`double`).
Used for both `hourly` (48 h) and `daily` (8 d) lists.

## Preferences keys (all `SharedPreferences`, prefix `uvalert_`)

| Key | Type | Default |
| --- | --- | --- |
| `first_launch` | `bool` | `true` |
| `theme_step_done` | `bool` | `false` |
| `uuid` | `String?` | -- |
| `theme` | `String` (`'system'`/`'light'`/`'dark'`) | `'system'` |
| `use_gps` | `bool` | `true` |
| `manual_location` | `String?` | -- |
| `notifications_enabled` | `bool` | `false` |
| `cached_payload` | `String?` | -- |
| `cached_payload_at` | `String?` | -- |

## Running Tests

```sh
# Run all tests with coverage
flutter test --coverage
```

CI enforces **100% line coverage** on every PR. All new code must
include tests that keep coverage at 100%.

Common patterns:

- Use `ProviderContainer(overrides: [...])` with
  `addTearDown(container.dispose)` for provider unit tests
- Use `SharedPreferences.setMockInitialValues(<String, Object>{})`
  in `setUp`
- Use `Future<void>.delayed(Duration.zero)` to flush microtasks after
  triggering async state transitions
- Shared fakes live in `test/fakes/`
  (e.g., `FakeGeolocator`, `FakeUvData`)

## Code Quality

This project uses
[very_good_analysis](https://pub.dev/packages/very_good_analysis) with
strict inference, strict casts, and strict raw types enabled. All
inference failures and unused elements are treated as errors.

```sh
flutter analyze
```

Additional style rules:

- All public API members require doc comments
  (`public_member_api_docs: error`)
- No `dynamic` (`avoid_dynamic_calls: true`); explicit types everywhere
  (`always_specify_types: true`)
- All numeric literals must be named constants -- no magic numbers, no
  single-use exemptions
- Double quotes for strings; single quotes only when the string
  contains a double quote
- File-private helpers go at file scope with `_` prefix, not as static
  methods
- No trailing commas (`require_trailing_commas` is off permanently)
- No `k` prefix on constants (`kFoo` is prohibited; use `foo`)

## CI/CD

GitHub Actions runs on every pull request targeting `main`:

- `flutter analyze --fatal-infos` -- static analysis
- `dart doc --validate-links` -- API doc validation
- `flutter test --coverage` -- unit and widget tests
- 100% line coverage gate via `lcov.info` inspection

Releases are managed by
[Release Please](https://github.com/googleapis/release-please) and
follow [Conventional Commits](https://www.conventionalcommits.org/).
The `pubspec.yaml` version is updated automatically on each release.

Dependencies are kept up to date monthly via Dependabot for pub
packages, Gradle, and GitHub Actions. Dependabot PRs (patch/minor) are
auto-merged via the `automerge` workflow.

PR titles must follow Conventional Commits:
`<type>(<scope>): <description>`. Copilot-generated PR titles do not
comply -- always correct them before submitting. Common types: `feat`,
`fix`, `chore`, `docs`, `test`, `refactor`, `ci`, `style`.

## Permissions

The app will request the following Android permissions at runtime
(neither is yet declared in the manifest or requested at runtime --
both are planned):

| Permission             | Reason              | Status  |
| ---------------------- | ------------------- | ------- |
| Location (fine/coarse) | GPS-based UV lookup | Planned |
| Notifications          | UV threshold alerts | Planned |

Location can be replaced with a manually entered location in Settings
if you prefer not to grant GPS access.

## Architecture decision records

Public ADRs are in `docs/adr/`.

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feat/your-feature`)
3. Commit using Conventional Commits (`feat:`, `fix:`, `chore:`, etc.)
4. Open a pull request against `main` -- CI must pass before merge

## Support

If this app is useful to you, consider supporting development:

- [Ko-fi](https://ko-fi.com/scottmilliorn)
- [GitHub Sponsors](https://github.com/sponsors/milliorn)

## License

This project is licensed under the MIT License.
