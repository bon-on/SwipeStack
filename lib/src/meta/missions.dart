import 'dart:math';

/// Kinds of in-run goals.
enum MissionKind { buildFloors, perfectDrops, perfectStreak, wideFloors }

/// Run facts a mission is measured against.
class MissionStats {
  const MissionStats({
    required this.floors,
    required this.perfects,
    required this.bestStreak,
    required this.topWidth,
  });

  final int floors;
  final int perfects;
  final int bestStreak;

  /// Width factor of the top floor (0..1 of the playfield).
  final double topWidth;
}

/// One in-run goal. Snapshots are immutable; [MissionBoard] replaces them.
class Mission {
  const Mission({
    required this.kind,
    required this.target,
    required this.xp,
    this.progress = 0,
  });

  final MissionKind kind;
  final int target;

  /// XP granted when completed.
  final int xp;

  /// Always within 0..[target].
  final int progress;

  bool get completed => progress >= target;

  String get label {
    switch (kind) {
      case MissionKind.buildFloors:
        return 'Build $target floors';
      case MissionKind.perfectDrops:
        return 'Land $target perfect drops';
      case MissionKind.perfectStreak:
        return 'Perfect x$target in a row';
      case MissionKind.wideFloors:
        return 'Reach $target floors at half width';
    }
  }

  Mission withProgress(int value) => Mission(
    kind: kind,
    target: target,
    xp: xp,
    progress: value.clamp(0, target),
  );
}

/// Three missions of different kinds per run. Targets grow a little with
/// the player level. Progress never goes back down within a run.
class MissionBoard {
  MissionBoard({Random? random, int level = 1, List<Mission>? missions})
    : _random = random ?? Random(),
      _level = level {
    _missions = missions ?? _roll();
  }

  /// A top floor at least this wide counts as "half width" (half of the
  /// 0.74 starting width).
  static const double halfWidth = 0.37;

  final Random _random;
  int _level;
  late List<Mission> _missions;

  List<Mission> get missions => List<Mission>.unmodifiable(_missions);

  int get completedCount => _missions.where((m) => m.completed).length;

  int get earnedXp =>
      _missions.where((m) => m.completed).fold<int>(0, (sum, m) => sum + m.xp);

  /// Starts a fresh set for a new run.
  void reset({int? level}) {
    if (level != null) _level = level;
    _missions = _roll();
  }

  /// Updates progress; returns missions completed by this update.
  List<Mission> update(MissionStats stats) {
    final completed = <Mission>[];
    final next = <Mission>[];
    for (final mission in _missions) {
      if (mission.completed) {
        next.add(mission);
        continue;
      }
      final value = switch (mission.kind) {
        MissionKind.buildFloors => stats.floors,
        MissionKind.perfectDrops => stats.perfects,
        MissionKind.perfectStreak => stats.bestStreak,
        MissionKind.wideFloors =>
          stats.topWidth >= halfWidth - 1e-9 ? stats.floors : 0,
      };
      final updated = mission.withProgress(max(mission.progress, value));
      if (updated.completed) completed.add(updated);
      next.add(updated);
    }
    _missions = next;
    return completed;
  }

  List<Mission> _roll() {
    final tier = min(3, (_level - 1) ~/ 3);
    final kinds = List<MissionKind>.of(MissionKind.values)..shuffle(_random);
    final picked = kinds.take(3).toList()
      ..sort((a, b) => a.index.compareTo(b.index));
    return <Mission>[for (final kind in picked) _make(kind, tier)];
  }

  Mission _make(MissionKind kind, int tier) {
    switch (kind) {
      case MissionKind.buildFloors:
        return Mission(
          kind: kind,
          target: const <int>[8, 12, 16, 20][tier] + _random.nextInt(3),
          xp: 15 + 5 * tier,
        );
      case MissionKind.perfectDrops:
        return Mission(
          kind: kind,
          target: const <int>[2, 3, 4, 5][tier],
          xp: 20 + 5 * tier,
        );
      case MissionKind.perfectStreak:
        return Mission(
          kind: kind,
          target: const <int>[2, 2, 3, 3][tier],
          xp: 25 + 5 * tier,
        );
      case MissionKind.wideFloors:
        return Mission(
          kind: kind,
          target: const <int>[6, 8, 10, 12][tier],
          xp: 20 + 5 * tier,
        );
    }
  }
}
