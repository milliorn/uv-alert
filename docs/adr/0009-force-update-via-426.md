# ADR 0009 — Force Update via HTTP 426

## Status

Accepted — not yet implemented

## Context

As the app evolves, old app versions may send requests the proxy can no longer
safely serve — incompatible payload shapes, deprecated fields, or removed
endpoints. A mechanism was needed to gate minimum supported versions without
requiring a Play Store review cycle for every enforcement change.

## Decision

The app sends its version string as the `X-App-Version` header on every proxy
request. The proxy checks the version against a minimum allowed version stored
in Vercel KV. If the version is below the minimum, the proxy returns
`426 Upgrade Required`. The app detects this response and shows a full-screen
blocking UI:

> "This version of UV Alert is no longer supported. Please update to continue."

A button links directly to the Play Store listing (Play Store listing TBD).
No other app functionality is accessible until the user updates.

## Consequences

- Minimum version threshold is updated in Vercel KV without a proxy
  deployment — enforcement is near-instant
- Force update is a last resort; normal deprecation should use warnings before
  hard blocking
- The 426 path is one of the defined error codes in the proxy-to-app error
  contract (see ADR 0010)
- If the app cannot reach the proxy (no network), no 426 response is possible
  and the force-update gate cannot fire; the app remains usable offline until
  connectivity is restored and the proxy responds
- iOS is deferred; force update behavior on iOS (App Store link) will be
  addressed when iOS support resumes
