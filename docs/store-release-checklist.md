# Swipe Stack Store Release Checklist

- Create AdMob apps for iOS and Android and replace test app/ad unit IDs.
- Publish `app-ads.txt` on the developer website with the real AdMob publisher
  ID.
- Publish a public privacy policy URL and add it to App Store Connect and Play
  Console.
- Complete App Store Privacy Nutrition Labels for local storage and AdMob data.
- Complete Google Play Data safety and Advertising ID declarations.
- Configure Android release signing and build `flutter build appbundle
  --release`.
- Configure Apple signing and archive a release build for App Store Connect.
- Capture final phone screenshots for both stores after ads are enabled with
  production-safe configuration.
