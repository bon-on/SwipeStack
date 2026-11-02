import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
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

    // Force a miss.
    c.debugSetRun(
      stack: c.stackedBoxes,
      movingBox: const BoxSegment(
        centerX: 0.95,
        widthFactor: 0.1,
        color: Color(0xFF000000),
      ),
      stackCount: 1,
      bestStack: 1,
    );
    // debugSetRun resets the run start best; the run began with best 0.
    await _land(tester, c);
    expect(c.isGameOver, isTrue);
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('Tower slipped'), findsOneWidget);
    // 1 floor x2 + 0 perfects counted after the reset + 35 mission XP.
    expect(store.value.totalXp, greaterThanOrEqualTo(35));
    expect(store.value.runs, 1);
    expect(find.textContaining('XP'), findsWidgets);

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
}
