---
id: contract-swipe-stack-mvp
title: SwipeStack MVP gameplay and feedback contract
status: draft
related_specs:
  - feature-swipe-stack-mvp
evidence_files:
  - reports/harness-apply-skill-note.md
---

# Contract: SwipeStack MVP gameplay and feedback contract

## Goal
Define the MVP behavior for the shared game controller, player input, scoring,
audio triggers, and local persistence needed to ship SwipeStack on iPhone and
Android.

## Scope
- Shared controller logic for moving, swipe nudging, dropping, stacking, speed
  ramping, restart, and game-over state.
- Flutter UI that renders the stage, alignment HUD, status text, and restart
  flow.
- Platform audio hooks for drop, stack success, and fail events.
- Best-stack persistence in local device storage.

## Done Criteria
- The controller exposes deterministic state for current stack count, best stack,
  speed tier, moving box geometry, stacked boxes, and game-over status.
- Active play accepts a tap-to-drop input and ignores duplicate taps while a box
  is already dropping.
- Active play accepts horizontal drag updates to nudge the active box and drops
  on drag release with bounded drift carry.
- Successful drops preserve only the overlapping segment and advance the run.
- Failed drops transition to immediate game over and present restart UI.
- Best stack is restored on launch and updated after new records.
- Required sound effects are triggered from the relevant gameplay events.

## Verification
- `flutter analyze`
- `flutter test`
- Manual run on iOS simulator and Android debug build

## Evidence References
- `reports/harness-apply-skill-note.md`

## Stack-Specific Verification Notes
- Keep platform-specific verification focused on audio bridge integration and
  runnable app shells.
- Shared gameplay behavior should be validated primarily through Dart unit and
  widget tests.
