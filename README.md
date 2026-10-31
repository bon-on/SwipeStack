# SwipeStack

SwipeStack is a cross-platform Flutter timing game delivered with
spec-driven harness engineering. A box moves left and right across the top of
the stage, the player can swipe to correct its path or tap to drop immediately,
and only the overlapping section survives on each successful stack.

## Gameplay

- Swipe horizontally to line up the active box, then release to drop.
- Tap to drop immediately when no correction is needed.
- Keyboard: Space/Enter/ArrowDown drops, Left/Right (or A/D) nudge, R restarts.
- Each successful stack adds 1 point to the run.
- Every 5 successful stacks increases horizontal movement speed.
- Missing the overlap threshold ends the run immediately.
- Drop, success, and fail events all trigger sound effects (web and mobile).
- The speaker button next to `?` mutes or unmutes the game; the choice is
  stored in `shared_preferences` as `sound_muted_v1`.

## Sounds

`assets/audio/drop.wav`, `stack_success.wav` and `fail.wav` were generated for
this project; there is no third-party audio. New sounds should be produced by a
deterministic generator script rather than downloaded. On iOS the audio session is `.ambient`, so the silent switch is
respected and other apps' music keeps playing.

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
