class AdService {
  AdService._();

  static final AdService instance = AdService._();

  bool get canRequestAds => false;

  bool get isInterstitialReady => false;

  Future<void> initialize() async {}

  Future<void> loadInterstitial() async {}

  /// Web builds are ad-free; nothing shows, so [onClosed] is never needed.
  bool showInterstitialIfReady({void Function()? onClosed}) => false;

  void dispose() {}
}
