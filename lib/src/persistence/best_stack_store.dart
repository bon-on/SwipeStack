import 'package:shared_preferences/shared_preferences.dart';

class BestStackStore {
  static const String _bestStackKey = 'best_stack';

  Future<int> loadBestStack() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      return preferences.getInt(_bestStackKey) ?? 0;
    } catch (_) {
      return 0;
    }
  }

  Future<void> saveBestStack(int bestStack) async {
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setInt(_bestStackKey, bestStack);
    } catch (_) {
      return;
    }
  }
}
