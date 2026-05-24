# ADR 0011 — Accessibility Approach

## Status

Accepted — implementation pending

## Context

UV data is safety-critical for people with sun-sensitive conditions including
melanoma survivors. Accessibility cannot be an afterthought. At the same time,
the host OS handles many accessibility concerns natively, so the scope of
in-app work needed to be clearly defined. The app targets Android, iOS
(deferred), and Linux desktop.

## Decision

Delegate OS-level accessibility entirely to the host OS (font scaling, display
size, high contrast, colorblind correction, reduce motion, bold text, invert
colors, grayscale). This covers Android and Linux desktop; iOS follows the same
delegation when enabled. Implement the following in-app:

**Semantic labels (TalkBack/VoiceOver):**

- All interactive elements must have descriptive labels
- App bar icons: "Change location" (pin), "Open settings" (gear)
- UV hero: reads full context, e.g. "UV index 4.2, Moderate risk"
- Each chart data point: "2:00 PM, UV index 4.2, Moderate risk" — navigable
  via TalkBack swipe without requiring press-and-hold

**Touch targets:**

- Minimum 48x48dp for all tappable elements (Android accessibility guideline)
- Applies to app bar icons, onboarding cards, notification toggles, and
  settings items

**Focus order:**

- Logical navigation order must be defined for keyboard and switch access users

**Responsive sizing:**

- The UV index ring and hero number scale relative to text size, not fixed
  pixels, to prevent overflow at large font scales

## Consequences

- WHO color scale (green/yellow/orange/red/purple) is used for both visual and
  semantic UV risk communication — colorblind users receive the risk label in
  text, not color alone
- Chart scrub interaction (press and hold) requires an alternate path for
  screen reader users — TalkBack swipe navigation through data points
- Accessibility requirements apply to all screens: onboarding, dashboard,
  settings
