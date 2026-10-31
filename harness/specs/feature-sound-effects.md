---
id: feature-sound-effects
title: Web sound effects and user mute toggle
status: active
owner: games
related_adrs:
  - adr-swipe-stack-deterministic-stacking
  - adr-swipe-stack-pwa-pages
related_contracts:
  - contract-swipe-stack-mvp
  - contract-swipe-stack-pwa-pages
required_evidence:
  - flutter-analyze
  - flutter-tests
  - web-build
  - harness-audit
---

# Feature Spec: Web sound effects and user mute toggle

## Problem
The drop, stack-success and fail sounds only play through the native iOS/Android shell channel, so the GitHub Pages build is silent. Players cannot mute the game, and the iOS audio session (`.playback`) ignores the silent switch and interrupts the user's music.

## Scope
- `lib/src/audio/sound_fx.dart` (`SoundFx`) replaces `AudioController`. The controller hooks stay the same: `onDrop` -> `drop`, `onStackSuccess` -> `stack_success`, `onFail` -> `fail` (once per game event, never per frame).
- Web: HTML `Audio` per asset (`web_sound_web.dart`, conditional import with a stub); reset `currentTime`, ignore `play()` rejections (autoplay policy). Sounds are triggered by taps and keys, which are user gestures.
- Native: the `swipe_stack/audio` MethodChannel keeps `playDrop`, `playStackSuccess`, `playFail`, `disposeAudio`. iOS uses audio session `.ambient`. Missing plugin or platform exceptions are swallowed.
- Mute: a sound `IconButton` next to the `?` button (`Icons.volume_up_rounded` / `Icons.volume_off_rounded`, tooltip "Sound on" / "Sound off") persists `sound_muted_v1` (bool, default on) through an injectable `SoundMuteStore`. There is no portal platform layer (Pages and mobile only), so the effective mute is the user mute. The sound-state load never delays the game start.
- The toggle follows the `?` button: it sits behind the tutorial card while it is open, refocuses the play area after a press when the card is closed, and adds no keyboard shortcut.
- No sound for the tutorial card. Existing wav files were generated for the project; no third-party audio and no new assets.

## Acceptance Criteria
- The toggle flips icon and tooltip and persists `sound_muted_v1`.
- Muted: no web audio and no native channel calls; unmuted: drop plays on a drop.
- The native method names are unchanged.
- Every asset referenced by `SoundFx` exists on disk and is bundled.
- Existing tests, including the tutorial tests, still pass.

## Constraints
- No new package dependencies. English ASCII strings in `lib/`.

## Evidence
- `flutter analyze`, `flutter test`
- `flutter build web --release --base-href /SwipeStack/`
- `node <harness-lab>/dist/index.js audit . --format md`
