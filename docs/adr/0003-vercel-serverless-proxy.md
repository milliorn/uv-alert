# ADR 0003 — Vercel Serverless Proxy

## Status

Accepted

## Context

The OWM API key must not be exposed in the client app. A proxy layer is needed
to protect the key, cache shared location data, and enforce per-device rate
limiting.

## Decision

Use a Vercel serverless function (Node.js) as a proxy between the app and OWM.
Use Upstash Redis for caching. The proxy lives in a separate repo
(`uv-alert-proxy`).

## Consequences

- OWM API key never exposed to the client; base URL is injected at build time
  via the `PROXY_BASE_URL` compile-time environment variable
- App sends `lat`, `lon`, and an `X-Device-ID` header (UUID) to `GET /api/uv`
- App sends location queries to `GET /api/geocode` for forward geocoding
  (city string -> coords) and reverse geocoding (coords -> display name);
  same `X-Device-ID` header; geocoding results are cached in Upstash Redis
  with a long TTL (coordinates of a city do not change)
- Shared location cache in Upstash Redis reduces OWM calls when multiple users
  request the same coordinates
- App POSTs crash reports to `POST /api/crash`; proxy forwards via Gmail
  SMTP (Nodemailer); no email credentials in the app binary
- No location change limits — cache amortizes costs naturally across users
- Vercel free tier supports ~4,761 users before upgrade needed (1M
  invocations/month)
