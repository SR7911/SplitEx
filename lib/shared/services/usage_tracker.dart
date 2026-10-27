import 'package:shared_preferences/shared_preferences.dart';

/// Tracks estimated Firestore reads/writes locally per day.
/// Call from any service after performing Firestore operations.
class UsageTracker {
  static const _keyDate = 'usage_date';
  static const _keyReads = 'daily_reads';
  static const _keyWrites = 'daily_writes';

  static UsageTracker? _instance;
  SharedPreferences? _prefs;

  UsageTracker._();
  static UsageTracker get instance => _instance ??= UsageTracker._();

  Future<SharedPreferences> _getPrefs() async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  Future<void> _resetIfNewDay(SharedPreferences prefs) async {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final storedDate = prefs.getString(_keyDate) ?? '';
    if (storedDate != today) {
      await prefs.setString(_keyDate, today);
      await prefs.setInt(_keyReads, 0);
      await prefs.setInt(_keyWrites, 0);
    }
  }

  Future<void> trackReads(int count) async {
    final prefs = await _getPrefs();
    await _resetIfNewDay(prefs);
    final current = prefs.getInt(_keyReads) ?? 0;
    await prefs.setInt(_keyReads, current + count);
  }

  Future<void> trackWrites(int count) async {
    final prefs = await _getPrefs();
    await _resetIfNewDay(prefs);
    final current = prefs.getInt(_keyWrites) ?? 0;
    await prefs.setInt(_keyWrites, current + count);
  }

  Future<Map<String, int>> getDailyUsage() async {
    final prefs = await _getPrefs();
    await _resetIfNewDay(prefs);
    return {
      'reads': prefs.getInt(_keyReads) ?? 0,
      'writes': prefs.getInt(_keyWrites) ?? 0,
    };
  }
}
