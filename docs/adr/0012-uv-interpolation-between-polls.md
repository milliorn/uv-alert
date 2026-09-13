# ADR 0012 — UV Interpolation Between Polls

## Status

Accepted. Solar-position interpolation math implemented in
`lib/services/uv_interpolation.dart`, not yet wired into the dashboard (see
issue #133)

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
2. Calculate solar elevation angle from lat, lon, date, and current time
   (all angular inputs — lat, lon, declination, hour angle — in degrees;
   convert to radians before calling trig functions); use the peak
   `hourly[].uvi` for the current day as UVmax (falls back to `current.uvi`
   if no hourly data is available); UV estimate = UVmax × sin(elevation_rad)
3. Always use the conservative (higher) of the interpolated value and the
   last-known `current.uvi`, even for a small difference (e.g. 3.2 vs. 3.3) --
   protecting user safety takes priority over reporting the more "accurate"
   lower estimate
4. Every 2-hour refresh corrects the model with fresh `current.uvi` from OWM

## Consequences

- UV display updates continuously between polls without network calls
- Cloud cover is not factored into the interpolation — the model assumes clear
  sky between refreshes, which may overestimate UV on cloudy days (the
  conservative choice)
- Solar position math runs on-device using only lat, lon, and the system clock
- The 2-hour refresh corrects accumulated drift from cloud cover or unexpected
  atmospheric conditions
- This logic lives in `lib/services/uv_interpolation.dart` alongside the
  polling service; no widget calls it yet, so the dashboard does not display
  interpolated values until issue #133 wires it in
