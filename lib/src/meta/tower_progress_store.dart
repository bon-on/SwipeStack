import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'tower_progress.dart';

/// Persists [TowerProgress] as a JSON string under [progressKey].
///
/// Storage failures never break play: a read failure or corrupt value loads
/// the initial progress and a write failure is ignored. Tests use
/// [MemoryTowerProgressStore].
class TowerProgressStore {
  const TowerProgressStore();

  static const String progressKey = 'tower_progress_v1';

  Future<TowerProgress> load() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final raw = preferences.getString(progressKey);
      if (raw == null) return const TowerProgress.initial();
      return TowerProgress.fromJson(jsonDecode(raw));
    } catch (_) {
      return const TowerProgress.initial();
    }
  }

  Future<void> save(TowerProgress progress) async {
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(progressKey, jsonEncode(progress.toJson()));
    } catch (_) {
      return;
    }
  }
}

/// In-memory store for tests.
class MemoryTowerProgressStore extends TowerProgressStore {
  MemoryTowerProgressStore([this.value = const TowerProgress.initial()]);

  TowerProgress value;
  int saveCount = 0;

  @override
  Future<TowerProgress> load() async => value;

  @override
  Future<void> save(TowerProgress progress) async {
    value = progress;
    saveCount += 1;
  }
}
