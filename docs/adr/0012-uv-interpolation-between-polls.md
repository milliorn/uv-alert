# ADR 0012 — UV Interpolation Between Polls

## Status

Accepted — not yet implemented

## Context

The app will poll the proxy every 2 hours. Between polls, the displayed UV
index would be static if cached data were shown verbatim. OWM `current.uvi`
is snapped to the current hour value, not interpolated, so it is already stale
by the time it arrives. A strategy was needed to show accurate, smoothly
changing UV values between refreshes without additional API calls.

## Decision

Between polls, derive a UV estimate using solar position math applied to the
hourly forecast anchors already present in the cached payload:

1. Use `hourly[].uvi` values from the cached payload as anchors
2. Calculate solar elevation angle from lat, lon, date, and current time.
   Dart's `sin`/`cos` expect radians. The intermediate angle values below are
   in degrees and must be converted before calling `sin`/`cos` — multiply by
   `π / 180`:
   - Declination (degrees) = 23.45 × sin((360/365 × (dayOfYear - 81)) × π/180)
   - Hour angle (degrees) = (currentHour - 12) × 15
   - sin(elevation) = sin(lat × π/180) × sin(dec × π/180) +
     cos(lat × π/180) × cos(dec × π/180) × cos(hourAngle × π/180)
   - All three variables — lat, dec, and hourAngle — are in degrees and must
     each be multiplied by π/180 before being passed to sin/cos
   - UVmax = the peak `hourly[].uvi` value in the cached payload for the
     current day (determined by device local time); falls back to `current.uvi`
     if no hourly data is available
   - UV estimate = UVmax × sin(elevation)
3. If the interpolated value and the last-known `current.uvi` diverge
   significantly, use the conservative (higher) value to protect user safety
4. Every 2-hour refresh corrects the model with fresh `current.uvi` from OWM

## Consequences

- UV display updates continuously between polls without network calls
- Cloud cover is not factored into the interpolation — the model assumes clear
  sky between refreshes, which may overestimate UV on cloudy days (the
  conservative choice)
- Solar position math runs on-device using only lat, lon, and the system clock
- The 2-hour refresh corrects accumulated drift from cloud cover or unexpected
  atmospheric conditions
- `sin(elevation)` is negative when the sun is below the horizon; the result
  must be clamped to `[0, UVmax]` before display — UV is never negative
- This logic will live in `lib/services/` alongside the polling service and is
  not yet implemented
