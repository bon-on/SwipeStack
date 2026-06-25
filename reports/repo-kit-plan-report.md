# Harness Plan Report

- Title: Deliver SwipeStack cross-platform timing-stack MVP
- Spec: `/Users/junsik.park/sources/games/SwipeStack/harness/specs/feature-swipe-stack-mvp.md`
- Status: active

## Execution Order

1. Read spec intent and acceptance criteria from `harness/specs/feature-swipe-stack-mvp.md`.
2. Read ADR `adr-swipe-stack-deterministic-stacking` before design or implementation decisions.
3. Read ADR `adr-ad-supported-store-release` before ad or store-release decisions.
4. Read contract `contract-swipe-stack-mvp` to lock chunk-level done criteria.
5. Reconcile spec requirements with repo constraints and golden rules.
6. Implement the smallest change that satisfies acceptance criteria.
7. Collect required evidence and record escalation points.

## Acceptance Criteria

- The game starts and runs from one Flutter codebase on iPhone and Android.
- Tapping during active play drops the moving box immediately.
- Dragging horizontally during active play nudges the moving box, and releasing a drag drops it without bypassing the deterministic overlap rule.
- A dropped box stacks successfully only when its overlap meets the deterministic success rule.
- The game ends immediately when a dropped box misses the success threshold.
- Horizontal movement speed increases after every 5 successful stacks.
- Drop, stack success, and fail events trigger audible feedback.
- Ads never interrupt active play; banners occupy their own safe-area slot and interstitials are only eligible after completed runs.
- Platform manifests include AdMob app identifiers and advertising ID metadata needed for test builds.
- Analysis, tests, and runnable iOS/Android builds are expected.

## Related Constraints

- Keep the MVP offline and single-player.
- Use deterministic overlap stacking instead of a full physics engine.
- Keep gameplay logic shared across platforms and platform code limited to shell integration.
- Future gameplay changes must be captured in `harness/specs/` before code changes.

## Related ADRs

- `adr-swipe-stack-deterministic-stacking` (accepted): Use deterministic overlap stacking in a shared Flutter runtime.
- `adr-ad-supported-store-release` (accepted): Use conservative AdMob placements for store release.

## Related Contracts

- `contract-swipe-stack-mvp` (draft): SwipeStack MVP gameplay and feedback contract.

## Required Evidence

- `flutter analyze`
- `flutter test`
- `flutter build ios --simulator`
- `flutter build apk --debug`
- `node /Users/junsik.park/sources/harness-lab/dist/index.js audit /Users/junsik.park/sources/games/SwipeStack --format md`
- `node /Users/junsik.park/sources/harness-lab/dist/index.js plan /Users/junsik.park/sources/games/SwipeStack/harness/specs/feature-swipe-stack-mvp.md --format text`

## Blockers

- none
