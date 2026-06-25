---
id: adr-ad-supported-store-release
title: Use conservative AdMob placements for store release
status: accepted
related_specs:
  - feature-swipe-stack-mvp
---

# ADR: Use conservative AdMob placements for store release

## Context
SwipeStack is intended for App Store and Play Store release as a free game with
advertising. Ads must not distort the timing loop or create policy risk by
interrupting active play.

## Decision
Use the official Google Mobile Ads Flutter plugin. Request consent through the
SDK's UMP flow before requesting ads, initialize the SDK at app startup when ads
can be requested, use test ad IDs until store-specific AdMob IDs are available,
show a bottom banner in a dedicated layout slot, and make interstitial ads
eligible only after completed runs at a low frequency.

## Consequences
- Gameplay stays deterministic because ad loading is outside the controller.
- Store metadata must disclose AdMob, advertising identifiers, and third-party
  data handling.
- Production release requires replacing test IDs with real AdMob app and ad
  unit IDs before submission.
