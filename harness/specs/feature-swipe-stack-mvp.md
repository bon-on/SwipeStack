---
id: feature-swipe-stack-mvp
title: Deliver SwipeStack cross-platform timing-stack MVP
status: active
owner: games
related_adrs:
  - adr-swipe-stack-deterministic-stacking
  - adr-ad-supported-store-release
related_contracts:
  - contract-swipe-stack-mvp
required_evidence:
  - flutter-analyze
  - flutter-tests
  - ios-build
  - android-build
  - harness-audit
  - harness-plan
---

# Feature Spec: Deliver SwipeStack cross-platform timing-stack MVP

## Problem
The next mobile game should reuse the same harness-driven delivery style as
MergeCamp and PulseDrift, but with a clearer arcade loop built around timing,
box drops, and visible stacking pressure.

## Scope
- Build SwipeStack as a shared Flutter game that runs on iPhone and Android.
- Use harness-lab artifacts as the source of truth before and during gameplay
  implementation work.
- Let a top box move horizontally until the player taps to drop it.
- Let horizontal drag reposition the active box, and let release drop it with a
  small amount of drift carry so the title's swipe interaction is meaningful.
- Show readable alignment feedback before the drop so players can learn timing
  and risk without relying on guesswork.
- Count each successful stack as score and increase horizontal speed every 5
  successful stacks.
- Make sound effects mandatory for drop, successful stack, and failed stack
  outcomes.
- Persist the best stack count locally across launches.
- Prepare the app for ad-supported App Store and Play Store release with
  AdMob banner ads, low-frequency game-over interstitials, and store privacy
  documentation.

## Acceptance Criteria
- The game starts and runs from one Flutter codebase on iPhone and Android.
- Tapping during active play drops the moving box immediately.
- Dragging horizontally during active play nudges the moving box, and releasing
  a drag drops it without bypassing the deterministic overlap rule.
- A dropped box stacks successfully only when its horizontal overlap with the
  previous top box meets the deterministic success rule.
- The game ends immediately when a dropped box misses the success threshold.
- Horizontal movement speed increases after every 5 successful stacks.
- Drop, stack success, and game-over failure events trigger audible feedback.
- Ads never interrupt active play; banners occupy their own safe-area slot and
  interstitials are only eligible after completed runs.
- Platform manifests include AdMob app identifiers and advertising ID metadata
  needed for test builds.
- Automated analysis and tests pass, and the project can produce runnable iOS
  and Android builds.

## Constraints
- Keep the MVP offline and single-player.
- Use deterministic overlap-based stack resolution instead of a full physics
  engine for v1.
- Keep gameplay logic shared across platforms and platform-specific code limited
  to shell and audio integration.
- Future gameplay changes must be captured in `harness/specs/` before code
  changes.

## Stack Notes
- The repo is a Flutter mobile app with no approved profile packs yet, so
  project-specific mobile constraints must remain explicit in the spec and ADR.
- Reuse the lightweight MethodChannel audio pattern already proven in
  MergeCamp and PulseDrift.

## Evidence
- `flutter analyze`
- `flutter test`
- `flutter build ios --simulator`
- `flutter build apk --debug`
- `node /Users/junsik.park/sources/harness-lab/dist/index.js audit /Users/junsik.park/sources/games/SwipeStack --format md`
- `node /Users/junsik.park/sources/harness-lab/dist/index.js plan harness/specs/feature-swipe-stack-mvp.md --format text`
