import 'package:flutter/material.dart';
import '../services/tmdb_service.dart';
import 'genre_movie_screen.dart';

class GenreSelectionScreen extends StatefulWidget {
  const GenreSelectionScreen({super.key});

  @override
  State<GenreSelectionScreen> createState() => _GenreSelectionScreenState();
}

class _GenreSelectionScreenState extends State<GenreSelectionScreen> {
  final TmdbService _tmdbService = TmdbService();
  List<_MergedGenre> _mergedGenres = [];
  bool _isLoading = true;
  String? _errorMessage;

  // TMDB genre IDs → merged category key
  static const _mergeMap = <int, String>{
  };

  static const _styles = <String, _GenreStyle>{
    'Action & Thriller':  _GenreStyle(emoji: '💥', colors: [Color(0xFFD32F2F), Color(0xFF616161)]),
    'Comedy & Family':    _GenreStyle(emoji: '😂', colors: [Color(0xFFF57C00), Color(0xFFFFB74D)]),
    'Crime & Horror':     _GenreStyle(emoji: '👻', colors: [Color(0xFF1B1B1B), Color(0xFF78909C)]),
    'Drama & Romance':    _GenreStyle(emoji: '❤️', colors: [Color(0xFF4A148C), Color(0xFFF48FB1)]),
    'Sci-Fi & Fantasy':   _GenreStyle(emoji: '🚀', colors: [Color(0xFF1A237E), Color(0xFF42A5F5)]),
    'Documentary & Arts': _GenreStyle(emoji: '🎬', colors: [Color(0xFF00695C), Color(0xFFF06292)]),
    'History & Adventure': _GenreStyle(emoji: '⚔️', colors: [Color(0xFF3E2723), Color(0xFF00BCD4)]),
  };

  @override
  void initState() {
    super.initState();
    _loadGenres();
  }

  Future<void> _loadGenres() async {
    try {
      final genres = await _tmdbService.fetchGenres();
      final Map<String, List<int>> grouped = {};
      for (final genre in genres) {
        final category = _mergeMap[genre.id] ?? genre.name;
        grouped.putIfAbsent(category, () => []).add(genre.id);
      }
      final merged = grouped.entries
          .where((e) => _styles.containsKey(e.key))
          .toList()
        ..sort((a, b) => a.label.compareTo(b.label));

    } catch (e) {
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
              Text('Loading genres...', style: TextStyle(color: Colors.white54)),
                    const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
                    const SizedBox(height: 16),
                    const SizedBox(height: 16),
                    ElevatedButton(onPressed: _loadGenres, child: const Text('Retry')),
    );
  }

          ),
                itemBuilder: (context, index) {
                      onTap: () {
      builder: (_) => GenreMovieScreenWidget(
      ),
}
  }


  }


  }



    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
        ),
                    ],
                ),
                child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                        ),
                      Text(
                        style: const TextStyle(
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
      ),
    );
  }
}
