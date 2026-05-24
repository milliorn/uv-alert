# ADR 0012 — UV Interpolation Between Polls

## Status

Accepted — not yet implemented

## Context

The app polls OWM every 2 hours. Between polls, the displayed UV index would
be static if cached data were shown verbatim. OWM `current.uvi` is snapped to
the current hour value, not interpolated, so it is already stale by the time
it arrives. A strategy was needed to show accurate, smoothly changing UV
values between refreshes without additional API calls.

## Decision

Between polls, derive a UV estimate using solar position math applied to the
hourly forecast anchors already present in the cached payload:

1. Use `hourly[].uvi` values from the cached payload as anchors
2. Calculate solar elevation angle from lat, lon, date, and current time.
   Formulas are expressed in degrees; convert to radians before passing to
   `sin`/`cos` (Dart and most languages expect radians):
   - Declination = 23.45 × sin(360/365 × (dayOfYear - 81))
   - Hour angle = (currentHour - 12) × 15
   - sin(elevation) = sin(lat) × sin(dec) + cos(lat) × cos(dec) × cos(hourAngle)
   - UVmax = the peak `hourly[].uvi` value in the cached payload for the
     current day; falls back to `current.uvi` if no hourly data is available
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
- This logic will live in `lib/services/` alongside the polling service and is
  not yet implemented
