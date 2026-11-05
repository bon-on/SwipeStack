import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swipe_stack/src/game/how_to_play.dart';
import 'package:swipe_stack/src/game/swipe_stack_controller.dart';
import 'package:swipe_stack/src/game/swipe_stack_models.dart';
import 'package:swipe_stack/src/game/swipe_stack_painter.dart';
import 'package:swipe_stack/src/game/swipe_stack_screen.dart';
import 'package:swipe_stack/src/meta/tower_progress_store.dart';
import 'package:swipe_stack/src/persistence/best_stack_store.dart';

class _SeenStore extends HowToPlayStore {
  const _SeenStore();
  @override
  Future<bool> loadSeen() async => true;
  @override
  Future<void> markSeen() async {}
}

class _PendingTutorial extends _SeenStore {
  final result = Completer<bool>();
  @override
  Future<bool> loadSeen() => result.future;
}

class _BestStore extends BestStackStore {
  @override
  Future<int> loadBestStack() async => 0;
  @override
  Future<void> saveBestStack(int value) async {}
}

class _PendingBest extends _BestStore {
  final result = Completer<int>();
  @override
  Future<int> loadBestStack() => result.future;
}

const _box = BoxSegment(
  centerX: 0.5,
  widthFactor: 0.74,
  color: Color(0xFF45647A),
);

final _stage = find.byWidgetPredicate(
  (w) => w is CustomPaint && w.painter is SwipeStackPainter,
);

void _resume(WidgetTester tester) {
  if (tester.binding.lifecycleState == AppLifecycleState.paused) {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
  }
  if (tester.binding.lifecycleState == AppLifecycleState.hidden) {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
  }
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
}

Future<SwipeStackController> _pump(
  WidgetTester tester, {
  HowToPlayStore tutorial = const _SeenStore(),
  BestStackStore? best,
}) async {
  _resume(tester);
  addTearDown(() => _resume(tester));
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  for (final channel in [
    const MethodChannel('swipe_stack/audio'),
    SystemChannels.platform,
  ]) {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (_) async => null,
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      ),
    );
  }
  final controller = SwipeStackController(
    bestStackStore: best ?? _BestStore(),
    random: Random(3),
  );
  controller.debugSetRun(stack: const [_box], movingBox: _box);
  addTearDown(controller.dispose);
  await tester.pumpWidget(
    MaterialApp(
      home: SwipeStackScreen(
        controller: controller,
        howToPlayStore: tutorial,
        progressStore: MemoryTowerProgressStore(),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 16));
  return controller;
}

void main() {
  testWidgets(
    'pending tutorial rejects taps, drags and keys without queued drop',
    (tester) async {
      final tutorial = _PendingTutorial();
      final c = await _pump(tester, tutorial: tutorial);
      final initial = c.movingBox.centerX;
      await tester.tap(_stage);
      await tester.drag(_stage, const Offset(80, 0));
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyR);
      await tester.pump(const Duration(seconds: 4));
      expect(c.isDropping, isFalse);
      expect(c.stackCount, 0);
      expect(c.movingBox.centerX, initial);

      tutorial.result.complete(false);
      await tester.pump();
      expect(find.text('How to play'), findsOneWidget);
      await tester.tap(find.text('Skip'));
      await tester.pump();
      expect(c.isDropping, isFalse);
      await tester.tap(_stage);
      expect(c.isDropping, isTrue);
    },
  );

  testWidgets('pending initialization rejects all play inputs until ready', (
    tester,
  ) async {
    final best = _PendingBest();
    final c = await _pump(tester, best: best);
    final initial = c.movingBox.centerX;
    await tester.tap(_stage);
    await tester.drag(_stage, const Offset(-80, 0));
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyR);
    await tester.pump(const Duration(seconds: 2));
    expect(c.isDropping, isFalse);
    expect(c.movingBox.centerX, initial);

    best.result.complete(12);
    await tester.pump();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    expect(c.isDropping, isTrue);
    expect(c.bestStack, 12);
  });

  testWidgets('inactive and background states freeze motion and reject input', (
    tester,
  ) async {
    final c = await _pump(tester);
    for (final state in [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(state);
      final before = c.movingBox.centerX;
      await tester.tap(_stage);
      await tester.drag(_stage, const Offset(80, 0));
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyR);
      await tester.pump(const Duration(seconds: 10));
      expect(c.isDropping, isFalse, reason: '$state');
      expect(c.movingBox.centerX, before, reason: '$state');
    }
    final before = c.movingBox.centerX;
    _resume(tester);
    await tester.pump(const Duration(seconds: 10));
    expect(c.movingBox.centerX, before);
    await tester.pump(const Duration(milliseconds: 16));
    expect(
      (c.movingBox.centerX - before).abs(),
      closeTo(c.moveSpeed * .016, 1e-9),
    );
  });

  testWidgets('a falling swipe resumes without hidden time or drift catch-up', (
    tester,
  ) async {
    final c = await _pump(tester);
    c.dropWithSwipeVelocity(1000);
    await tester.pump(const Duration(milliseconds: 16));
    final progress = c.dropProgress;
    final center = c.movingBox.centerX;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    await tester.pump(const Duration(seconds: 30));
    expect(c.dropProgress, progress);
    expect(c.movingBox.centerX, center);
    _resume(tester);
    await tester.pump(const Duration(seconds: 30));
    expect(c.dropProgress, progress);
    expect(c.movingBox.centerX, center);
    expect(c.isDropping, isTrue);
    await tester.pump(const Duration(milliseconds: 16));
    expect(c.dropProgress, greaterThan(progress));
    expect(c.isDropping, isTrue);
    expect(c.stackCount, 0);
  });

  testWidgets('an active rendering hitch advances at most one capped frame', (
    tester,
  ) async {
    final c = await _pump(tester);
    c.drop();
    await tester.pump(const Duration(seconds: 5));
    final maxProgress =
        c.dropSpeed / 30 / SwipeStackController.verticalTravelUnits;
    expect(c.dropProgress, closeTo(maxProgress, 1e-9));
    expect(c.isDropping, isTrue);
    expect(c.stackCount, 0);
    await tester.pump(const Duration(milliseconds: 16));
    expect(
      c.dropProgress,
      closeTo(
        maxProgress +
            c.dropSpeed * .016 / SwipeStackController.verticalTravelUnits,
        1e-9,
      ),
    );
  });

  testWidgets('a pointer held across inactivity cannot queue a drop', (
    tester,
  ) async {
    final c = await _pump(tester);
    final point = tester.getCenter(_stage);
    final gesture = await tester.startGesture(point);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    _resume(tester);
    await gesture.up();
    expect(c.isDropping, isFalse);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    final inactiveGesture = await tester.startGesture(point);
    _resume(tester);
    await inactiveGesture.moveBy(const Offset(80, 0));
    await inactiveGesture.up();
    expect(c.isDropping, isFalse);
    await tester.tap(_stage);
    expect(c.isDropping, isTrue);
  });

  testWidgets('closing Help discards overlay time for an in-flight box', (
    tester,
  ) async {
    final c = await _pump(tester);
    c.drop();
    await tester.pump(const Duration(milliseconds: 16));
    final progress = c.dropProgress;
    await tester.tap(find.byTooltip('How to play'));
    await tester.pump(const Duration(seconds: 10));
    expect(c.dropProgress, progress);
    await tester.tap(find.text('Skip'));
    await tester.pump(const Duration(seconds: 10));
    expect(c.dropProgress, progress);
    await tester.pump(const Duration(milliseconds: 16));
    expect(c.dropProgress, greaterThan(progress));
    expect(c.isDropping, isTrue);
  });
}
