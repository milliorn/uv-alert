# ADR 0010 — Proxy-to-App Error Code Contract

## Status

Accepted — consecutive-failure tracking implemented in the Flutter app
(`ProxyErrorState`/`ProxyErrorNotifier` in `lib/providers/uv_provider.dart`);
per-status-code UX (banners, inline errors, toast text) not yet wired to a
consumer widget

## Context

The proxy sits between the app and OWM. Raw OWM error responses are not
meaningful to the app and expose internal API details. A defined, stable error
code contract was needed so the app can present appropriate UX for each failure
mode without knowing which upstream caused it.

## Decision

The proxy translates all upstream errors to a fixed set of HTTP status codes
before responding to the app. OWM errors must never be forwarded raw. The
contract is:

| Code  | Meaning                     |
| ----- | --------------------------- |
| `200` | Success                     |
| `400` | Invalid params              |
| `404` | Geocoding no results        |
| `426` | App version too old         |
| `429` | Proxy abuse detection       |
| `500` | Unhandled proxy error       |
| `502` | OWM key invalid/expired     |
| `503` | OWM unreachable/rate capped |
| `504` | OWM timeout                 |

App UX per code:

- **200** — normal render
- **400** — surface an error to the user; do not retry (an identical bad
  request will produce another 400)
- **404** — inline field error: "Location not found. Try a different search."
- **426** — full-screen block with Play Store link
  (force update behavior defined in ADR 0009)
- **429** — banner: "Too many requests. Please try again later."
- **500/503/504** — 1st occurrence: toast. After 3 consecutive: persistent
  banner "UV data is temporarily unavailable. Showing last known reading."
  Banner clears on next success.
- **502** — persistent banner immediately (no toast-first path): "UV data is
  temporarily unavailable. Showing last known reading." 502 indicates an
  invalid or expired OWM key, which requires operator action — there is no
  point waiting for 3 consecutive failures when the root cause cannot self-heal.

## Consequences

- The app never inspects OWM response bodies — all error semantics flow through
  HTTP status codes
- `lib/api/uv_api.dart` declares a sealed `UvApiFailure` hierarchy:
  `UvApiException` (any non-200 response; carries `statusCode` and `body`),
  `UvApiForceUpdateException` (426), and `UvApiParseException` (a 200 response
  whose body is unparseable, not a proxy error). Each subtype declares an
  `escalationStatusCode` getter (non-null status code to escalate with, or
  `null` to be excluded) so escalation eligibility and the code to record are
  a single getter, centralized on the exception type rather than inferred per
  catch site -- a subtype can't opt in without also providing the code the
  counter needs, in any build mode.
- `ProxyErrorState`/`ProxyErrorNotifier` in `lib/providers/uv_provider.dart`
  track the 3-consecutive-failure threshold for escalating from toast to
  persistent banner. Currently this is one undifferentiated counter across all
  status codes for which `escalationStatusCode` is non-null (today, only
  `UvApiException`, i.e. every non-200/non-426 code) — it does not yet
  implement the per-code distinctions above (e.g. 502's immediate escalation,
  or excluding 400/404/429 from the counter). No widget consumes this state yet.
