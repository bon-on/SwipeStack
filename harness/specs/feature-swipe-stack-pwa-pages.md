---
id: feature-swipe-stack-pwa-pages
title: SwipeStack PWA GitHub Pages deployment
status: active
owner: games
related_adrs:
  - adr-swipe-stack-pwa-pages
related_contracts:
  - contract-swipe-stack-pwa-pages
required_evidence:
  - flutter-tests
  - flutter-web-build
  - harness-audit
---

# Feature Spec: SwipeStack PWA GitHub Pages Deployment

## Problem

Directly installed iPhone builds can stop launching when their signing expires. SwipeStack needs a public web/PWA path that can be added to the iPhone home screen without App Store distribution.

## Scope

- Keep the existing iOS and Android native projects.
- Add Flutter web/PWA output for GitHub Pages.
- Serve from the `/SwipeStack/` project path.
- Set PWA metadata to the SwipeStack name and app colors.
- Treat mobile AdMob calls as no-op on web.
- Deploy with GitHub Actions after tests pass.

## Acceptance Criteria

- `flutter test` passes.
- `flutter build web --release --base-href /SwipeStack/` passes.
- The built web app resolves assets from `https://bon-on.github.io/SwipeStack/`.
- iOS and Android native directories remain in place.
- Web builds do not initialize or request AdMob ads.
- GitHub Pages deploys from `build/web`.

## Constraints

- Gameplay logic remains shared across iPhone and Android.
- Ads must remain outside active play and use dedicated layout slots.
- The PWA path is ad-free unless a separate web ad product is configured later.

## Evidence

- `flutter test`
- `flutter build web --release --base-href /SwipeStack/`
- `node /Users/junsik.park/sources/harness-lab/dist/index.js audit . --format md`
