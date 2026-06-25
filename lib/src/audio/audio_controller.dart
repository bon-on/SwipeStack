import 'package:flutter/services.dart';

class AudioController {
  static const MethodChannel _channel = MethodChannel('swipe_stack/audio');

  Future<void> initialize() async {}

  Future<void> playDrop() async => _invoke('playDrop');

  Future<void> playStackSuccess() async => _invoke('playStackSuccess');

  Future<void> playFail() async => _invoke('playFail');

  Future<void> dispose() async => _invoke('disposeAudio');

  Future<void> _invoke(String method) async {
    try {
      await _channel.invokeMethod<void>(method);
    } on MissingPluginException {
      return;
    } on PlatformException {
      return;
    }
  }
}
