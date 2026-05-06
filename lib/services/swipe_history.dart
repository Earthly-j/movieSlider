import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class SwipeHistory {
  static const _watchedKey = 'swipe_watched_ids';
  static const _skippedKey = 'swipe_skipped_ids';

  /// Load persisted watched movie IDs (list of ints)
  static Future<Set<int>> loadWatchedIds() async {
    final prefs = await SharedPreferences.getInstance();
    final str = prefs.getString(_watchedKey);
    if (str == null) return {};
    return (jsonDecode(str) as List).cast<int>().toSet();
  }

  /// Load persisted skipped movie IDs (list of ints)
  static Future<Set<int>> loadSkippedIds() async {
    final prefs = await SharedPreferences.getInstance();
    final str = prefs.getString(_skippedKey);
    if (str == null) return {};
    return (jsonDecode(str) as List).cast<int>().toSet();
  }

  /// Save a watched movie ID
  static Future<void> addWatched(int movieId) async {
    final ids = await loadWatchedIds();
    ids.add(movieId);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_watchedKey, jsonEncode(ids.toList()));
  }

  /// Save a skipped movie ID
  static Future<void> addSkipped(int movieId) async {
    final ids = await loadSkippedIds();
    ids.add(movieId);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_skippedKey, jsonEncode(ids.toList()));
  }

  /// Clear all history
  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_watchedKey);
    await prefs.remove(_skippedKey);
  }
}
