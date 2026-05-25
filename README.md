# UV Alert

A Flutter app that monitors the UV index at your location and alerts you when
exposure risk is high. Targets Android and Linux desktop.

## Features

- Real-time UV index fetched from a Vercel serverless proxy using your GPS
  coordinates (GPS permission not yet wired on Android) or a manually entered
  location
- Local notifications when UV levels reach configurable thresholds (planned)
- Background refresh via WorkManager so data stays current without keeping the
  app open (planned)
- 24-hour response cache keyed to the server-provided fetch timestamp, reducing
  unnecessary network requests
- Hourly and daily UV forecast with sunrise/sunset awareness and cloud cover
- Persistent user preferences: theme (light/dark/system), notification toggle,
  and GPS vs. manual location
- Material 3 design with an orange seed color palette
- Anonymous per-install UUID used for per-device request tracking

## Architecture

```text
lib/
  api/          # UvApi - HTTP client with cache-first fetch, timeout, error handling
  models/       # UvData, UvForecastEntry — immutable, JSON-serializable value types
  providers/    # Riverpod notifiers and providers: UvNotifier, LocationNotifier,
                #   SettingsNotifier, deviceIdProvider, preferencesProvider
  storage/      # Cache - 24-hour staleness check; Preferences - SharedPrefs wrapper
  app.dart      # Root widget and Material 3 theme
  constants.dart # App-wide constants
  main.dart     # Entry point with Riverpod ProviderScope and zone error hooks
```

State management uses [Riverpod](https://riverpod.dev). Dependency injection is
constructor-based so every layer is independently testable without mocks leaking
across boundaries.

The OWM API key is never bundled in the app. All UV data requests go through a
Vercel serverless proxy (`uvwatch-proxy`) that protects the key, caches shared
location data, and enforces per-device rate limiting via Vercel KV.

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

# Run on Linux desktop
flutter run -d linux
```

## Running Tests

```sh
# Run all tests with coverage
flutter test --coverage
```

CI enforces 100% line coverage on every pull request. Any new code must be
accompanied by tests that maintain full coverage.

## Code Quality

This project uses
[very_good_analysis](https://pub.dev/packages/very_good_analysis) with strict
inference, strict casts, and strict raw types enabled. All inference failures
and unused elements are treated as errors.

```sh
flutter analyze
```

## CI / CD

GitHub Actions runs on every pull request targeting `main`:

- `flutter analyze` - static analysis
- `flutter test --coverage` - unit and widget tests
- 100% line coverage gate via `lcov.info` inspection

Releases are managed by
[Release Please](https://github.com/googleapis/release-please) and follow
[Conventional Commits](https://www.conventionalcommits.org/). The `pubspec.yaml`
version is updated automatically on each release.

Dependencies are kept up to date monthly via Dependabot for pub packages,
Gradle, and GitHub Actions.

## Permissions

The app will request the following Android permissions at runtime (location
permission is declared but not yet requested; notification permission is
planned):

| Permission             | Reason              | Status  |
| ---------------------- | ------------------- | ------- |
| Location (fine/coarse) | GPS-based UV lookup | Planned |
| Notifications          | UV threshold alerts | Planned |

Location can be replaced with a manually entered location in Settings if you
prefer not to grant GPS access.

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feat/your-feature`)
3. Commit using Conventional Commits (`feat:`, `fix:`, `chore:`, etc.)
4. Open a pull request against `main` - CI must pass before merge

## Support

If this app is useful to you, consider supporting development:

- [Ko-fi](https://ko-fi.com/scottmilliorn)
- [GitHub Sponsors](https://github.com/sponsors/milliorn)

## License

This project is licensed under the MIT License.
