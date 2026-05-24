# ADR 0003 — Vercel Serverless Proxy

## Status

Accepted

## Context

The OWM API key must not be exposed in the client app. A proxy layer is needed
to protect the key, cache shared location data, and enforce per-user rate
limiting.

## Decision

Use a Vercel serverless function (Node.js) as a proxy between the app and OWM.
Use Vercel KV for caching and rate limiting. The proxy lives in a separate repo
(`uvwatch-proxy`).

## Consequences

- OWM API key never exposed to the client; base URL is injected at build time
  via the `PROXY_BASE_URL` compile-time environment variable
- App sends `lat`, `lon`, and an `X-Device-ID` header (UUID) to `GET /api/uv`
- Shared location cache in Vercel KV reduces OWM calls when multiple users
  request the same coordinates
- No location change limits — cache amortizes costs naturally across users
- Vercel free tier supports ~4,761 users before upgrade needed (1M
  invocations/month)
