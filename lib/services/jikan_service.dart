import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

/// Base URL for Jikan v4 REST API (unofficial MyAnimeList API — no key needed).
const String JIKAN_BASE_URL = 'https://api.jikan.moe/v4';

class AnimeGenre {
  final int malId;
  final String name;
  final String url;
  final int count;

  const AnimeGenre({
    required this.malId,
    required this.name,
    required this.url,
    required this.count,
  });

  factory AnimeGenre.fromJson(Map<String, dynamic> json) {
    return AnimeGenre(
      malId: json['mal_id'] as int? ?? 0,
      name: json['name'] as String? ?? '',
      url: json['url'] as String? ?? '',
      count: json['count'] as int? ?? 0,
    );
  }
}

class Anime {
  final int malId;
  final String title;
  final String titleEnglish;
  final String synopsis;
  final String imageUrl;
  final double score;
  final int scoredBy;
  final int episodes;
  final String status;
  final String rating;
  final String season;
  final int year;
  final List<String> genres;
  final List<String> themes;
  final String type; // TV, Movie, OVA, ONA, Special, Music
  final String trailerUrl;

  const Anime({
    required this.malId,
    required this.title,
    required this.titleEnglish,
    required this.synopsis,
    required this.imageUrl,
    required this.score,
    required this.scoredBy,
    required this.episodes,
    required this.status,
    required this.rating,
    required this.season,
    required this.year,
    required this.genres,
    required this.themes,
    required this.type,
    required this.trailerUrl,
  });

  /// Display title — prefer English, fall back to romaji.
  String get displayTitle => titleEnglish.isNotEmpty ? titleEnglish : title;

  /// Year as string.
  String get yearString => year > 0 ? '$year' : '';

  /// Score formatted.
  String get scoreText => score > 0 ? score.toStringAsFixed(1) : 'N/A';

  /// Type + episode count label.
  String get typeLabel {
    if (episodes > 0) return '$type • $episodes eps';
    return type;
  }

  factory Anime.fromJson(Map<String, dynamic> json) {
    return Anime(
      malId: json['mal_id'] as int? ?? 0,
      title: json['title'] as String? ?? '',
      titleEnglish: json['title_english'] as String? ?? '',
      synopsis: json['synopsis'] as String? ?? '',
      imageUrl: json['images']?['jpg']?['large_image_url'] as String? ??
          json['images']?['jpg']?['image_url'] as String? ??
          '',
      score: (json['score'] as num?)?.toDouble() ?? 0.0,
      scoredBy: (json['scored_by'] as int?) ?? 0,
      episodes: (json['episodes'] as int?) ?? 0,
      status: json['status'] as String? ?? '',
      rating: json['rating'] as String? ?? '',
      season: json['season'] as String? ?? '',
      year: (json['year'] as int?) ?? 0,
      genres: (json['genres'] as List<dynamic>?)
              ?.map((g) => g['name'] as String? ?? '')
              .toList() ??
          [],
      themes: (json['themes'] as List<dynamic>?)
              ?.map((t) => t['name'] as String? ?? '')
              .toList() ??
          [],
      type: json['type'] as String? ?? '',
      trailerUrl: json['trailer']?['url'] as String? ?? '',
    );
  }
}

class JikanService {
  final http.Client _client;
  static const _timeout = Duration(seconds: 30);

  /// Jikan rate-limits aggressively — we space requests.
  DateTime? _lastRequest;
  static const _minInterval = Duration(milliseconds: 350);

  JikanService({http.Client? client})
      : _client = client ?? http.Client();

  /// Fetch with rate-limit delay.
  Future<http.Response> _fetch(Uri uri) async {
    // Respect Jikan's rate limit (3 req/sec)
    if (_lastRequest != null) {
      final elapsed = DateTime.now().difference(_lastRequest!);
      if (elapsed < _minInterval) {
        await Future.delayed(_minInterval - elapsed);
      }
    }
    _lastRequest = DateTime.now();

    final headers = {'User-Agent': 'MovieSlider/1.0 (Flutter App)'};

    try {
      final response = await _client.get(uri, headers: headers).timeout(_timeout);
      if (response.statusCode == 429) {
        print('[Jikan] Rate limited, waiting 3s...');
        await Future.delayed(const Duration(seconds: 3));
        return await _client.get(uri, headers: headers).timeout(_timeout);
      }
      return response;
    } on TimeoutException {
      throw Exception('Jikan API timed out — check your connection');
    }
  }

  // ─── Anime Genres ─────────────────────────────────────────────

  Future<List<AnimeGenre>> fetchAnimeGenres() async {
    print('[Jikan] Fetching genres from $JIKAN_BASE_URL/genres/anime');
    final uri = Uri.parse('$JIKAN_BASE_URL/genres/anime');
    final response = await _fetch(uri);
    print('[Jikan] Response status: ${response.statusCode}');
    if (response.statusCode != 200) {
      throw Exception('Jikan API error: ${response.statusCode}');
    }
    final data = jsonDecode(response.body);
    final genres = data['data'] as List? ?? [];
    print('[Jikan] Parsed ${genres.length} genres');
    return genres.map((g) => AnimeGenre.fromJson(g)).toList();
  }

  // ─── Top Anime ────────────────────────────────────────────────

  /// Fetch top anime sorted by score. [page] is 1-indexed.
  /// Max 25 per page. We fetch [pages] pages.
  Future<List<Anime>> fetchTopAnime({int pages = 4, String type = ''}) async {
    final List<Anime> allAnime = [];
    for (var i = 1; i <= pages; i++) {
      var url = '$JIKAN_BASE_URL/top/anime?page=$i';
      if (type.isNotEmpty) url += '&type=$type';
      final uri = Uri.parse(url);
      final response = await _fetch(uri);
      if (response.statusCode != 200) break;
      final data = jsonDecode(response.body);
      final results = data['data'] as List? ?? [];
      for (final json in results) {
        allAnime.add(Anime.fromJson(json));
      }
    }
    // Sort by score descending
    allAnime.sort((a, b) => b.score.compareTo(a.score));
    return allAnime;
  }

  // ─── Anime by Genre ───────────────────────────────────────────

  /// Fetch anime filtered by genre IDs from Jikan.
  /// Returns a [Stream] that emits the growing list as each page loads,
  /// so the UI can display cards progressively instead of waiting for all pages.
  Stream<List<Anime>> fetchAnimeByGenre(
    int genreId, {
    int pages = 4,
    String? type,
  }) async* {
    final List<Anime> allAnime = [];
    for (var i = 1; i <= pages; i++) {
      var url = '$JIKAN_BASE_URL/anime?genres=$genreId&page=$i&order_by=score&sort=desc&min_score=7';
      if (type != null && type.isNotEmpty) url += '&type=$type';
      final uri = Uri.parse(url);
      final response = await _fetch(uri);
      if (response.statusCode != 200) break;
      final data = jsonDecode(response.body);
      final results = data['data'] as List? ?? [];
      final hasMore = results.length >= 25; // full page = more available
      for (final json in results) {
        allAnime.add(Anime.fromJson(json));
      }
      allAnime.sort((a, b) => b.score.compareTo(a.score));
      yield List.unmodifiable(allAnime);
      if (!hasMore) break;
    }
  }

  // ─── Anime by Season ──────────────────────────────────────────

  /// Fetch anime from a specific season/year.
  Future<List<Anime>> fetchSeasonalAnime({
    required int year,
    required String season,
    int pages = 3,
  }) async {
    final List<Anime> allAnime = [];
    for (var i = 1; i <= pages; i++) {
      final uri = Uri.parse(
        '$JIKAN_BASE_URL/seasons/$year/$season?page=$i&order_by=score&sort=desc',
      );
      final response = await _fetch(uri);
      if (response.statusCode != 200) break;
      final data = jsonDecode(response.body);
      final results = data['data'] as List? ?? [];
      for (final json in results) {
        allAnime.add(Anime.fromJson(json));
      }
    }
    allAnime.sort((a, b) => b.score.compareTo(a.score));
    return allAnime;
  }

  // ─── Search Anime ─────────────────────────────────────────────

  Future<List<Anime>> searchAnime(String query, {int pages = 2}) async {
    final List<Anime> allAnime = [];
    for (var i = 1; i <= pages; i++) {
      final uri = Uri.parse(
        '$JIKAN_BASE_URL/anime?q=${Uri.encodeComponent(query)}&page=$i&order_by=score&sort=desc',
      );
      final response = await _fetch(uri);
      if (response.statusCode != 200) break;
      final data = jsonDecode(response.body);
      final results = data['data'] as List? ?? [];
      for (final json in results) {
        allAnime.add(Anime.fromJson(json));
      }
    }
    allAnime.sort((a, b) => b.score.compareTo(a.score));
    return allAnime;
  }

  /// Fetch currently airing top anime as "recommendations".
  Future<List<Anime>> fetchRecommendations({int pages = 2}) async {
    final uri = Uri.parse(
      '$JIKAN_BASE_URL/seasons/now?page=1&order_by=score&sort=desc',
    );
    final response = await _fetch(uri);
    if (response.statusCode != 200) {
      return fetchTopAnime(pages: 2);
    }
    final data = jsonDecode(response.body);
    final results = data['data'] as List? ?? [];
    return results.map((json) => Anime.fromJson(json)).toList();
  }

  // ─── Top Anime by Year Range ──────────────────────────────────

  /// Fetch top anime within a year range. Fetches multiple pages and filters client-side.
  Future<List<Anime>> fetchTopAnimeByYearRange({
    required int startYear,
    required int endYear,
    int pages = 4,
  }) async {
    final allAnime = await fetchTopAnime(pages: pages);
    return allAnime.where((a) {
      if (a.year <= 0) return false;
      return a.year >= startYear && a.year <= endYear;
    }).toList();
  }
}

