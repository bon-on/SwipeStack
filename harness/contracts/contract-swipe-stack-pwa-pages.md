---
id: contract-swipe-stack-pwa-pages
title: SwipeStack PWA GitHub Pages deployment contract
status: active
related_specs:
  - feature-swipe-stack-pwa-pages
evidence_files:
  - docs/pwa-github-pages.md
  - reports/swipe-stack-pwa-pages-verification.md
---

# Contract: SwipeStack PWA GitHub Pages Deployment

## Goal

Publish SwipeStack as a Flutter web/PWA build at `https://bon-on.github.io/SwipeStack/`.

## Scope

- Flutter web scaffold and PWA metadata.
- GitHub Pages workflow.
- Web no-op ad service and banner implementations.
- Deployment documentation and verification report.

## Done Criteria

- `flutter test` passes.
- `flutter build web --release --base-href /SwipeStack/` passes.
- Harness audit has no critical findings or warnings.
- GitHub Pages serves the deployed app URL.

## Verification

```sh
flutter test
flutter build web --release --base-href /SwipeStack/
node /Users/junsik.park/sources/harness-lab/dist/index.js audit . --format md
```

## Evidence References

- docs/pwa-github-pages.md
- reports/swipe-stack-pwa-pages-verification.md
