import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swipe_stack/src/game/how_to_play.dart';
import 'package:swipe_stack/src/game/swipe_stack_controller.dart';
import 'package:swipe_stack/src/game/swipe_stack_models.dart';
import 'package:swipe_stack/src/game/swipe_stack_screen.dart';
import 'package:swipe_stack/src/persistence/best_stack_store.dart';

class _FakeStore extends HowToPlayStore {
  _FakeStore({this.seen = false});

  bool seen;

  @override
  Future<bool> loadSeen() async => seen;

  @override
  Future<void> markSeen() async => seen = true;
}

class _ThrowingStore extends HowToPlayStore {
  const _ThrowingStore();

  @override
  Future<bool> loadSeen() async => false;

  @override
  Future<void> markSeen() async => throw StateError('disk full');
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

Future<SwipeStackController> _pump(
  WidgetTester tester,
  HowToPlayStore store, {
  Size size = const Size(390, 844),
}) async {
  final controller = SwipeStackController(
    bestStackStore: _MemoryStore(),
    random: math.Random(1),
  );
  controller.debugSetRun(
    stack: const <BoxSegment>[_base],
    movingBox: const BoxSegment(
      centerX: 0.5,
      widthFactor: 0.74,
      color: Color(0xFFFFB14C),
    ),
  );
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  addTearDown(controller.dispose);
  await tester.pumpWidget(
    MaterialApp(
      home: SwipeStackScreen(controller: controller, howToPlayStore: store),
    ),
  );
  await tester.pump();
  return controller;
}

final _nextBtn = find.widgetWithText(FilledButton, 'Next');
final _playBtn = find.widgetWithText(FilledButton, 'Play');
final _title = find.text('How to play');
final _text = find.byKey(const ValueKey('how-to-play-text'));

void main() {
  testWidgets('first launch shows the overlay and blocks game input', (
    tester,
  ) async {
    final controller = await _pump(tester, _FakeStore());
    expect(_title, findsOneWidget);

    await tester.tapAt(const Offset(195, 400));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyR);
    await tester.pump();
    expect(controller.isDropping, isFalse);
    expect(controller.movingBox.centerX, 0.5);
    expect(_title, findsOneWidget);
  });

  testWidgets('Next walks the steps; Play closes and stores the flag', (
    tester,
  ) async {
    final store = _FakeStore();
    await _pump(tester, store);
    for (var i = 0; i < 2; i++) {
      await tester.tap(_nextBtn);
      await tester.pump();
    }
    expect(_nextBtn, findsNothing);
    expect(_playBtn, findsOneWidget);
    await tester.tap(_playBtn);
    await tester.pump();
    expect(_title, findsNothing);
    expect(store.seen, isTrue);
  });

  testWidgets('Skip closes and stores the flag', (tester) async {
    final store = _FakeStore();
    await _pump(tester, store);
    await tester.tap(find.text('Skip'));
    await tester.pump();
    expect(_title, findsNothing);
    expect(store.seen, isTrue);
  });

  testWidgets('Escape skips; Enter/Space and arrows navigate', (tester) async {
    final store = _FakeStore();
    final controller = await _pump(tester, store);
    final first = tester.widget<Text>(_text).data;
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    final second = tester.widget<Text>(_text).data;
    expect(second, isNot(first));
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    expect(tester.widget<Text>(_text).data, first);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(tester.widget<Text>(_text).data, second);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(_playBtn, findsOneWidget);
    expect(controller.isDropping, isFalse);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(_title, findsNothing);
    expect(store.seen, isTrue);
  });

  testWidgets('does not appear when the flag is already set', (tester) async {
    await _pump(tester, _FakeStore(seen: true));
    expect(_title, findsNothing);
  });

  testWidgets('? reopens at step 1 without resetting the run', (tester) async {
    final controller = await _pump(tester, _FakeStore(seen: true));
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    final centerX = controller.movingBox.centerX;
    expect(centerX, isNot(0.5));

    await tester.tap(find.byTooltip('How to play'));
    await tester.pump();
    expect(_title, findsOneWidget);
    expect(tester.widget<Text>(_text).data, startsWith('Stack boxes'));
    expect(controller.movingBox.centerX, centerX);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(_title, findsNothing);
    // Game keys work again after closing.
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(controller.isDropping, isTrue);
  });

  testWidgets('simulation does not advance while the overlay is open', (
    tester,
  ) async {
    final controller = await _pump(tester, _FakeStore());
    // Let the screen bootstrap and start its ticker.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(_title, findsOneWidget);
    final before = controller.movingBox.centerX;
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(controller.movingBox.centerX, before);

    await tester.tap(find.text('Skip'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 200));
    expect(controller.movingBox.centerX, isNot(before));
  });

  testWidgets('storage failures do not break play', (tester) async {
    await _pump(tester, const _ThrowingStore());
    expect(_title, findsOneWidget);
    await tester.tap(find.text('Skip'));
    await tester.pump();
    expect(_title, findsNothing);
  });

  for (final size in const [Size(390, 844), Size(844, 390), Size(1280, 720)]) {
    testWidgets('overlay fits without overflow at $size', (tester) async {
      await _pump(tester, _FakeStore(), size: size);
      expect(_title, findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
