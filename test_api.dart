import 'dart:convert';
import 'package:http/http.dart' as http;

class Movie {
  final int id;
  final String title;
  final String overview;
  final String posterPath;
  final String backdropPath;
  final double voteAverage;
  final int voteCount;
  final String releaseDate;
  final List<int> genreIds;

  Movie({
    required this.id,
    required this.title,
    required this.overview,
    required this.posterPath,
    required this.backdropPath,
    required this.voteAverage,
    required this.voteCount,
    required this.releaseDate,
    required this.genreIds,
  });

  factory Movie.fromJson(Map<String, dynamic> json) {
    return Movie(
      id: json['id'] as int,
      title: json['title'] as String? ?? '',
      overview: json['overview'] as String? ?? '',
      posterPath: json['poster_path'] as String? ?? '',
      backdropPath: json['backdrop_path'] as String? ?? '',
      voteAverage: (json['vote_average'] as num?)?.toDouble() ?? 0.0,
      voteCount: (json['vote_count'] as int?) ?? 0,
      releaseDate: json['release_date'] as String? ?? '',
      genreIds: (json['genre_ids'] as List<dynamic>?)
              ?.map((e) => e as int)
              .toList() ??
          [],
    );
  }
}

void main() async {
  final uri = Uri.parse('https://api.themoviedb.org/3/movie/top_rated?api_key=59b268ca75ebe0dcd4ef51b19587f99f&page=1');
  try {
    final response = await http.get(uri);
    final data = jsonDecode(response.body);
    final results = data['results'] as List;
    final movies = results.map((json) => Movie.fromJson(json)).toList();
    print('Successfully parsed \${movies.length} movies');
  } catch (e) {
    print('Error: \$e');
  }
}
