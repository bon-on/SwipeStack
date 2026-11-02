import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'sound_mute_store.dart';
import 'web_sound_stub.dart' if (dart.library.js_interop) 'web_sound_web.dart';

/// One-shot sound effects. Each maps to `assets/audio/<name>.wav`.
///
/// The original three keep their dedicated native methods; newer effects use
/// the generic native `play` method with the asset key.
enum Sfx {
  drop('drop', 'playDrop', 0.56),
  stackSuccess('stack_success', 'playStackSuccess', 0.72),
  fail('fail', 'playFail', 0.68),
  perfect('perfect', 'play', 0.7),
  streak('streak', 'play', 0.7),
  mission('mission', 'play', 0.75),
  levelUp('level_up', 'play', 0.8);

  const Sfx(this.fileName, this.nativeMethod, this.volume);

  final String fileName;
  final String nativeMethod;
  final double volume;

  String get assetKey => 'assets/audio/$fileName.wav';
}

/// Plays effects and the background music loop on web (HTML audio) and
/// through the native shell channel.
///
/// Nothing here throws or blocks the UI. One user toggle ([userMuted])
/// silences effects and music (SwipeStack has no portal layer with its own
/// mute). Music has a wanted state ([startMusic] / [stopMusic]) separate from
/// whether it actually plays: mute, a hidden app or tab and (on web) a
/// missing first user input all hold it back until they clear.
class SoundFx {
  SoundFx({
    this.store = const SoundMuteStore(),
    WebSound? webSound,
    MethodChannel? channel,
    bool? isWeb,
  }) : _webSound = webSound ?? WebSound(),
       _channel = channel ?? const MethodChannel('swipe_stack/audio'),
       _isWeb = isWeb ?? kIsWeb;

  static const String musicAsset = 'assets/audio/music_loop.wav';
  static const double musicVolume = 0.42;

  final SoundMuteStore store;
  final WebSound _webSound;
  final MethodChannel _channel;
  final bool _isWeb;

  bool _userMuted = false;
  bool _userTouched = false;

  bool _musicWanted = false;
  bool _musicPlaying = false;
  bool _musicStarting = false;
  bool _webLoopStarted = false;
  bool _appVisible = true;
  bool _userInteracted = false;

  bool get userMuted => _userMuted;

  bool get muted => _userMuted;

  /// True while the music loop is (believed to be) audible.
  bool get isMusicPlaying => _musicPlaying;

  /// True after [startMusic] until [stopMusic], even while held back.
  bool get isMusicWanted => _musicWanted;

  /// Loads the stored choice. A toggle made meanwhile wins.
  Future<void> initialize() async {
    final stored = await store.loadMuted();
    if (_userTouched) return;
    _userMuted = stored;
    _applyMusic();
  }

  Future<void> setUserMuted(bool value) async {
    _userTouched = true;
    _userMuted = value;
    _applyMusic();
    await store.saveMuted(value);
  }

  void play(Sfx sfx) {
    if (muted) return;
    if (_isWeb) {
      _webSound.play(sfx.assetKey, volume: sfx.volume);
      return;
    }
    if (sfx.nativeMethod == 'play') {
      _invoke('play', <String, Object>{
        'asset': sfx.assetKey,
        'volume': sfx.volume,
      });
    } else {
      _invoke(sfx.nativeMethod);
    }
  }

  /// Requests background music. It plays once nothing holds it back.
  void startMusic() {
    _musicWanted = true;
    _applyMusic();
  }

  /// Stops the music and forgets the request (ads, dispose).
  void stopMusic() {
    _musicWanted = false;
    _applyMusic();
  }

  /// Call when the app or browser tab is hidden or shown again.
  void setAppVisible(bool visible) {
    if (_appVisible == visible) return;
    _appVisible = visible;
    _applyMusic();
  }

  /// Call on pointer or key input. Browsers only allow music after the
  /// first one; a request made earlier starts now.
  void onUserInput() {
    if (_userInteracted) {
      // Retry a loop the browser refused earlier.
      if (_isWeb && _musicWanted && !_musicPlaying) _applyMusic();
      return;
    }
    _userInteracted = true;
    _applyMusic();
  }

  void dispose() {
    _musicWanted = false;
    _musicPlaying = false;
    _musicStarting = false;
    if (_isWeb) {
      _webSound.stopLoop();
      _webLoopStarted = false;
      return;
    }
    _invoke('disposeAudio');
  }

  bool get _musicAllowed =>
      _musicWanted && !muted && _appVisible && (!_isWeb || _userInteracted);

  void _applyMusic() {
    try {
      if (!_musicAllowed) {
        _holdMusicBack();
        return;
      }
      if (_musicPlaying || _musicStarting) return;
      if (_isWeb) {
        _startWebMusic();
      } else {
        _musicPlaying = true;
        _invoke('startLoop', <String, Object>{
          'asset': musicAsset,
          'volume': musicVolume,
        });
      }
    } catch (_) {
      // Music is optional and must never break the game.
    }
  }

  void _holdMusicBack() {
    if (_isWeb) {
      if (!_musicWanted) {
        if (_webLoopStarted) {
          _webSound.stopLoop();
          _webLoopStarted = false;
        }
      } else if (_musicPlaying) {
        _webSound.pauseLoop();
      }
      _musicPlaying = false;
      return;
    }
    if (_musicPlaying) {
      _musicPlaying = false;
      _invoke('stopLoop');
    }
  }

  void _startWebMusic() {
    _musicStarting = true;
    final Future<bool> started = _webLoopStarted
        ? _webSound.resumeLoop()
        : _webSound.loop(musicAsset, volume: musicVolume);
    started.then<bool>((ok) => ok, onError: (Object _) => false).then((ok) {
      _musicStarting = false;
      if (!ok) return;
      _webLoopStarted = true;
      _musicPlaying = true;
      // State may have changed while the browser was starting playback.
      _applyMusic();
    });
  }

  void _invoke(String method, [Object? arguments]) {
    if (_isWeb) return;
    try {
      _channel.invokeMethod<void>(method, arguments).catchError((Object _) {});
    } catch (_) {
      // Audio is optional where the native channel is unavailable.
    }
  }
}
