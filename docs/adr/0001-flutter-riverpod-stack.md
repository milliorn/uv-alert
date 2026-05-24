# ADR 0001 — Flutter + Riverpod Stack

## Status

Accepted

## Context

UV Alert targets Android as its primary platform. The developer works on
Linux/Arch with an Android/Pixel device. iOS support is deferred pending access
to a Mac, Apple Developer account, and iOS device. A cross-platform solution
was required to avoid maintaining separate native codebases when other platforms
are added later.

## Decision

Use Flutter for the UI framework and Riverpod for state management.

## Consequences

- Android is the active development target; iOS and other platforms are
  structurally supported by Flutter and can be enabled when requirements are met
- Riverpod provides compile-safe, testable state management; providers live in
  `lib/providers/` and are wired via `ProviderScope` in `main.dart`
- iOS builds require macOS and Xcode — deferred until a Mac, Apple Developer
  account, and iOS device are available (Codemagic identified as cloud build
  solution)
- Linux desktop is a supported development target (used for local iteration on
  the developer's Arch machine)
