# ADR 0013 — Material 3 Theming

## Status

Accepted

## Context

UV Alert needed a colour scheme that reflects the app's brand identity and
works well in both light and dark environments. The app logo uses a periwinkle
colour (`#9498ED`) that needed to carry through the UI. Material 3's
`ColorScheme.fromSeed` generates a full tonal palette from a single seed
colour, which made it the natural fit for deriving a harmonious scheme from
the logo colour. A separate decision was needed for light mode because the
periwinkle seed produces a blue-toned light scheme that doesn't convey urgency
for a UV safety app; orange was chosen as the light-mode seed to signal warmth
and sun exposure. Users can also choose their preferred theme (light, dark, or
system default) during onboarding, so the scheme had to look good in all three
modes.

## Decision

Use Material 3 (`useMaterial3: true`) with two pre-built `ThemeData` objects
constructed once at app startup (not per-build, because `ColorScheme.fromSeed`
is expensive):

- **Light theme** — `ColorScheme.fromSeed(seedColor: Colors.orange)`. Orange
  signals solar exposure and UV risk; it is the default until the user selects
  a theme during onboarding.
- **Dark theme** — `ColorScheme.fromSeed(seedColor: logoPurple,
  brightness: Brightness.dark)` where `logoPurple = Color(0xFF9498ED)`.
  Periwinkle is sampled directly from the app logo and anchors the dark palette
  to the brand.

The active theme is controlled by `ThemeMode`, stored in `SettingsNotifier` and
read from `SharedPreferences` (key `uvalert_theme`, values `'light'`/`'dark'`/
`'system'`). While `settingsProvider` is loading or in error the app falls back
to `ThemeMode.system`.

`logoPurple` is declared as a named constant in `lib/constants.dart` to satisfy
the no-magic-numbers rule and to give the colour a single canonical definition
reusable in other files.

Theme selection happens on the first screen of onboarding
(`ThemeOnboardingScreen`). Tapping a card updates the provider immediately
(optimistic write) so the theme applies in real time before the user taps
Continue. `setThemeStepDone()` is called on Continue; `setFirstLaunchDone()`
is called only after the final onboarding step.

## Consequences

- Two `ThemeData` singletons are allocated at startup and held for the
  lifetime of the process; this avoids re-running `ColorScheme.fromSeed`
  on every rebuild.
- Light and dark seeds are intentionally different colours. Changing one does
  not affect the other.
- Adding a new seed colour requires updating `lib/constants.dart` (if reused
  across files) and the relevant `ThemeData` in `lib/app.dart`.
- `ThemeMode.system` respects the OS preference at runtime. Users who never
  complete onboarding (or reset preferences) always get system default.
- The orange seed is not derived from the logo; it is a deliberate design
  choice for the light mode only.
