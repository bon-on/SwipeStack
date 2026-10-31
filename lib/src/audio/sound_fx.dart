import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'sound_mute_store.dart';
import 'web_sound_stub.dart' if (dart.library.js_interop) 'web_sound_web.dart';

/// One-shot sound effects. Each maps to `assets/audio/<name>.wav`.
enum Sfx {
  drop('drop', 'playDrop', 0.56),
  stackSuccess('stack_success', 'playStackSuccess', 0.72),
  fail('fail', 'playFail', 0.68);

  const Sfx(this.fileName, this.nativeMethod, this.volume);

  final String fileName;
  final String nativeMethod;
  final double volume;

  String get assetKey => 'assets/audio/$fileName.wav';
}

/// Plays effects on web (HTML audio) and through the native shell channel.
///
/// Nothing here throws or blocks the UI. Playback is silent while
/// [userMuted] is on (SwipeStack has no portal layer with its own mute).
class SoundFx {
  SoundFx({
    this.store = const SoundMuteStore(),
    WebSound? webSound,
    MethodChannel? channel,
    bool? isWeb,
  }) : _webSound = webSound ?? WebSound(),
       _channel = channel ?? const MethodChannel('swipe_stack/audio'),
       _isWeb = isWeb ?? kIsWeb;

  final SoundMuteStore store;
  final WebSound _webSound;
  final MethodChannel _channel;
  final bool _isWeb;

  bool _userMuted = false;
  bool _userTouched = false;

  bool get userMuted => _userMuted;

  bool get muted => _userMuted;

  /// Loads the stored choice. A toggle made meanwhile wins.
  Future<void> initialize() async {
    final stored = await store.loadMuted();
    if (_userTouched) return;
    _userMuted = stored;
  }

  Future<void> setUserMuted(bool value) async {
    _userTouched = true;
    _userMuted = value;
    await store.saveMuted(value);
  }

  void play(Sfx sfx) {
    if (muted) return;
    if (_isWeb) {
      _webSound.play(sfx.assetKey, volume: sfx.volume);
      return;
    }
    _invoke(sfx.nativeMethod);
  }

  void dispose() {
    if (!_isWeb) _invoke('disposeAudio');
  }

  void _invoke(String method) {
    try {
      _channel.invokeMethod<void>(method).catchError((Object _) {});
    } catch (_) {
      // Audio is optional where the native channel is unavailable.
    }
  }
}
