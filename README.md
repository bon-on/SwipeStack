# SwipeStack

SwipeStack is a cross-platform Flutter timing game delivered with
spec-driven harness engineering. A box moves left and right across the top of
the stage, the player can swipe to correct its path or tap to drop immediately,
and only the overlapping section survives on each successful stack.

## Gameplay

- Swipe horizontally to line up the active box, then release to drop.
- Tap to drop immediately when no correction is needed.
- Each successful stack adds 1 point to the run.
- Every 5 successful stacks increases horizontal movement speed.
- Missing the overlap threshold ends the run immediately.
- Drop, success, and fail events all trigger sound effects.

## Development Flow

- Read `harness/manifest.json` first.
- Work from `harness/specs/feature-swipe-stack-mvp.md`.
- Honor `harness/adrs/adr-swipe-stack-deterministic-stacking.md`.
- Keep implementation and verification aligned with repo-native harness docs.

## Verification

- `flutter analyze`
- `flutter test`
- `flutter build ios --simulator`
- `flutter build apk --debug`
