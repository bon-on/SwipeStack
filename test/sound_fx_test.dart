import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:swipe_stack/src/audio/sound_fx.dart';
import 'package:swipe_stack/src/audio/sound_mute_store.dart';
import 'package:swipe_stack/src/audio/web_sound_stub.dart';
import 'package:swipe_stack/src/game/how_to_play.dart';
import 'package:swipe_stack/src/game/swipe_stack_screen.dart';

class _FakeWeb extends WebSound {
  final List<String> calls = <String>[];

  @override
  void play(String assetKey, {double volume = 1}) => calls.add(assetKey);
}

class _LoopWeb extends WebSound {
  final List<String> events = <String>[];
  bool allow = true;

  @override
  void play(String assetKey, {double volume = 1}) => events.add('play');

  @override
  Future<bool> loop(String assetKey, {double volume = 1}) async {
    events.add('loop');
    return allow;
  }

  @override
  void stopLoop() => events.add('stop');

  @override
  void pauseLoop() => events.add('pause');

  @override
  Future<bool> resumeLoop() async {
    events.add('resume');
    return allow;
  }
}

class _MemoryMuteStore extends SoundMuteStore {
  bool muted = false;
  int writes = 0;

  @override
  Future<bool> loadMuted() async => muted;

  @override
  Future<void> saveMuted(bool value) async {
    muted = value;
    writes += 1;
  }
}

class _SeenStore extends HowToPlayStore {
  @override
  Future<bool> loadSeen() async => true;
}

const _channel = MethodChannel('swipe_stack/audio');

List<String> _recordChannel() {
  final calls = <String>[];
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_channel, (call) async {
        calls.add(call.method);
        return null;
      });
  addTearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null),
  );
  return calls;
}

Future<void> _settle() => Future<void>.delayed(Duration.zero);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('web playback maps each effect to its asset and honors mute', () async {
    final web = _FakeWeb();
    final fx = SoundFx(webSound: web, isWeb: true);
    fx.play(Sfx.drop);
    fx.play(Sfx.stackSuccess);
    fx.play(Sfx.fail);
    expect(web.calls, [
      'assets/audio/drop.wav',
      'assets/audio/stack_success.wav',
      'assets/audio/fail.wav',
    ]);
    web.calls.clear();
    await fx.setUserMuted(true);
    fx.play(Sfx.drop);
    expect(web.calls, isEmpty);
  });

  test('native playback keeps the existing method names', () async {
    final calls = _recordChannel();
    final fx = SoundFx(isWeb: false);
    fx.play(Sfx.drop);
    fx.play(Sfx.stackSuccess);
    fx.play(Sfx.fail);
    fx.dispose();
    await _settle();
    expect(calls, ['playDrop', 'playStackSuccess', 'playFail', 'disposeAudio']);
    calls.clear();
    await fx.setUserMuted(true);
    fx.play(Sfx.drop);
    await _settle();
    expect(calls, isEmpty);
  });

  test('web music waits for input, follows mute, visibility and ads', () async {
    final web = _LoopWeb();
    final fx = SoundFx(webSound: web, isWeb: true, store: _MemoryMuteStore());
    fx.startMusic();
    await _settle();
    expect(web.events, isEmpty, reason: 'no audio before the first input');
    fx.onUserInput();
    await _settle();
    expect(web.events, ['loop']);
    expect(fx.isMusicPlaying, isTrue);

    await fx.setUserMuted(true);
    expect(web.events.last, 'pause');
    expect(fx.isMusicPlaying, isFalse);
    await fx.setUserMuted(false);
    await _settle();
    expect(web.events.last, 'resume');

    fx.setAppVisible(false);
    expect(web.events.last, 'pause');
    fx.setAppVisible(true);
    await _settle();
    expect(web.events.last, 'resume');

    // Ads stop the loop; it starts again afterwards.
    fx.stopMusic();
    expect(web.events.last, 'stop');
    fx.startMusic();
    await _settle();
    expect(web.events.last, 'loop');
    fx.dispose();
    expect(web.events.last, 'stop');
  });

  test('a refused web loop retries on the next input', () async {
    final web = _LoopWeb()..allow = false;
    final fx = SoundFx(webSound: web, isWeb: true);
    fx.startMusic();
    fx.onUserInput();
    await _settle();
    expect(fx.isMusicPlaying, isFalse);
    web.allow = true;
    fx.onUserInput();
    await _settle();
    expect(fx.isMusicPlaying, isTrue);
  });

  test(
    'native music uses startLoop/stopLoop and new effects use play',
    () async {
      final calls = _recordChannel();
      final fx = SoundFx(isWeb: false, store: _MemoryMuteStore());
      fx.startMusic();
      fx.play(Sfx.perfect);
      await _settle();
      expect(calls, ['startLoop', 'play']);
      await fx.setUserMuted(true);
      await _settle();
      expect(calls.last, 'stopLoop');
      fx.play(Sfx.levelUp);
      await _settle();
      expect(calls.last, 'stopLoop');
    },
  );

  test('music loop asset is small enough for the web build', () {
    final file = File(SoundFx.musicAsset);
    expect(file.existsSync(), isTrue);
    expect(file.lengthSync(), lessThanOrEqualTo(1024 * 1024));
  });

  test('a missing native channel is swallowed', () async {
    final fx = SoundFx(isWeb: false);
    fx.play(Sfx.fail);
    fx.dispose();
    await _settle();
  });

  test('mute choice persists under sound_muted_v1', () async {
    SharedPreferences.setMockInitialValues({});
    const store = SoundMuteStore();
    expect(await store.loadMuted(), isFalse);
    await store.saveMuted(true);
    expect(await store.loadMuted(), isTrue);
    expect(
      (await SharedPreferences.getInstance()).getBool('sound_muted_v1'),
      isTrue,
    );
    final fx = SoundFx(isWeb: true, webSound: _FakeWeb());
    await fx.initialize();
    expect(fx.userMuted, isTrue);
  });

  test('every audio asset used by SoundFx exists and is bundled', () {
    expect(
      File('pubspec.yaml').readAsStringSync(),
      contains('- assets/audio/'),
    );
    for (final sfx in Sfx.values) {
      final file = File(sfx.assetKey);
      expect(file.existsSync(), isTrue, reason: sfx.assetKey);
      expect(file.lengthSync(), lessThan(40 * 1024), reason: sfx.assetKey);
    }
  });

  testWidgets('toggle flips icon, persists, and silences gameplay sounds', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final calls = _recordChannel();
    final store = _MemoryMuteStore();
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: SwipeStackScreen(
          howToPlayStore: _SeenStore(),
          soundMuteStore: store,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byIcon(Icons.volume_up_rounded), findsOneWidget);
    expect(find.byTooltip('Sound on'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.volume_up_rounded));
    await tester.pump();
    expect(find.byIcon(Icons.volume_off_rounded), findsOneWidget);
    expect(find.byTooltip('Sound off'), findsOneWidget);
    expect(store.muted, isTrue);
    expect(store.writes, 1);
    expect(FocusManager.instance.primaryFocus?.debugLabel, 'SwipeStackPlay');

    calls.clear();
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump(const Duration(milliseconds: 100));
    expect(calls, isEmpty);

    await tester.tap(find.byIcon(Icons.volume_off_rounded));
    await tester.pump();
    expect(find.byIcon(Icons.volume_up_rounded), findsOneWidget);
    expect(store.muted, isFalse);
    // Drain the drop animation so no timers outlive the test.
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('unmuted drop plays the drop sound', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final calls = _recordChannel();
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: SwipeStackScreen(
          howToPlayStore: _SeenStore(),
          soundMuteStore: _MemoryMuteStore(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump(const Duration(milliseconds: 100));
    expect(calls, contains('playDrop'));
    await tester.pump(const Duration(seconds: 3));
  });
}
