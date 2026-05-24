# ADR 0010 — Proxy-to-App Error Code Contract

## Status

Accepted — UX handling not yet implemented in the Flutter app

## Context

The proxy sits between the app and OWM. Raw OWM error responses are not
meaningful to the app and expose internal API details. A defined, stable error
code contract was needed so the app can present appropriate UX for each failure
mode without knowing which upstream caused it.

## Decision

The proxy translates all upstream errors to a fixed set of HTTP status codes
before responding to the app. OWM errors must never be forwarded raw. The
contract is:

| Code  | Meaning                     | Sentry             |
| ----- | --------------------------- | ------------------ |
| `200` | Success                     | No action          |
| `400` | Invalid params              | Alert              |
| `404` | Geocoding no results        | Log                |
| `426` | App version too old         | Log                |
| `429` | Proxy abuse detection       | Alert              |
| `500` | Unhandled proxy error       | Alert              |
| `502` | OWM key invalid/expired     | Alert — rotate key |
| `503` | OWM unreachable/rate capped | Log                |
| `504` | OWM timeout                 | Log                |

App UX per code:

- **200** — normal render
- **400** — silent retry
- **404** — inline field error: "Location not found. Try a different search."
- **426** — full-screen block with Play Store link
- **429** — banner: "Too many requests. Please try again later."
- **500/503/504** — 1st occurrence: toast. After 3 consecutive: persistent
  banner "UV data is temporarily unavailable. Showing last known reading."
  Banner clears on next success.
- **502** — banner: "UV data is temporarily unavailable. Showing last known
  reading."

## Consequences

- The app never inspects OWM response bodies — all error semantics flow through
  HTTP status codes
- Sentry captures every error code on both the proxy (Node.js) and app
  (Flutter) sides; alerts fire on first occurrence of any error
- The 3-consecutive-failure threshold for escalating from toast to persistent
  banner must be tracked in app state — not yet implemented
- `UvApiException` in `lib/api/uv_api.dart` is thrown on any non-200 response;
  it will carry the status code so callers can map to the above UX behaviors
