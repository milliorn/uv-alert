# ADR 0005 — catcher_2 for Crash Reporting

## Status

Accepted — end-to-end delivery validated

## Context

The Flutter app needs visibility into runtime crashes and unhandled exceptions.
The original plan (ADR 0005, now superseded) was to integrate Sentry, which
requires a paid or hosted third-party service. A simpler, zero-cost alternative
was needed for the early development phase.

## Decision

Use [`catcher_2`](https://pub.dev/packages/catcher_2) for crash reporting with
a custom `CrashReportHandler` that POSTs reports to the proxy's `/api/crash`
endpoint. The proxy forwards them via Gmail SMTP (Nodemailer). No email address
or credentials are embedded in the app binary.

- **Debug mode:** `DialogReportMode` shows an in-app dialog on crash;
  `ConsoleHandler` prints the full stack trace; `CrashReportHandler` POSTs to
  the proxy.
- **Release mode:** `SilentReportMode` suppresses the in-app dialog;
  `CrashReportHandler` POSTs to the proxy silently.

`Catcher2.navigatorKey` is wired into `MaterialApp` in `app.dart` so
navigation-context-requiring report modes work correctly.

`catcher_2` replaces the previous `FlutterError.onError` +
`runZonedGuarded` hooks that had TODO comments pointing to Sentry.

Crash reports include: error message, stack trace, device parameters, app
parameters, device UUID, and UTC timestamp.

## Consequences

- No third-party crash reporting service required beyond the existing proxy
- Crash reports arrive as emails via Gmail SMTP; no dashboard or aggregation
- No PII (email address) embedded in the app binary or source code
- Proxy environment variables (`GMAIL_USER`, `GMAIL_APP_PASSWORD`,
  `CRASH_REPORT_TO_EMAIL`) hold credentials server-side on Vercel
- Gmail free tier allows 500 emails/day -- sufficient for a personal app
- Sentry (or Firebase Crashlytics) remains an option for a future upgrade
  if volume or aggregation needs arise
