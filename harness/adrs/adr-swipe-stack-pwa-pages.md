---
id: adr-swipe-stack-pwa-pages
title: Use Flutter Web and GitHub Pages for SwipeStack PWA deployment
status: accepted
related_specs:
  - feature-swipe-stack-pwa-pages
---

# ADR: Use Flutter Web and GitHub Pages for SwipeStack PWA Deployment

## Context

Developer-signed iPhone builds require recurring re-signing. SwipeStack is a timing-stack game that can run as a Flutter web app, so a PWA offers a lower-maintenance play path.

## Decision

Keep the native mobile app and add Flutter web output served by `bon-on/SwipeStack` GitHub Pages. Build with `--base-href /SwipeStack/`. On web, replace AdMob service and banner implementations with no-op implementations.

## Consequences

- The iPhone home-screen app avoids native signing expiry.
- GitHub Pages can host the static Flutter web build.
- Web builds are ad-free until a web-specific ad product is configured.
- The mobile AdMob path remains available for native builds.
