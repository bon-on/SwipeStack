# SwipeStack PWA GitHub Pages Verification

## Commands

```sh
flutter test
flutter analyze
flutter build web --release --base-href /SwipeStack/
node /Users/junsik.park/sources/harness-lab/dist/index.js audit . --format md
```

## Results

- `flutter test`: passed, 9 tests.
- `flutter analyze`: passed, no issues found.
- `flutter build web --release --base-href /SwipeStack/`: passed, built `build/web`.
- Harness audit: passed, blocked `no`, 0 critical findings, 0 warnings.

## Build Path Check

`build/web/index.html` contains:

```html
<base href="/SwipeStack/">
```

`build/web/manifest.json` contains `SwipeStack` for both `name` and `short_name`.

## Notes

- Web builds use no-op ad service and banner implementations.
- Native iOS and Android project directories remain in the repository.
