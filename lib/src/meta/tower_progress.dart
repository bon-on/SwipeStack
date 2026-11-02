import 'tower_theme.dart';

/// Facts about one finished (or restarted) run, fed to
/// [TowerProgress.applyRun].
class RunSummary {
  const RunSummary({
    required this.floors,
    required this.perfects,
    required this.bestStreak,
    this.missionXp = 0,
  });

  /// Floors stacked in the run (the controller's stack count).
  final int floors;
  final int perfects;
  final int bestStreak;

  /// XP already earned from missions completed during the run.
  final int missionXp;
}

/// Result of applying a run to the saved progress.
class RunOutcome {
  const RunOutcome({
    required this.progress,
    required this.xpGained,
    required this.levelBefore,
    required this.levelAfter,
    required this.newlyUnlockedThemes,
  });

  final TowerProgress progress;
  final int xpGained;
  final int levelBefore;
  final int levelAfter;
  final List<TowerTheme> newlyUnlockedThemes;

  bool get leveledUp => levelAfter > levelBefore;
}

/// Saved meta progress: player XP, chosen theme and lifetime stats.
///
/// The best height is NOT stored here: it stays under the original
/// `best_stack` key (BestStackStore) so existing records are kept.
///
/// XP per run = floors x [xpPerFloor] + perfect drops x [xpPerPerfect]
/// + mission XP + [participationXp] (runs of at least
/// [participationMinFloors] floors). A casual 10 to 15 floor run with a few
/// perfect drops and one mission earns about 60 to 80 XP. Reaching level L+1
/// costs 60 + 20 x (L - 1) XP, so themes open after roughly 2 (Lv3), 7 (Lv6)
/// and 18 (Lv10) such runs.
class TowerProgress {
  const TowerProgress({
    required this.totalXp,
    required this.selectedTheme,
    required this.totalFloors,
    required this.totalPerfects,
    required this.runs,
    required this.bestStreak,
  });

  const TowerProgress.initial()
    : totalXp = 0,
      selectedTheme = TowerTheme.downtown,
      totalFloors = 0,
      totalPerfects = 0,
      runs = 0,
      bestStreak = 0;

  static const int xpPerFloor = 2;
  static const int xpPerPerfect = 3;
  static const int participationXp = 10;
  static const int participationMinFloors = 3;

  final int totalXp;
  final TowerTheme selectedTheme;
  final int totalFloors;
  final int totalPerfects;
  final int runs;
  final int bestStreak;

  /// XP needed to go from [level] to the next one.
  static int xpToAdvance(int level) => 60 + 20 * (level < 1 ? 0 : level - 1);

  /// XP a run earns before mission rewards are added.
  static int xpForRun(RunSummary run) {
    if (run.floors <= 0) return 0;
    return run.floors * xpPerFloor +
        (run.perfects < 0 ? 0 : run.perfects) * xpPerPerfect +
        (run.missionXp < 0 ? 0 : run.missionXp) +
        (run.floors >= participationMinFloors ? participationXp : 0);
  }

  /// (level, XP into that level) for an XP total.
  static (int, int) levelFor(int xp) {
    var level = 1;
    var left = xp < 0 ? 0 : xp;
    while (left >= xpToAdvance(level)) {
      left -= xpToAdvance(level);
      level += 1;
    }
    return (level, left);
  }

  int get level => levelFor(totalXp).$1;
  int get xpIntoLevel => levelFor(totalXp).$2;
  int get xpForNextLevel => xpToAdvance(level);

  bool isThemeUnlocked(TowerTheme theme) => level >= theme.requiredLevel;

  /// Returns this progress unchanged when [theme] is still locked.
  TowerProgress withTheme(TowerTheme theme) {
    if (!isThemeUnlocked(theme)) return this;
    return _copy(selectedTheme: theme);
  }

  /// Adds [xp] and lifetime stats from another progress delta (used to merge
  /// runs that finished before the stored value had loaded).
  TowerProgress mergedWith(TowerProgress delta, {TowerTheme? theme}) {
    final merged = TowerProgress(
      totalXp: totalXp + delta.totalXp,
      selectedTheme: selectedTheme,
      totalFloors: totalFloors + delta.totalFloors,
      totalPerfects: totalPerfects + delta.totalPerfects,
      runs: runs + delta.runs,
      bestStreak: bestStreak > delta.bestStreak ? bestStreak : delta.bestStreak,
    );
    return theme == null ? merged : merged.withTheme(theme);
  }

  RunOutcome applyRun(RunSummary run) {
    final levelBefore = level;
    if (run.floors <= 0) {
      return RunOutcome(
        progress: this,
        xpGained: 0,
        levelBefore: levelBefore,
        levelAfter: levelBefore,
        newlyUnlockedThemes: const <TowerTheme>[],
      );
    }
    final xp = xpForRun(run);
    final next = _copy(
      totalXp: totalXp + xp,
      totalFloors: totalFloors + run.floors,
      totalPerfects: totalPerfects + (run.perfects < 0 ? 0 : run.perfects),
      runs: runs + 1,
      bestStreak: run.bestStreak > bestStreak ? run.bestStreak : bestStreak,
    );
    final levelAfter = next.level;
    return RunOutcome(
      progress: next,
      xpGained: xp,
      levelBefore: levelBefore,
      levelAfter: levelAfter,
      newlyUnlockedThemes: <TowerTheme>[
        for (final theme in TowerTheme.values)
          if (levelBefore < theme.requiredLevel &&
              levelAfter >= theme.requiredLevel)
            theme,
      ],
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'totalXp': totalXp,
    'selectedTheme': selectedTheme.name,
    'totalFloors': totalFloors,
    'totalPerfects': totalPerfects,
    'runs': runs,
    'bestStreak': bestStreak,
  };

  /// Tolerant parser: any missing or invalid field falls back on its own.
  factory TowerProgress.fromJson(Object? json) {
    if (json is! Map) return const TowerProgress.initial();
    int readInt(Object? value) {
      if (value is! num || !value.isFinite || value < 0) return 0;
      // Clamp absurd values so level math stays fast.
      return value > 100000000 ? 100000000 : value.toInt();
    }

    final progress = TowerProgress(
      totalXp: readInt(json['totalXp']),
      selectedTheme: TowerTheme.downtown,
      totalFloors: readInt(json['totalFloors']),
      totalPerfects: readInt(json['totalPerfects']),
      runs: readInt(json['runs']),
      bestStreak: readInt(json['bestStreak']),
    );
    final theme = json['selectedTheme'];
    return progress.withTheme(
      TowerTheme.fromName(theme is String ? theme : null),
    );
  }

  TowerProgress _copy({
    int? totalXp,
    TowerTheme? selectedTheme,
    int? totalFloors,
    int? totalPerfects,
    int? runs,
    int? bestStreak,
  }) {
    return TowerProgress(
      totalXp: totalXp ?? this.totalXp,
      selectedTheme: selectedTheme ?? this.selectedTheme,
      totalFloors: totalFloors ?? this.totalFloors,
      totalPerfects: totalPerfects ?? this.totalPerfects,
      runs: runs ?? this.runs,
      bestStreak: bestStreak ?? this.bestStreak,
    );
  }
}
