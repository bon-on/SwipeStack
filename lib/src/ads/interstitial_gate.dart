import 'ad_service.dart';

/// The interstitial calls the game screen needs; tests inject a fake.
abstract class InterstitialGate {
  const InterstitialGate();

  /// True when an ad is loaded and [show] would display it.
  bool get isReady;

  /// Shows a loaded ad. Returns whether it is showing; if so, [onClosed]
  /// runs once it is dismissed or fails to show.
  bool show({void Function()? onClosed});

  /// Starts loading the next ad if none is loaded.
  void preload();
}

/// Default gate backed by [AdService].
class AdServiceInterstitials extends InterstitialGate {
  const AdServiceInterstitials();

  @override
  bool get isReady => AdService.instance.isInterstitialReady;

  @override
  bool show({void Function()? onClosed}) =>
      AdService.instance.showInterstitialIfReady(onClosed: onClosed);

  @override
  void preload() {
    AdService.instance.loadInterstitial();
  }
}
