---
id: feature-fair-start-and-starter-missions
title: Fair session timing and approachable starter missions
status: active
related_adrs:
  - adr-swipe-stack-deterministic-stacking
  - adr-swipe-stack-pwa-pages
related_contracts:
  - contract-swipe-stack-mvp
  - contract-swipe-stack-pwa-pages
---

# Fair session timing and approachable starter missions

## Problem
New players face long initial goals. Hidden time and loading-time gestures can decide a run before the player can react.

## Scope
Session timing/input fairness and approachable initial missions.

## Acceptance Criteria
- Simulation and play input run only while the app is resumed, initialized, and free of tutorial/theme overlays. Tutorial storage loading must block pointer input as well as keys.
- Returning from background or an overlay discards elapsed hidden time. A delayed active frame advances simulation by at most 1/30 second, preventing an unobserved hitch from deciding a drop.
- Existing audio visibility behavior remains unchanged. Deterministic overlap, movement speed, perfect tolerance, growth and scoring rules remain unchanged.
- Builder levels 1 and 2 receive three distinct starter goals: build 3 floors (15 XP), land 1 perfect drop (20 XP), reach 3 floors at half width (20 XP). Level 3 onward retains the existing randomized goal pool and progression. Injected mission boards remain supported.
- Mission rewards trigger once per run; resetting after reaching level 3 leaves the starter set.
- No new dependencies, portal build scripts, or active-play advertisements.

## Requirement mapping
| Requirement | Owner/files | Check |
| --- | --- | --- |
| Session fairness and loading input | controller_impl: screen and screen tests | Lifecycle, delayed frame and pending tutorial widget regressions |
| Early achievable goals | meta_impl: missions and meta tests | Starter targets, completion once, regular goals after reset |
| Integration | coordinator: spec and reports | analyze, all tests, Pages build, harness audit, independent review |

## Evidence
See reports/fair-start-verification.md for executed checks and limitations.

## Constraints
Preserve shared Flutter runtime, deterministic stacking rules and existing audio behavior. No dependencies or portal builds.
