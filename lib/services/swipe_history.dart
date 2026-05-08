import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Unique key for a genre + era combination.
class GenreEraKey {
  final String genreName;
  final String eraLabel;

  const GenreEraKey({required this.genreName, required this.eraLabel});

  String get _key => '${genreName}__${eraLabel}';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GenreEraKey &&
          genreName == other.genreName &&
          eraLabel == other.eraLabel;

  @override
  int get hashCode => _key.hashCode;
}

class SwipeHistory {
  static const _watchedKey = 'swipe_watched_ids';
  static const _skippedKey = 'swipe_skipped_ids';

  /// Per-genre/era progress: JSON map of "genre__era" → {"total": int, "watched": int, "skipped": int}
  static const _progressKey = 'swipe_genre_era_progress';

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
    await prefs.remove(_progressKey);
  }

  // ── Per-genre/era progress tracking ──

  /// Save or update progress for a genre+era combination.
  /// [total] is the total number of movies available (before filtering).
  /// [watched] and [skipped] are counts after filtering out history.
  static Future<void> saveGenreEraProgress({
    required String genreName,
    required String eraLabel,
    required int total,
    required int watched,
    required int skipped,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '${genreName}__${eraLabel}';
    final progress = await loadAllProgress();
    progress[key] = {
      'total': total,
      'watched': watched,
      'skipped': skipped,
    };
    await prefs.setString(_progressKey, jsonEncode(progress));
  }

  /// Load all genre/era progress as a map.
  /// Keys are "genre__era" strings.
  static Future<Map<String, Map<String, int>>> loadAllProgress() async {
    final prefs = await SharedPreferences.getInstance();
    final str = prefs.getString(_progressKey);
    if (str == null) return {};
    final decoded = jsonDecode(str) as Map<String, dynamic>;
    return decoded.map((k, v) {
      final m = v as Map<String, dynamic>;
      return MapEntry(k, {
        'total': (m['total'] as num).toInt(),
        'watched': (m['watched'] as num).toInt(),
        'skipped': (m['skipped'] as num).toInt(),
      });
    });
  }

  /// Load progress for a specific genre+era.
  static Future<Map<String, int>?> loadGenreEraProgress({
    required String genreName,
    required String eraLabel,
  }) async {
    final all = await loadAllProgress();
    return all['${genreName}__${eraLabel}'];
  }

  /// Get the completion fraction (0.0 – 1.0) for a genre+era.
  /// Returns null if no progress data exists.
  static Future<double?> loadGenreEraFraction({
    required String genreName,
    required String eraLabel,
  }) async {
    final data = await loadGenreEraProgress(
      genreName: genreName,
      eraLabel: eraLabel,
    );
    if (data == null || data['total'] == 0) return null;
    final done = data['watched']! + data['skipped']!;
    return (done / data['total']!).clamp(0.0, 1.0);
  }
}
