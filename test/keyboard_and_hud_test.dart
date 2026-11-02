import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swipe_stack/src/game/how_to_play.dart';
import 'package:swipe_stack/src/game/swipe_stack_controller.dart';
import 'package:swipe_stack/src/game/swipe_stack_models.dart';
import 'package:swipe_stack/src/game/swipe_stack_painter.dart';
import 'package:swipe_stack/src/game/swipe_stack_screen.dart';
import 'package:swipe_stack/src/persistence/best_stack_store.dart';

class _SeenStore extends HowToPlayStore {
  const _SeenStore();
  @override
  Future<bool> loadSeen() async => true;
  @override
  Future<void> markSeen() async {}
}

class _MemoryStore extends BestStackStore {
  @override
  Future<int> loadBestStack() async => 0;

  @override
  Future<void> saveBestStack(int bestStack) async {}
}

const _base = BoxSegment(
  centerX: 0.5,
  widthFactor: 0.74,
  color: Color(0xFF45647A),
);

SwipeStackController _controller({double movingCenterX = 0.5}) {
  final controller = SwipeStackController(
    bestStackStore: _MemoryStore(),
    random: math.Random(1),
  );
  controller.debugSetRun(
    stack: const <BoxSegment>[_base],
    movingBox: BoxSegment(
      centerX: movingCenterX,
      widthFactor: 0.74,
      color: const Color(0xFFFFB14C),
    ),
  );
  return controller;
}

Future<void> _pump(
  WidgetTester tester,
  SwipeStackController controller, {
  Size size = const Size(390, 844),
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
      ),
    ),
  );
  await tester.pump();
}

bool _isStagePaint(Widget widget) =>
    widget is CustomPaint && widget.painter is SwipeStackPainter;

void main() {
  testWidgets('HUD shows Perfect x1 after a perfect drop', (tester) async {
    final controller = _controller();
    await _pump(tester, controller);
    expect(find.text('Perfect x1'), findsNothing);

    controller.drop();
    controller.update(2);
    await tester.pump();

    expect(controller.lastDropPerfect, isTrue);
    expect(find.text('Perfect x1'), findsOneWidget);
  });

  for (final key in [
    LogicalKeyboardKey.space,
    LogicalKeyboardKey.enter,
    LogicalKeyboardKey.arrowDown,
  ]) {
    testWidgets('${key.keyLabel} drops the box', (tester) async {
      final controller = _controller();
      await _pump(tester, controller);
      expect(controller.isDropping, isFalse);

      await tester.sendKeyEvent(key);
      await tester.pump();
      expect(controller.isDropping, isTrue);
    });
  }

  testWidgets('Left/Right nudge within the cap', (tester) async {
    final controller = _controller();
    await _pump(tester, controller);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(
      controller.movingBox.centerX,
      closeTo(0.5 + SwipeStackController.keyboardNudgeStep, 1e-9),
    );

    for (var i = 0; i < 10; i += 1) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    }
    await tester.pump();
    expect(
      controller.movingBox.centerX,
      closeTo(0.5 - SwipeStackController.maxNudgePerBox, 1e-9),
    );
  });

  testWidgets('keys restart after game over', (tester) async {
    final controller = _controller();
    controller.debugSetRun(
      stack: const <BoxSegment>[_base],
      movingBox: _base,
      stackCount: 4,
      isGameOver: true,
    );
    await _pump(tester, controller);
    expect(find.text('Tower slipped'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.keyR);
    await tester.pump();
    expect(controller.isGameOver, isFalse);
    expect(controller.stackCount, 0);
  });

  testWidgets('HUD shows MAX speed once the tier cap is reached', (
    tester,
  ) async {
    final controller = _controller();
    controller.debugSetRun(
      stack: const <BoxSegment>[_base],
      movingBox: _base,
      stackCount: SwipeStackController.maxSpeedTier * 5,
    );
    await _pump(tester, controller);
    expect(find.text('MAX'), findsOneWidget);
  });

  testWidgets('wide viewports cap the play field and add side panels', (
    tester,
  ) async {
    await _pump(tester, _controller(), size: const Size(1280, 720));
    expect(find.byWidgetPredicate(_isStagePaint), findsOneWidget);
    final field = tester.getRect(find.byWidgetPredicate(_isStagePaint));
    expect(field.width, lessThanOrEqualTo(SwipeStackScreen.maxContentWidth));
    expect(field.center.dx, closeTo(640, 1));
    // Side panels: title on the left, missions on the right.
    expect(tester.getRect(find.text('SwipeStack')).right, lessThan(field.left));
    expect(tester.getRect(find.text('MISSIONS')).left, greaterThan(field.right));
    expect(tester.takeException(), isNull);
  });

  testWidgets('phone portrait stacks the HUD and keeps a wide play field', (
    tester,
  ) async {
    await _pump(tester, _controller());
    final field = tester.getRect(find.byWidgetPredicate(_isStagePaint));
    expect(field.width, greaterThan(350));
    expect(tester.getRect(find.text('SwipeStack')).bottom, lessThan(field.top));
    expect(find.text('MISSIONS'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('held-key repeat does not restart or drop', (tester) async {
    final controller = _controller();
    controller.debugSetRun(
      stack: const <BoxSegment>[_base],
      movingBox: _base,
      isGameOver: true,
    );
    await _pump(tester, controller);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.space);
    await tester.sendKeyRepeatEvent(LogicalKeyboardKey.space);
    // The initial key down restarts; repeats must not drop the fresh box.
    await tester.pump();
    expect(controller.isGameOver, isFalse);
    expect(controller.isDropping, isFalse);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.space);
  });

  testWidgets('Ctrl+R does not restart', (tester) async {
    final controller = _controller();
    controller.debugSetRun(
      stack: const <BoxSegment>[_base],
      movingBox: _base,
      stackCount: 3,
    );
    await _pump(tester, controller);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyR);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();
    expect(controller.stackCount, 3);
  });
}
