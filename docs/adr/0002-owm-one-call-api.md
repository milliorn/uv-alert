# ADR 0002 — OpenWeatherMap One Call API 3.0

## Status

Accepted

## Context

UV Alert requires real-time UV index data, hourly UV forecast, and daily UV forecast
from a single API call. A reliable, affordable data source was needed with no fallback.

## Decision

Use OpenWeatherMap One Call API 3.0 on the pay-per-call "One Call by Call" subscription.

## Consequences

- First 1,000 calls/day free, $0.0015/call beyond that
- Single API covers current UV, 48-hour hourly forecast, 8-day daily forecast, sunrise/sunset
- No fallback API — if OWM is unreachable, app falls back to cached data
- Fields not used: minutely, alerts, moon data, temperature, wind, pressure, humidity
