# ADR 0005 — catcher_2 for Crash Reporting

## Status

Accepted — email delivery not yet validated end-to-end

## Context

The Flutter app needs visibility into runtime crashes and unhandled exceptions.
The original plan (ADR 0005, now superseded) was to integrate Sentry, which
requires a paid or hosted third-party service. A simpler, zero-cost alternative
was needed for the early development phase.

## Decision

Use [`catcher_2`](https://pub.dev/packages/catcher_2) for crash reporting.

- **Debug mode:** `DialogReportMode` shows an in-app dialog on crash;
  `ConsoleHandler` prints the full stack trace; `EmailManualHandler` prepares
  a draft email for manual send.
- **Release mode:** `SilentReportMode` suppresses the in-app dialog;
  `EmailManualHandler` sends a crash report to `scottmilliorn@gmail.com` with
  the title "UV Alert crash report".

`Catcher2.navigatorKey` is wired into `MaterialApp` in `app.dart` so
navigation-context-requiring report modes work correctly.

`catcher_2` replaces the previous `FlutterError.onError` +
`runZonedGuarded` hooks that had TODO comments pointing to Sentry.

## Consequences

- No third-party crash reporting service required; no ongoing cost
- Crash reports arrive as emails; no dashboard or aggregation
- `EmailManualHandler` in release mode requires the device mail client to
  complete the send -- delivery is not guaranteed if the user dismisses the
  draft
- Sentry (or Firebase Crashlytics) remains an option for a future upgrade
  if volume or aggregation needs arise
- `EmailAutoHandler` via SMTP would auto-send without user interaction but
  requires SMTP credentials bundled in the app (not yet done)
