# SwipeStack

SwipeStack is a cross-platform Flutter timing game delivered with
spec-driven harness engineering. You build a tower into the sky: a floor moves
left and right across the top of the stage, you swipe to correct its path or
tap to drop immediately, and only the overlapping section survives on each
successful stack. The camera rises with the tower and the sky turns from day
to sunset to space.

## Gameplay

- Swipe horizontally to line up the active box, then release to drop.
- Tap to drop immediately when no correction is needed.
- Keyboard: Space/Enter/ArrowDown drops, Left/Right (or A/D) nudge, R restarts.
- Each successful stack adds 1 point to the run.
- Every 5 successful stacks increases horizontal movement speed.
- Missing the overlap threshold ends the run immediately.
- Drop, success, and fail events all trigger sound effects (web and mobile).
- The speaker button next to `?` mutes or unmutes the game (effects and
  music); the choice is stored in `shared_preferences` as `sound_muted_v1`.
- Perfect drops flash and build a "Perfect xN" streak; imperfect drops cut off
  a falling chip; a miss topples the top of the tower.
- Every run has 3 missions that pay XP. Builder XP (floors, perfect drops,
  missions) raises your level and unlocks 4 cosmetic themes: Downtown (Lv1),
  Harbor (Lv3), Candy (Lv6) and Neon (Lv10).
- The best height stays under the original `best_stack` key. XP, the chosen
  theme and lifetime records are stored as JSON under `tower_progress_v1`;
  corrupt values fall back to defaults.
- Wide landscape screens show side panels (stats, level, records, missions,
  controls); portrait phones stack everything in one column.

## Sounds

All audio was generated for this project; there is no third-party audio.
`drop.wav`, `stack_success.wav` and `fail.wav` are the original effects. The
music loop (`music_loop.wav`, 16 kHz mono, about 720 KB) and the `perfect`,
`streak`, `mission` and `level_up` effects come from a deterministic,
standard-library-only generator:

```sh
python3 tool/generate_sounds.py
```

On web the music starts after the first tap or key press, pauses while the tab
is hidden and stops during full-screen ads on mobile. On iOS the audio session is `.ambient`, so the silent switch is
respected and other apps' music keeps playing.

## Development Flow

- Read `harness/manifest.json` first.
- Work from `harness/specs/feature-swipe-stack-mvp.md` and
  `harness/specs/feature-retention-polish.md`.
- Honor `harness/adrs/adr-swipe-stack-deterministic-stacking.md`.
- Keep implementation and verification aligned with repo-native harness docs.

## Verification

- `flutter analyze`
- `flutter test`
- `flutter build web --release --base-href /SwipeStack/`
- `flutter build ios --simulator`
- `flutter build apk --debug`
