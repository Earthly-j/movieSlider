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

  String get fullPosterUrl => 'https://image.tmdb.org/t/p/w500$posterPath';
  String get fullBackdropUrl => 'https://image.tmdb.org/t/p/w780$backdropPath';
  String get year {
    if (releaseDate.isEmpty) return '';
    return releaseDate.substring(0, 4);
  }

  String get ratingText => voteAverage.toStringAsFixed(1);

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
