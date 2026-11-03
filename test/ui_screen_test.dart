import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:swipe_stack/src/ads/interstitial_gate.dart';
import 'package:swipe_stack/src/game/how_to_play.dart';
import 'package:swipe_stack/src/game/swipe_stack_controller.dart';
import 'package:swipe_stack/src/game/swipe_stack_models.dart';
import 'package:swipe_stack/src/game/swipe_stack_painter.dart';
import 'package:swipe_stack/src/game/swipe_stack_screen.dart';
import 'package:swipe_stack/src/meta/missions.dart';
import 'package:swipe_stack/src/meta/tower_progress.dart';
import 'package:swipe_stack/src/meta/tower_progress_store.dart';
import 'package:swipe_stack/src/meta/tower_theme.dart';
import 'package:swipe_stack/src/persistence/best_stack_store.dart';

class _SeenStore extends HowToPlayStore {
  const _SeenStore();
  @override
  Future<bool> loadSeen() async => true;
  @override
  Future<void> markSeen() async {}
}

class _BestStore extends BestStackStore {
  _BestStore([this.value = 0]);
  int value;
  @override
  Future<int> loadBestStack() async => value;
  @override
  Future<void> saveBestStack(int bestStack) async => value = bestStack;
}

/// Load completes only when [gate] completes.
class _GatedProgressStore extends MemoryTowerProgressStore {
  _GatedProgressStore(super.value);
  final Completer<void> gate = Completer<void>();
  @override
  Future<TowerProgress> load() async {
    await gate.future;
    return super.load();
  }
}

class _FakeAds extends InterstitialGate {
  bool ready = false;
  int shows = 0;
  int preloads = 0;
  void Function()? onClosed;

  @override
  bool get isReady => ready;

  @override
  bool show({void Function()? onClosed}) {
    shows += 1;
    this.onClosed = onClosed;
    return true;
  }

  @override
  void preload() => preloads += 1;
}

const _audio = MethodChannel('swipe_stack/audio');

List<String> _recordAudio() {
  final calls = <String>[];
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_audio, (call) async {
        calls.add(call.method);
        return null;
      });
  addTearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_audio, null),
  );
  return calls;
}

List<String> _loopCalls(List<String> calls) =>
    calls.where((c) => c == 'startLoop' || c == 'stopLoop').toList();

const _base = BoxSegment(
  centerX: 0.5,
  widthFactor: 0.74,
  color: Color(0xFF45647A),
);

SwipeStackController _controller({int best = 0}) => SwipeStackController(
  bestStackStore: _BestStore(best),
  random: math.Random(3),
);

MissionBoard _board() => MissionBoard(
  missions: const <Mission>[
    Mission(kind: MissionKind.buildFloors, target: 1, xp: 15),
    Mission(kind: MissionKind.perfectDrops, target: 1, xp: 20),
    Mission(kind: MissionKind.perfectStreak, target: 3, xp: 25),
  ],
);

Future<void> _pump(
  WidgetTester tester,
  SwipeStackController controller, {
  Size size = const Size(390, 844),
  TowerProgressStore? store,
  MissionBoard? missions,
  InterstitialGate? ads,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  addTearDown(controller.dispose);
  await tester.pumpWidget(
    MaterialApp(
      home: SwipeStackScreen(
        controller: controller,
        howToPlayStore: const _SeenStore(),
        progressStore: store ?? MemoryTowerProgressStore(),
        missions: missions,
        enableAds: ads != null,
        interstitials: ads ?? const AdServiceInterstitials(),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 16));
}

/// Lands the moving box with the screen's own ticker.
Future<void> _land(WidgetTester tester, SwipeStackController c) async {
  c.drop();
  for (var i = 0; i < 80 && c.isDropping; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

void main() {
  const sizes = <Size>[
    Size(1280, 720),
    Size(1366, 768),
    Size(390, 844),
    Size(844, 390),
    Size(667, 375),
    Size(800, 600),
    Size(360, 640),
  ];

  for (final size in sizes) {
    testWidgets('no overflow while playing at $size', (tester) async {
      final c = _controller();
      c.debugSetRun(stack: const <BoxSegment>[_base], movingBox: _base);
      await _pump(tester, c, size: size);
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
      expect(find.text('SwipeStack'), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (w) => w is CustomPaint && w.painter is SwipeStackPainter,
        ),
        findsOneWidget,
      );
    });

    testWidgets('no overflow on the run summary at $size', (tester) async {
      final c = _controller();
      c.debugSetRun(
        stack: const <BoxSegment>[_base],
        movingBox: _base,
        stackCount: 12,
        isGameOver: true,
      );
      await _pump(tester, c, size: size);
      await tester.pump(const Duration(seconds: 2));
      expect(tester.takeException(), isNull);
      expect(find.text('Tower slipped'), findsOneWidget);
      expect(find.text('Play again'), findsOneWidget);
    });

    testWidgets('no overflow in the theme picker at $size', (tester) async {
      final c = _controller();
      c.debugSetRun(stack: const <BoxSegment>[_base], movingBox: _base);
      await _pump(
        tester,
        c,
        size: size,
        store: MemoryTowerProgressStore(
          const TowerProgress.initial().mergedWith(
            const TowerProgress(
              totalXp: 600,
              selectedTheme: TowerTheme.downtown,
              totalFloors: 0,
              totalPerfects: 0,
              runs: 0,
              bestStreak: 0,
            ),
          ),
        ),
      );
      final opener = find.byTooltip('Themes').evaluate().isNotEmpty
          ? find.byTooltip('Themes')
          : find.textContaining('Theme:');
      await tester.tap(opener);
      await tester.pump();
      expect(find.text('Tower themes'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('landing completes missions; game over shows XP and New best', (
    tester,
  ) async {
    final store = MemoryTowerProgressStore();
    final c = _controller(best: 0);
    c.debugSetRun(stack: const <BoxSegment>[_base], movingBox: _base);
    await _pump(tester, c, store: store, missions: _board());
    await _land(tester, c);
    expect(c.stackCount, 1);
    expect(c.lastDropPerfect, isTrue);
    // Two of three missions done.
    expect(find.text('+15 XP'), findsOneWidget);
    expect(find.text('+20 XP'), findsOneWidget);

    // Force a miss, keeping this run's stats (1 floor, 1 perfect, started
    // with best 0).
    c.debugSetRun(
      stack: c.stackedBoxes,
      movingBox: const BoxSegment(
        centerX: 0.95,
        widthFactor: 0.1,
        color: Color(0xFF000000),
      ),
      stackCount: 1,
      bestStack: 1,
      runStartBest: 0,
      runPerfectCount: 1,
      perfectStreak: 1,
    );
    await _land(tester, c);
    expect(c.isGameOver, isTrue);
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('Tower slipped'), findsOneWidget);
    expect(find.text('New best!'), findsOneWidget);
    // 1 floor x2 + 1 perfect x3 + 35 mission XP; no participation bonus.
    expect(store.value.totalXp, 40);
    expect(store.value.runs, 1);
    expect(find.text('+40 XP'), findsOneWidget);

    // Enter plays again and the summary goes away.
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(c.isGameOver, isFalse);
    expect(find.text('Tower slipped'), findsNothing);
    expect(FocusManager.instance.primaryFocus?.debugLabel, 'SwipeStackPlay');
  });

  testWidgets('summary blocks taps on the play field', (tester) async {
    final c = _controller();
    c.debugSetRun(
      stack: const <BoxSegment>[_base],
      movingBox: _base,
      stackCount: 3,
      isGameOver: true,
    );
    await _pump(tester, c);
    await tester.pump(const Duration(seconds: 2));
    await tester.tapAt(const Offset(195, 300));
    await tester.pump();
    expect(c.isGameOver, isTrue);
    expect(c.isDropping, isFalse);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(c.isGameOver, isFalse);
  });

  testWidgets('a mid-run restart still earns XP', (tester) async {
    final store = MemoryTowerProgressStore();
    final c = _controller();
    c.debugSetRun(stack: const <BoxSegment>[_base], movingBox: _base);
    await _pump(tester, c, store: store, missions: _board());
    await _land(tester, c);
    expect(c.stackCount, 1);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyR);
    await tester.pump();
    expect(c.stackCount, 0);
    expect(store.value.runs, 1);
    expect(
      store.value.totalXp,
      TowerProgress.xpForRun(
        const RunSummary(floors: 1, perfects: 1, bestStreak: 1, missionXp: 35),
      ),
    );
    // A second restart of an empty run adds nothing.
    await tester.sendKeyEvent(LogicalKeyboardKey.keyR);
    await tester.pump();
    expect(store.value.runs, 1);
  });

  testWidgets('runs that end before progress loads are merged, not lost', (
    tester,
  ) async {
    final store = _GatedProgressStore(
      const TowerProgress(
        totalXp: 50,
        selectedTheme: TowerTheme.downtown,
        totalFloors: 10,
        totalPerfects: 0,
        runs: 2,
        bestStreak: 1,
      ),
    );
    final c = _controller();
    c.debugSetRun(stack: const <BoxSegment>[_base], movingBox: _base);
    await _pump(tester, c, store: store, missions: _board());
    await _land(tester, c);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyR);
    await tester.pump();
    expect(store.saveCount, 0, reason: 'no save before the load');
    store.gate.complete();
    await tester.pump();
    await tester.pump();
    expect(store.saveCount, 1);
    expect(store.value.runs, 3);
    expect(store.value.totalFloors, 11);
    expect(store.value.totalXp, greaterThan(50));
  });

  testWidgets('theme picker: locked themes stay locked, Esc closes', (
    tester,
  ) async {
    final store = MemoryTowerProgressStore(
      TowerProgress.fromJson(<String, Object>{'totalXp': 150}),
    );
    final c = _controller();
    c.debugSetRun(stack: const <BoxSegment>[_base], movingBox: _base);
    await _pump(tester, c, store: store, size: const Size(1280, 720));
    await tester.tap(find.textContaining('Theme:'));
    await tester.pump();
    expect(find.text('Tower themes'), findsOneWidget);
    // Neon needs level 10.
    await tester.tap(find.text('Neon'));
    await tester.pump();
    expect(store.value.selectedTheme, TowerTheme.downtown);
    await tester.tap(find.text('Harbor'));
    await tester.pump();
    expect(store.value.selectedTheme, TowerTheme.harbor);
    // Game keys do nothing while the picker is open.
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(c.isDropping, isFalse);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(find.text('Tower themes'), findsNothing);
    expect(find.text('Theme: Harbor'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(c.isDropping, isTrue);
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('summary ignores drop keys and taps until it has faded in', (
    tester,
  ) async {
    final c = _controller();
    c.debugSetRun(
      stack: const <BoxSegment>[_base],
      movingBox: _base,
      stackCount: 4,
      isGameOver: true,
    );
    await _pump(tester, c);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(c.isGameOver, isTrue);
    await tester.tap(find.text('Play again'), warnIfMissed: false);
    await tester.pump();
    expect(c.isGameOver, isTrue);
    await tester.pump(const Duration(milliseconds: 1200));
    await tester.tap(find.text('Play again'));
    await tester.pump();
    expect(c.isGameOver, isFalse);
  });

  testWidgets('R restarts from the summary immediately', (tester) async {
    final c = _controller();
    c.debugSetRun(
      stack: const <BoxSegment>[_base],
      movingBox: _base,
      stackCount: 4,
      isGameOver: true,
    );
    await _pump(tester, c);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyR);
    await tester.pump();
    expect(c.isGameOver, isFalse);
  });

  testWidgets('reopening the summary after themes does not replay or lock', (
    tester,
  ) async {
    final c = _controller();
    c.debugSetRun(
      stack: const <BoxSegment>[_base],
      movingBox: _base,
      stackCount: 4,
      isGameOver: true,
    );
    await _pump(tester, c);
    await tester.pump(const Duration(milliseconds: 1500));
    await tester.tap(find.text('Themes'));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    await tester.pump();
    expect(find.text('Tower themes'), findsNothing);
    // Armed at once: Enter plays again without waiting.
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(c.isGameOver, isFalse);
  });

  group('music around ads and app visibility', () {
    Future<void> gameOver(WidgetTester tester, SwipeStackController c) async {
      c.debugSetRun(
        stack: const <BoxSegment>[_base],
        movingBox: const BoxSegment(
          centerX: 0.97,
          widthFactor: 0.06,
          color: Color(0xFF000000),
        ),
      );
      await _land(tester, c);
      expect(c.isGameOver, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyR);
      await tester.pump();
    }

    testWidgets('music stops for a ready ad and restarts only after close', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final calls = _recordAudio();
      final ads = _FakeAds()..ready = true;
      final c = _controller();
      c.debugSetRun(stack: const <BoxSegment>[_base], movingBox: _base);
      await _pump(tester, c, ads: ads);
      expect(_loopCalls(calls), <String>['startLoop']);
      await gameOver(tester, c);
      await gameOver(tester, c);
      expect(ads.shows, 0);
      expect(_loopCalls(calls), <String>['startLoop']);
      await gameOver(tester, c);
      expect(ads.shows, 1);
      expect(_loopCalls(calls), <String>['startLoop', 'stopLoop']);
      await tester.pump(const Duration(seconds: 1));
      expect(_loopCalls(calls).last, 'stopLoop');
      ads.onClosed!();
      await tester.pump();
      expect(_loopCalls(calls), <String>['startLoop', 'stopLoop', 'startLoop']);
    });

    testWidgets('no ad ready: the music keeps playing', (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final calls = _recordAudio();
      final ads = _FakeAds();
      final c = _controller();
      c.debugSetRun(stack: const <BoxSegment>[_base], movingBox: _base);
      await _pump(tester, c, ads: ads);
      for (var i = 0; i < 3; i++) {
        await gameOver(tester, c);
      }
      expect(ads.shows, 0);
      expect(ads.preloads, 3);
      expect(_loopCalls(calls), <String>['startLoop']);
    });

    testWidgets('hidden or paused app holds the music back', (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final calls = _recordAudio();
      final c = _controller();
      c.debugSetRun(stack: const <BoxSegment>[_base], movingBox: _base);
      await _pump(tester, c);
      expect(_loopCalls(calls), <String>['startLoop']);
      Future<void> to(AppLifecycleState state) async {
        tester.binding.handleAppLifecycleStateChanged(state);
        await tester.pump();
      }

      await to(AppLifecycleState.resumed);
      await to(AppLifecycleState.inactive);
      expect(_loopCalls(calls), <String>['startLoop']);
      await to(AppLifecycleState.hidden);
      expect(_loopCalls(calls), <String>['startLoop', 'stopLoop']);
      await to(AppLifecycleState.paused);
      await to(AppLifecycleState.hidden);
      expect(_loopCalls(calls), <String>['startLoop', 'stopLoop']);
      await to(AppLifecycleState.inactive);
      await to(AppLifecycleState.resumed);
      expect(_loopCalls(calls), <String>['startLoop', 'stopLoop', 'startLoop']);
    });

    test('lifecycle mapping', () {
      expect(
        SwipeStackScreen.isVisibleState(AppLifecycleState.resumed),
        isTrue,
      );
      expect(
        SwipeStackScreen.isVisibleState(AppLifecycleState.inactive),
        isTrue,
      );
      expect(
        SwipeStackScreen.isVisibleState(AppLifecycleState.hidden),
        isFalse,
      );
      expect(
        SwipeStackScreen.isVisibleState(AppLifecycleState.paused),
        isFalse,
      );
      expect(
        SwipeStackScreen.isVisibleState(AppLifecycleState.detached),
        isFalse,
      );
    });
  });
}
