import 'package:shared_preferences/shared_preferences.dart';

class LocalStore {
  static const _kLastCompletedDay = 'last_completed_day';
  static const _kCompletedCount = 'completed_count';
  static const _kLastMode = 'last_mode';
  static const _kDurationSeconds = 'duration_seconds';

  Future<int> getDurationSeconds() async {
    final p = await SharedPreferences.getInstance();
    return p.getInt(_kDurationSeconds) ?? 60;
  }

  Future<void> setDurationSeconds(int seconds) async {
    final p = await SharedPreferences.getInstance();
    await p.setInt(_kDurationSeconds, seconds);
  }

  Future<String?> getLastCompletedDay() async {
    final p = await SharedPreferences.getInstance();
    return p.getString(_kLastCompletedDay);
  }

  Future<int> getCompletedCount() async {
    final p = await SharedPreferences.getInstance();
    return p.getInt(_kCompletedCount) ?? 0;
  }

  Future<int?> getLastModeIndex() async {
    final p = await SharedPreferences.getInstance();
    return p.getInt(_kLastMode);
  }

  Future<void> saveCompletedDay({
    required String dayKey,
    required int modeIndex,
  }) async {
    final p = await SharedPreferences.getInstance();
    final current = p.getInt(_kCompletedCount) ?? 0;
    await p.setString(_kLastCompletedDay, dayKey);
    await p.setInt(_kCompletedCount, current + 1);
    await p.setInt(_kLastMode, modeIndex);
  }
}
