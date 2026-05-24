# ADR 0004 — Polling Strategy

## Status

Accepted — background scheduling not yet implemented

## Context

UV index only matters during daylight hours. Polling continuously wastes API
calls and battery. A strategy was needed to minimize calls while keeping data
accurate.

## Decision

Poll every 2 hours between sunrise and sunset only. Between polls, derive UV
estimates using sine interpolation from solar position math (no cloud
correction). Every 2-hour refresh corrects the model with fresh `currentUvi`.
If interpolated and actual values diverge significantly, use the conservative
(higher) value.

## Consequences

- ~7 API calls/user/day (1 sunrise + ~6 two-hour refreshes)
- No polling overnight — app sleeps until tomorrow's sunrise
- UV estimate between polls is approximate but corrected every 2 hours
- Conservative value used on divergence to protect user safety
- Background scheduling via WorkManager is stubbed in `lib/services/`; sunrise/
  sunset interpolation logic is not yet implemented
