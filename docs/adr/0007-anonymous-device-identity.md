# ADR 0007 — Anonymous Device Identity via UUID

## Status

Accepted

## Context

The proxy needs to identify individual devices for rate limiting and error
tracking without collecting personally identifiable information. Platform
device IDs (Android ID, IDFA) are tied to the device and may be considered
PII depending on jurisdiction. A privacy-preserving alternative was needed.

## Decision

Generate a random UUID (v4) on first launch, store it in SharedPreferences
under `uvalert_uuid`, and send it as the `X-Device-ID` header on every proxy
request. `device_info_plus` is available for collecting platform device
metadata but is not used for identity.

## Consequences

- No PII collected or transmitted — UUID is anonymous and not linked to any
  account or device identifier. Latitude and longitude are transmitted to the
  proxy as query parameters to forward to the weather API, but are not stored
  or logged by the proxy as currently implemented.
- UUID is stable for the lifetime of the app install; reinstalling generates
  a new UUID. Android Auto Backup (enabled by default) can restore
  SharedPreferences after a reinstall, which would carry over the UUID and
  make the reinstalled app appear as the same device. If that behavior is
  undesirable, exclude `uvalert_uuid` from backup via an Android backup rules
  XML (`android:fullBackupContent` / `android:dataExtractionRules`).
- Proxy keys rate limiting on UUID — abuse (scripted coord spamming) can be
  detected and blocked per device without identifying the user
- Error tracking in Sentry is per-UUID, enabling per-device error history
  without exposing user identity
- `device_info_plus` data (Android build info, model, SDK version) is
  available for future diagnostics but is not sent to the proxy in the
  current implementation
