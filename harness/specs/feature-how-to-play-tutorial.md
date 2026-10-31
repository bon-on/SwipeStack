---
id: feature-how-to-play-tutorial
title: Deliver SwipeStack first-run How to play tutorial
status: active
owner: games
related_adrs:
  - adr-swipe-stack-deterministic-stacking
related_contracts:
  - contract-swipe-stack-mvp
required_evidence:
  - flutter-analyze
  - flutter-tests
  - web-build
  - harness-audit
---

# Feature Spec: Deliver SwipeStack first-run How to play tutorial

## Problem
First-time players do not know the goal, the inputs, or the overlap rule. A short explanation with a skip option is needed.

## Scope
- On first launch only (flag unset), show a 3-step "How to play" overlay card over the game with a per-step icon, page dots, and Skip / Next (Play on the last step) buttons.
- Skip or Play closes it and stores `shared_preferences` key `tutorial_seen_v1` (bool).
- A `?` header button (tooltip "How to play") reopens it at step 1 at any time without resetting the run.
- Keyboard: Enter/Space next/Play, Escape skip, Left/Right arrows previous/next. While open, these keys and all game input (taps, drags, drop/nudge/restart keys) are blocked from the game.
- The real-time simulation (moving box, drop) does not advance while the overlay is open or while the first-run check is pending; closing resumes it without a time jump.
- Storage failures never break play: read failure shows the tutorial, write failure just closes it.
- Copy is English and describes only inputs that exist.

## Acceptance Criteria
- With the flag unset the overlay appears and game input is blocked.
- Next walks the steps, the last step shows Play, Play closes and stores the flag.
- Skip and Escape close it and store the flag.
- With the flag set the overlay does not appear.
- `?` reopens at step 1 without resetting game state.
- The moving box does not advance while the overlay is open.
- No overflow at 390x844, 844x390 and 1280x720.

## Constraints
- Gameplay logic stays shared across iPhone and Android; ads stay outside active play.
- Storage goes through an injectable `HowToPlayStore`, following the `BestStackStore` pattern.

## Evidence
- `flutter analyze`, `flutter test`
- `flutter build web --release --base-href /SwipeStack/`
- `node <harness-lab>/dist/index.js audit . --format md`
