import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config.dart';
import '../models/movie.dart';

class Genre {
  final int id;
  final String name;
  Genre({required this.id, required this.name});
  factory Genre.fromJson(Map<String, dynamic> json) {
    return Genre(id: json['id'] as int, name: json['name'] as String);
  }
}

class TmdbService {
  final http.Client _client;
  static const _timeout = Duration(seconds: 30);

  TmdbService({http.Client? client})
      : _client = client ?? http.Client();

  /// Fetch with timeout — prevents hanging forever on slow network or rate limits.
  Future<http.Response> _fetch(Uri uri) async {
    try {
      return await _client.get(uri).timeout(_timeout);
    } on TimeoutException {
      throw Exception('Request timed out — check your internet connection');
    }
  }

  // ─── Genres ────────────────────────────────────────────────────

  Future<List<Genre>> fetchGenres() async {
    final uri = Uri.parse(
      '$TMDB_BASE_URL/genre/movie/list?api_key=$TMDB_API_KEY',
    );
    final response = await _fetch(uri);
    if (response.statusCode != 200) {
      throw Exception('TMDB API error: ${response.statusCode}');
    }
    final data = jsonDecode(response.body);
    final genres = data['genres'] as List;
    return genres.map((g) => Genre.fromJson(g)).toList();
  }

  // ─── Discover by Genre (sorted by rating desc) ────────────────

  Future<List<Movie>> fetchMoviesByGenre(List<int> genreIds, {int? yearFrom, int? yearTo}) async {
    final genreQuery = genreIds.map((id) => '$id').join(',');
    // Build date filter params for TMDB discover API
    String dateFilter = '';
    if (yearFrom != null) {
      dateFilter += '&primary_release_date.gte=$yearFrom-01-01';
    }
    if (yearTo != null && yearTo < 2100) {
      dateFilter += '&primary_release_date.lte=$yearTo-12-31';
    }
    // Fetch all pages in parallel — a timeout on one page won't kill the rest
    final futures = List.generate(5, (i) {
      final uri = Uri.parse(
        '$TMDB_BASE_URL/discover/movie'
        '?api_key=$TMDB_API_KEY'
        '&with_genres=$genreQuery'
        '&sort_by=vote_average.desc'
        '&vote_count.gte=200'
        '$dateFilter'
        '&page=${i + 1}',
      );
      return _fetch(uri).then((response) {
        if (response.statusCode != 200) {
          throw Exception('Failed to load genre movies: \${response.statusCode}');
        }
        final data = jsonDecode(response.body);
        final results = data['results'] as List;
        return results.map((json) => Movie.fromJson(json)).toList();
      });
    });

    final results = await Future.wait(futures);
    final allMovies = results.expand((page) => page).toList();

    // Sort high → low rating, tie-break by vote count
    allMovies.sort((a, b) {
      final r = b.voteAverage.compareTo(a.voteAverage);
      return r != 0 ? r : b.voteCount.compareTo(a.voteCount);
    });

    return allMovies;
  }

  // ─── Popular (fallback) ───────────────────────────────────────

  Future<List<Movie>> fetchTopRatedMovies({int page = 1}) async {
    final futures = List.generate(3, (i) {
      final uri = Uri.parse(
        '$TMDB_BASE_URL/movie/popular?api_key=$TMDB_API_KEY&page=${i + 1}',
      );
      return _fetch(uri).then((response) {
        if (response.statusCode != 200) {
          throw Exception('Failed to load popular movies: \${response.statusCode}');
        }
        final data = jsonDecode(response.body);
        final results = data['results'] as List;
        return results.map((json) => Movie.fromJson(json)).toList();
      });
    });

    final results = await Future.wait(futures);
    final allMovies = results.expand((page) => page).toList();

    allMovies.sort((a, b) {
      final rating = b.voteAverage.compareTo(a.voteAverage);
      if (rating != 0) return rating;
      return b.voteCount.compareTo(a.voteCount);
    });
    return allMovies;
  }

  Future<List<Movie>> fetchOfficialTopRated({int page = 1}) async {
    final futures = List.generate(5, (i) {
      final uri = Uri.parse(
        '$TMDB_BASE_URL/movie/top_rated?api_key=$TMDB_API_KEY&page=${i + 1}',
      );
      return _fetch(uri).then((response) {
        if (response.statusCode != 200) {
          throw Exception('Failed to load top rated movies: \${response.statusCode}');
        }
        final data = jsonDecode(response.body);
        final results = data['results'] as List;
        return results.map((json) => Movie.fromJson(json)).toList();
      });
    });

    final results = await Future.wait(futures);
    final allMovies = results.expand((page) => page).toList();

    allMovies.sort((a, b) => b.voteAverage.compareTo(a.voteAverage));
    return allMovies;
  }
}
