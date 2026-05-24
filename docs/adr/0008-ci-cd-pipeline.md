# ADR 0008 — CI/CD Pipeline Design

## Status

Accepted

## Context

The project needed a pipeline that enforces code quality, prevents regressions,
automates dependency updates, and automates releases with zero manual versioning
work.

## Decision

Use GitHub Actions with the following distinct workflows:

- **CI** (`ci.yml`) — runs on every PR to `main`: `flutter analyze
--fatal-infos`, `dart doc --validate-links`, `flutter test --coverage`,
  and an awk-based 100% line coverage gate against `coverage/lcov.info`
- **Release Please** (`release-please.yml`) — runs on push to `main`;
  automatically opens and maintains a release PR that bumps `pubspec.yaml`
  version and generates `CHANGELOG.md` from Conventional Commits
- **Automerge** (`automerge.yml`) — automatically approves and squash-merges
  Dependabot PRs for GitHub Actions updates and pub patch/minor version bumps;
  closes major version bumps with an explanation
- **Dependency Review** (`dependency-review.yml`) — scans changed dependency
  manifests against GitHub's advisory database on every PR; fails at `low`
  severity or above
- **Labeler** (`labeler.yml`) — applies labels to PRs based on changed paths
- **Merge Gatekeeper** (`merge-gatekeeper.yml`) — ensures required status
  checks pass before merge is allowed

## Consequences

- 100% line coverage is a hard gate — every new line of code must be covered
  by tests or CI fails
- `--fatal-infos` means analysis infos are treated as errors, not warnings
- Conventional Commits format is required on all commits; Release Please
  derives version bumps (`feat:` = minor, `fix:` = patch, `feat!:` = major)
  and changelog entries from commit messages
- Dependabot runs monthly for pub, Gradle, and GitHub Actions dependencies
- Release Please PRs require manual merge — GitHub Actions cannot self-approve
- All workflows pin to `ubuntu-24.04` and set
  `FORCE_JAVASCRIPT_ACTIONS_TO_NODE24: true` ahead of the June 2026 Node.js
  20 end-of-life for GitHub Actions
