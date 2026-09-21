# ADR 0006 — SharedPreferences as the Only Local Storage

## Status

Accepted

## Context

The app needs to persist user settings, a device UUID, cached UV payload, and
notification preferences across sessions. Several local storage options exist
for Flutter: SharedPreferences, Hive, SQLite (via sqflite or drift), and
Isar. A choice was needed to avoid future divergence.

## Decision

Use SharedPreferences exclusively. No Hive, SQLite, Isar, or any other local
database.

## Consequences

- All keys are prefixed `uvalert_` to prevent collisions
- The full key set is owned by `lib/storage/preferences.dart` — no other file
  writes to SharedPreferences directly
- Cache payload, timestamp, and location key are stored together as one
  JSON-encoded record (`uvalert_cached_entry`), so they can never be read
  back as a combination that wasn't written together by the same `store` call
- `manual_location` is currently a raw string; it will migrate to a structured
  lat/lon representation when the location feature is fully implemented
- Sufficient for this app's data volume — no relational queries, no large
  datasets, no offline-first sync requirements that would justify a database
