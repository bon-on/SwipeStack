import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:swipe_stack/src/game/swipe_stack_controller.dart';
import 'package:swipe_stack/src/game/swipe_stack_models.dart';
import 'package:swipe_stack/src/meta/missions.dart';
import 'package:swipe_stack/src/meta/tower_progress.dart';
import 'package:swipe_stack/src/meta/tower_progress_store.dart';
import 'package:swipe_stack/src/meta/tower_theme.dart';
import 'package:swipe_stack/src/persistence/best_stack_store.dart';

class _SlowBestStore extends BestStackStore {
  _SlowBestStore(this.stored);

  int stored;
  final List<int> saves = <int>[];

  @override
  Future<int> loadBestStack() async => stored;

  @override
  Future<void> saveBestStack(int bestStack) async {
    saves.add(bestStack);
    stored = bestStack;
  }
}

void main() {
  group('TowerProgress', () {
    test('level curve and XP split', () {
      expect(TowerProgress.xpToAdvance(1), 60);
      expect(TowerProgress.xpToAdvance(2), 80);
      expect(TowerProgress.levelFor(0), (1, 0));
      expect(TowerProgress.levelFor(59), (1, 59));
      expect(TowerProgress.levelFor(60), (2, 0));
      expect(TowerProgress.levelFor(140), (3, 0));
      expect(TowerProgress.levelFor(-5), (1, 0));
    });

    test('run XP formula and zero-floor runs', () {
      expect(
        TowerProgress.xpForRun(
          const RunSummary(
            floors: 10,
            perfects: 2,
            bestStreak: 2,
            missionXp: 15,
          ),
        ),
        20 + 6 + 15 + 10,
      );
      expect(
        TowerProgress.xpForRun(
          const RunSummary(floors: 2, perfects: 0, bestStreak: 0),
        ),
        4,
      );
      const progress = TowerProgress.initial();
      final outcome = progress.applyRun(
        const RunSummary(floors: 0, perfects: 0, bestStreak: 0, missionXp: 99),
      );
      expect(outcome.xpGained, 0);
      expect(identical(outcome.progress, progress), isTrue);
    });

    test('applyRun levels up and reports unlocked themes', () {
      const progress = TowerProgress.initial();
      final outcome = progress.applyRun(
        const RunSummary(
          floors: 40,
          perfects: 10,
          bestStreak: 5,
          missionXp: 30,
        ),
      );
      // 80 + 30 + 30 + 10 = 150 XP -> level 3.
      expect(outcome.xpGained, 150);
      expect(outcome.levelBefore, 1);
      expect(outcome.levelAfter, 3);
      expect(outcome.leveledUp, isTrue);
      expect(outcome.newlyUnlockedThemes, <TowerTheme>[TowerTheme.harbor]);
      expect(outcome.progress.runs, 1);
      expect(outcome.progress.bestStreak, 5);
      expect(outcome.progress.totalFloors, 40);
    });

    test('locked themes cannot be selected', () {
      const progress = TowerProgress.initial();
      expect(
        progress.withTheme(TowerTheme.neon).selectedTheme,
        TowerTheme.downtown,
      );
      final rich = TowerProgress.fromJson(<String, Object>{'totalXp': 100000});
      expect(rich.level, greaterThanOrEqualTo(10));
      expect(rich.withTheme(TowerTheme.neon).selectedTheme, TowerTheme.neon);
    });

    test('fromJson tolerates corrupt values', () {
      expect(TowerProgress.fromJson('nope').totalXp, 0);
      expect(TowerProgress.fromJson(null).selectedTheme, TowerTheme.downtown);
      final parsed = TowerProgress.fromJson(<String, Object?>{
        'totalXp': -4,
        'selectedTheme': 'neon',
        'runs': double.nan,
        'totalFloors': 'x',
        'bestStreak': 3,
      });
      expect(parsed.totalXp, 0);
      // Neon is locked at level 1, so it falls back.
      expect(parsed.selectedTheme, TowerTheme.downtown);
      expect(parsed.runs, 0);
      expect(parsed.bestStreak, 3);
      final round = TowerProgress.fromJson(
        const TowerProgress(
          totalXp: 200,
          selectedTheme: TowerTheme.harbor,
          totalFloors: 50,
          totalPerfects: 9,
          runs: 4,
          bestStreak: 4,
        ).toJson(),
      );
      expect(round.selectedTheme, TowerTheme.harbor);
      expect(round.totalFloors, 50);
    });
  });

  group('TowerProgressStore', () {
    test('missing and corrupt values load defaults', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      const store = TowerProgressStore();
      expect((await store.load()).totalXp, 0);
      SharedPreferences.setMockInitialValues(<String, Object>{
        TowerProgressStore.progressKey: '{not json',
      });
      expect((await store.load()).totalXp, 0);
      SharedPreferences.setMockInitialValues(<String, Object>{
        TowerProgressStore.progressKey: '[1,2]',
      });
      expect((await store.load()).totalXp, 0);
    });

    test('saves under tower_progress_v1 and keeps best_stack', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'best_stack': 17,
      });
      const store = TowerProgressStore();
      await store.save(
        const TowerProgress.initial()
            .applyRun(const RunSummary(floors: 5, perfects: 1, bestStreak: 1))
            .progress,
      );
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('tower_progress_v1'), contains('totalXp'));
      expect(prefs.getInt('best_stack'), 17);
      expect(await BestStackStore().loadBestStack(), 17);
      expect((await store.load()).runs, 1);
    });
  });

  group('MissionBoard', () {
    test('builder levels 1 and 2 get the same achievable starter goals', () {
      for (final level in <int>[1, 2]) {
        for (var seed = 0; seed < 10; seed++) {
          final board = MissionBoard(random: math.Random(seed), level: level);
          expect(board.missions.map((m) => m.kind), <MissionKind>[
            MissionKind.buildFloors,
            MissionKind.perfectDrops,
            MissionKind.wideFloors,
          ]);
          expect(board.missions.map((m) => m.target), <int>[3, 1, 3]);
          expect(board.missions.map((m) => m.xp), <int>[15, 20, 20]);
          expect(board.missions[1].label, 'Land 1 perfect drop');
        }
      }
    });

    test('starter achievements pay once and reset enters the regular pool', () {
      final board = MissionBoard(random: math.Random(7), level: 2);
      final first = board.update(
        const MissionStats(
          floors: 1,
          perfects: 1,
          bestStreak: 1,
          topWidth: 0.74,
        ),
      );
      expect(first.single.kind, MissionKind.perfectDrops);
      expect(board.earnedXp, 20);
      final third = board.update(
        const MissionStats(
          floors: 3,
          perfects: 1,
          bestStreak: 1,
          topWidth: MissionBoard.halfWidth,
        ),
      );
      expect(third.map((m) => m.kind), <MissionKind>[
        MissionKind.buildFloors,
        MissionKind.wideFloors,
      ]);
      expect(board.earnedXp, 55);
      expect(board.completedCount, 3);
      expect(
        board.update(
          const MissionStats(
            floors: 8,
            perfects: 3,
            bestStreak: 2,
            topWidth: 0.1,
          ),
        ),
        isEmpty,
      );
      expect(board.earnedXp, 55);

      board.reset(level: 3);
      expect(board.completedCount, 0);
      expect(board.earnedXp, 0);
      // Beginner generation consumes no RNG; the first regular roll is
      // identical to a fresh level-3 board with the same source.
      final regular = MissionBoard(random: math.Random(7), level: 3);
      expect(
        board.missions.map((m) => m.label),
        regular.missions.map((m) => m.label),
      );
      for (final m in board.missions) {
        switch (m.kind) {
          case MissionKind.buildFloors:
            expect(m.target, inInclusiveRange(8, 10));
          case MissionKind.perfectDrops:
          case MissionKind.perfectStreak:
            expect(m.target, 2);
          case MissionKind.wideFloors:
            expect(m.target, 6);
        }
      }
    });

    test('explicit injected missions override beginner defaults', () {
      const custom = Mission(
        kind: MissionKind.perfectStreak,
        target: 7,
        xp: 42,
      );
      final board = MissionBoard(level: 1, missions: const [custom]);
      expect(board.missions.single, same(custom));
      expect(
        board.update(
          const MissionStats(
            floors: 3,
            perfects: 1,
            bestStreak: 1,
            topWidth: 0.74,
          ),
        ),
        isEmpty,
      );
    });

    test('rolls three distinct kinds with level-scaled targets', () {
      for (var seed = 0; seed < 20; seed++) {
        final board = MissionBoard(random: math.Random(seed), level: 3);
        final kinds = board.missions.map((m) => m.kind).toSet();
        expect(kinds, hasLength(3));
        for (final m in board.missions) {
          expect(m.target, greaterThan(0));
          expect(m.xp, greaterThan(0));
          expect(m.label, isNotEmpty);
        }
      }
      final low = MissionBoard(
        random: math.Random(1),
        missions: null,
        level: 3,
      ).missions;
      final high = MissionBoard(random: math.Random(1), level: 12).missions;
      expect(high.first.target, greaterThanOrEqualTo(low.first.target));
    });

    test('progress completes once and never drops', () {
      final board = MissionBoard(
        missions: const <Mission>[
          Mission(kind: MissionKind.buildFloors, target: 3, xp: 10),
          Mission(kind: MissionKind.perfectStreak, target: 2, xp: 20),
          Mission(kind: MissionKind.wideFloors, target: 2, xp: 30),
        ],
      );
      var done = board.update(
        const MissionStats(
          floors: 2,
          perfects: 2,
          bestStreak: 2,
          topWidth: 0.5,
        ),
      );
      expect(done.map((m) => m.kind), <MissionKind>[
        MissionKind.perfectStreak,
        MissionKind.wideFloors,
      ]);
      expect(board.earnedXp, 50);
      // Narrow tower: wide mission keeps its finished state.
      done = board.update(
        const MissionStats(
          floors: 3,
          perfects: 2,
          bestStreak: 2,
          topWidth: 0.1,
        ),
      );
      expect(done.single.kind, MissionKind.buildFloors);
      expect(board.completedCount, 3);
      expect(board.earnedXp, 60);
      expect(
        board.update(
          const MissionStats(
            floors: 4,
            perfects: 2,
            bestStreak: 2,
            topWidth: 0.1,
          ),
        ),
        isEmpty,
      );
    });

    test('wide floors only counts while the top is wide', () {
      final board = MissionBoard(
        missions: const <Mission>[
          Mission(kind: MissionKind.wideFloors, target: 5, xp: 10),
        ],
      );
      board.update(
        const MissionStats(
          floors: 3,
          perfects: 0,
          bestStreak: 0,
          topWidth: 0.4,
        ),
      );
      board.update(
        const MissionStats(
          floors: 4,
          perfects: 0,
          bestStreak: 0,
          topWidth: 0.2,
        ),
      );
      expect(board.missions.single.progress, 3);
      board.reset(level: 1);
      expect(board.missions, hasLength(3));
      expect(board.completedCount, 0);
    });
  });

  group('controller run stats', () {
    const base = BoxSegment(
      centerX: 0.5,
      widthFactor: 0.74,
      color: Color(0xFF45647A),
    );

    test('landing reports cut chips and perfect drops', () {
      final controller = SwipeStackController(
        bestStackStore: _SlowBestStore(0),
        random: math.Random(2),
      );
      controller.debugSetRun(
        stack: const <BoxSegment>[base],
        movingBox: const BoxSegment(
          centerX: 0.6,
          widthFactor: 0.74,
          color: Color(0xFFFFB14C),
        ),
      );
      controller.drop();
      controller.update(1);
      final landing = controller.lastLanding!;
      expect(landing.perfect, isFalse);
      expect(landing.floor, 1);
      expect(landing.chips, hasLength(1));
      expect(landing.chips.single.left, closeTo(0.87, 1e-6));
      expect(landing.chips.single.widthFactor, closeTo(0.1, 1e-6));

      controller.debugSetRun(stack: const <BoxSegment>[base], movingBox: base);
      controller.drop();
      controller.update(1);
      expect(controller.lastLanding!.perfect, isTrue);
      expect(controller.lastLanding!.chips, isEmpty);
      expect(controller.runPerfectCount, 1);
      expect(controller.runBestStreak, 1);
      final serial = controller.lastLanding!.serial;
      controller.restart();
      expect(controller.lastLanding, isNull);
      expect(controller.runPerfectCount, 0);
      expect(serial, greaterThan(1));
    });

    test('best is not saved before the stored value loads', () async {
      final store = _SlowBestStore(9);
      final controller = SwipeStackController(
        bestStackStore: store,
        random: math.Random(2),
      );
      // Land before initialize: no write may clobber the stored 9.
      controller.drop();
      controller.update(0.05);
      controller.setPlayfieldSize(const Size(300, 600));
      controller.update(2);
      expect(controller.stackCount, 1, reason: 'seed must land a floor');
      expect(controller.bestStack, 1);
      expect(store.saves, isEmpty);
      await controller.initialize();
      expect(controller.bestStack, 9);
      expect(controller.runStartBest, 9);
      expect(store.saves, isEmpty);
    });
  });
}
