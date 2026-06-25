import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:swipe_stack/src/game/swipe_stack_controller.dart';
import 'package:swipe_stack/src/game/swipe_stack_models.dart';
import 'package:swipe_stack/src/persistence/best_stack_store.dart';

class _InMemoryBestStackStore extends BestStackStore {
  int value;

  _InMemoryBestStackStore([this.value = 0]);

  @override
  Future<int> loadBestStack() async => value;

  @override
  Future<void> saveBestStack(int bestStack) async {
    value = bestStack;
  }
}

void main() {
  group('SwipeStackController', () {
    test('loads persisted best stack on initialize', () async {
      final store = _InMemoryBestStackStore(7);
      final controller = SwipeStackController(
        bestStackStore: store,
        random: math.Random(1),
      );

      await controller.initialize();

      expect(controller.bestStack, 7);
      expect(controller.isInitialized, isTrue);
    });

    test('speed tier increases every five stacked boxes', () {
      final controller = SwipeStackController(
        bestStackStore: _InMemoryBestStackStore(),
        random: math.Random(2),
      );

      controller.debugSetRun(
        stack: const <BoxSegment>[
          BoxSegment(centerX: 0.5, widthFactor: 0.74, color: Color(0xFF45647A)),
        ],
        movingBox: const BoxSegment(
          centerX: 0.5,
          widthFactor: 0.74,
          color: Color(0xFFFFB14C),
        ),
        stackCount: 10,
      );

      expect(controller.speedTier, 2);
    });

    test('successful drop keeps only overlap and updates best stack', () {
      final store = _InMemoryBestStackStore();
      final controller = SwipeStackController(
        bestStackStore: store,
        random: math.Random(3),
      );

      controller.debugSetRun(
        stack: const <BoxSegment>[
          BoxSegment(centerX: 0.5, widthFactor: 0.74, color: Color(0xFF45647A)),
        ],
        movingBox: const BoxSegment(
          centerX: 0.58,
          widthFactor: 0.74,
          color: Color(0xFFFFB14C),
        ),
      );

      controller.drop();
      controller.update(1.0);

      expect(controller.isGameOver, isFalse);
      expect(controller.stackCount, 1);
      expect(controller.stackedBoxes.length, 2);
      expect(controller.stackedBoxes.last.widthFactor, closeTo(0.66, 0.001));
      expect(controller.bestStack, 1);
      expect(store.value, 1);
    });

    test('horizontal drag nudges moving box inside the playfield', () {
      final controller = SwipeStackController(
        bestStackStore: _InMemoryBestStackStore(),
        random: math.Random(8),
      )..setPlayfieldSize(const Size(300, 600));

      controller.debugSetRun(
        stack: const <BoxSegment>[
          BoxSegment(centerX: 0.5, widthFactor: 0.74, color: Color(0xFF45647A)),
        ],
        movingBox: const BoxSegment(
          centerX: 0.5,
          widthFactor: 0.74,
          color: Color(0xFFFFB14C),
        ),
      );

      controller.nudgeMovingBox(90);

      expect(controller.movingBox.centerX, greaterThan(0.5));

      controller.nudgeMovingBox(900);

      expect(controller.movingBox.right, lessThanOrEqualTo(1));
    });

    test('swipe release drops with bounded drift carry', () {
      final controller = SwipeStackController(
        bestStackStore: _InMemoryBestStackStore(),
        random: math.Random(9),
      )..setPlayfieldSize(const Size(300, 600));

      controller.debugSetRun(
        stack: const <BoxSegment>[
          BoxSegment(centerX: 0.5, widthFactor: 0.74, color: Color(0xFF45647A)),
        ],
        movingBox: const BoxSegment(
          centerX: 0.5,
          widthFactor: 0.74,
          color: Color(0xFFFFB14C),
        ),
      );

      controller.dropWithSwipeVelocity(1200);
      controller.update(0.1);

      expect(controller.isDropping, isTrue);
      expect(controller.movingBox.centerX, greaterThan(0.5));
    });

    test('drop fails when overlap ratio is under threshold', () {
      final controller = SwipeStackController(
        bestStackStore: _InMemoryBestStackStore(),
        random: math.Random(4),
      );

      controller.debugSetRun(
        stack: const <BoxSegment>[
          BoxSegment(centerX: 0.5, widthFactor: 0.74, color: Color(0xFF45647A)),
        ],
        movingBox: const BoxSegment(
          centerX: 0.88,
          widthFactor: 0.74,
          color: Color(0xFFFFB14C),
        ),
      );

      controller.drop();
      controller.update(1.0);

      expect(controller.isGameOver, isTrue);
      expect(controller.stackCount, 0);
      expect(controller.stackedBoxes.length, 1);
    });

    test('restart resets stack state but keeps best stack', () {
      final controller = SwipeStackController(
        bestStackStore: _InMemoryBestStackStore(3),
        random: math.Random(5),
      );

      controller.debugSetRun(
        stack: const <BoxSegment>[
          BoxSegment(centerX: 0.5, widthFactor: 0.74, color: Color(0xFF45647A)),
          BoxSegment(
            centerX: 0.55,
            widthFactor: 0.62,
            color: Color(0xFFFF8C69),
          ),
        ],
        movingBox: const BoxSegment(
          centerX: 0.55,
          widthFactor: 0.62,
          color: Color(0xFFE86A92),
        ),
        stackCount: 1,
        bestStack: 3,
        isGameOver: true,
      );

      controller.restart();

      expect(controller.isGameOver, isFalse);
      expect(controller.stackCount, 0);
      expect(controller.bestStack, 3);
      expect(controller.stackedBoxes.length, 1);
      expect(controller.movingBox.widthFactor, closeTo(0.74, 0.001));
    });

    test('new moving box respawns away from the previous stack center', () {
      final controller = SwipeStackController(
        bestStackStore: _InMemoryBestStackStore(),
        random: math.Random(7),
      );

      controller.debugSetRun(
        stack: const <BoxSegment>[
          BoxSegment(centerX: 0.5, widthFactor: 0.74, color: Color(0xFF45647A)),
        ],
        movingBox: const BoxSegment(
          centerX: 0.58,
          widthFactor: 0.74,
          color: Color(0xFFFFB14C),
        ),
      );

      controller.drop();
      controller.update(1.0);

      expect((controller.movingBox.centerX - 0.58).abs(), greaterThan(0.05));
    });
  });
}
