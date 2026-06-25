---
id: adr-swipe-stack-deterministic-stacking
title: Use deterministic overlap stacking in a shared Flutter runtime
status: accepted
related_specs:
  - feature-swipe-stack-mvp
---

# ADR: Use deterministic overlap stacking in a shared Flutter runtime

## Context
SwipeStack needs the tactile feel of falling boxes, but the MVP also needs to
stay easy to test, fast to iterate on, and portable across iPhone and Android
without introducing a full external physics engine.

## Decision
Implement SwipeStack in one Flutter runtime with a shared game controller that
drives horizontal movement, drop timing, stacking resolution, difficulty ramp,
and persistence. Resolve stacked boxes with a deterministic horizontal overlap
rule: only the overlapping portion survives, and the run ends immediately when
the overlap ratio falls below the success threshold.

Use lightweight platform MethodChannel audio integration for required sound
effects instead of a heavier audio framework for v1.

## Consequences
- Core gameplay remains unit-testable because success and failure are derived
  from explicit overlap math instead of engine-side collision state.
- The shrinking overlap area naturally increases difficulty without extra rule
  systems.
- The visual result still communicates stacking and loss of width even without a
  full rigid-body simulation.
- Audio remains cross-platform but requires platform shell code in iOS and
  graceful no-op behavior when channels are unavailable in tests.
