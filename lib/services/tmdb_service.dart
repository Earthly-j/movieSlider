import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config.dart';
import '../models/movie.dart';

class TmdbService {
  final http.Client _client;

  TmdbService({http.Client? client}) : _client = client ?? http.Client();

  /// Fetch popular movies sorted by rating descending.
  /// TMDB popular endpoint + client-side sort by vote_average desc.
  Future<List<Movie>> fetchTopRatedMovies({int page = 1}) async {
    // Fetch multiple pages to get a good set of movies
    final List<Movie> allMovies = [];

    for (int p = 1; p <= 3; p++) {
      final uri = Uri.parse(
        '$TMDB_BASE_URL/movie/popular?api_key=$TMDB_API_KEY&page=$p',
      );
      final response = await _client.get(uri);

      if (response.statusCode != 200) {
        throw Exception('TMDB API error: ${response.statusCode}');
      }

      final data = jsonDecode(response.body);
      final results = data['results'] as List;
      allMovies.addAll(results.map((json) => Movie.fromJson(json)));
    }

    // Sort by rating high → low, then by vote count as tiebreaker
    allMovies.sort((a, b) {
      final rating = b.voteAverage.compareTo(a.voteAverage);
      if (rating != 0) return rating;
      // Higher vote count = more reliable rating
      return (b.voteCount).compareTo(a.voteCount);
    });

    return allMovies;
  }

  /// Fetch from the official top_rated endpoint (already sorted).
  Future<List<Movie>> fetchOfficialTopRated({int page = 1}) async {
    final List<Movie> allMovies = [];

    // Fetch 5 pages to get ~100 movies
    for (int p = 1; p <= 5; p++) {
      final uri = Uri.parse(
        '$TMDB_BASE_URL/movie/top_rated?api_key=$TMDB_API_KEY&page=$p',
      );
      final response = await _client.get(uri);

      if (response.statusCode != 200) {
        throw Exception('TMDB API error: ${response.statusCode}');
      }

      final data = jsonDecode(response.body);
      final results = data['results'] as List;
      allMovies.addAll(results.map((json) => Movie.fromJson(json)));
    }

    // Already sorted by rating, but ensure descending
    allMovies.sort((a, b) => b.voteAverage.compareTo(a.voteAverage));

    return allMovies;
  }
}
