# SwipeStack PWA GitHub Pages Deployment

## URL

```text
https://bon-on.github.io/SwipeStack/
```

## Local Build

```sh
flutter build web --release --base-href /SwipeStack/
```

## Deployment

`.github/workflows/deploy-pages.yml` runs tests, builds the web app for `/SwipeStack/`, uploads `build/web`, and deploys it with GitHub Pages.

The repository Pages source must be set to GitHub Actions.

## iPhone Install

Open the URL in Safari, use Share, then choose Add to Home Screen.

The PWA avoids iOS app signing expiry, but Safari/WebKit may still evict cached data under storage pressure.
