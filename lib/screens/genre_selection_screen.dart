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
    28: 'Action & Thriller',    // Action
    53: 'Action & Thriller',    // Thriller
    12: 'History & Adventure',  // Adventure
    37: 'History & Adventure',  // Western
    36: 'History & Adventure',  // History
    80: 'Crime & Horror',       // Crime
    27: 'Crime & Horror',       // Horror
    9648: 'Crime & Horror',     // Mystery
    35: 'Comedy & Family',      // Comedy
    10751: 'Comedy & Family',   // Family
    18: 'Drama & Romance',      // Drama
    10749: 'Drama & Romance',   // Romance
    10770: 'Documentary & Arts', // TV Movie
    99: 'Documentary & Arts',    // Documentary
    10402: 'Documentary & Arts', // Music
    878: 'Sci-Fi & Fantasy',     // Science Fiction
    14: 'Sci-Fi & Fantasy',      // Fantasy
    16: 'Sci-Fi & Fantasy',      // Animation
  };

  // Style for each merged category
  static const _styles = <String, _GenreStyle>{
    'Action & Thriller':  _GenreStyle(emoji: '💥', colors: [Color(0xFFD32F2F), Color(0xFF616161)]),
    'Comedy & Family':    _GenreStyle(emoji: '😂', colors: [Color(0xFFF57C00), Color(0xFFFFB74D)]),
    'Crime & Horror':     _GenreStyle(emoji: '👻', colors: [Color(0xFF1B1B1B), Color(0xFF78909C)]),
    'Drama & Romance':    _GenreStyle(emoji: '❤️', colors: [Color(0xFF4A148C), Color(0xFFF48FB1)]),
    'Sci-Fi & Fantasy':   _GenreStyle(emoji: '🚀', colors: [Color(0xFF1A237E), Color(0xFF42A5F5)]),
    'Documentary & Arts': _GenreStyle(emoji: '🎬', colors: [Color(0xFF00695C), Color(0xFFF06292)]),
    'History & Adventure':_GenreStyle(emoji: '⚔️', colors: [Color(0xFF3E2723), Color(0xFF00BCD4)]),
  };

  static const _defaultStyle = _GenreStyle(
    emoji: '🎬',
    colors: [Color(0xFF424242), Color(0xFF757575)],
  );

  @override
  void initState() {
    super.initState();
    _loadGenres();
  }

  Future<void> _loadGenres() async {
    try {
      final genres = await _tmdbService.fetchGenres();

      // Merge individual TMDB genres into grouped categories
      final Map<String, List<int>> grouped = {};
      for (final genre in genres) {
        final category = _mergeMap[genre.id] ?? genre.name;
        grouped.putIfAbsent(category, () => []).add(genre.id);
      }

      // Build merged genre list (preserves insertion order, sorted by category name)
      final merged = grouped.entries
          .where((e) => _styles.containsKey(e.key))
          .map((e) => _MergedGenre(
                label: e.key,
                genreIds: e.value,
                style: _styles[e.key]!,
              ))
          .toList()
        ..sort((a, b) => a.label.compareTo(b.label));

      setState(() {
        _mergedGenres = merged;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        title: const Text('🎬 Pick a Genre'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading genres...', style: TextStyle(color: Colors.white54)),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
              const SizedBox(height: 16),
              Text(_errorMessage!, textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70)),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: _loadGenres, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.6,
      ),
      itemCount: _mergedGenres.length,
      itemBuilder: (context, index) {
        final merged = _mergedGenres[index];
        return _GenreCard(
          label: merged.label,
          style: merged.style,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => GenreMovieScreenWidget(
                  genreName: merged.label,
                  genreIds: merged.genreIds,
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// ─── Merged Genre ────────────────────────────────────────────────

class _MergedGenre {
  final String label;
  final List<int> genreIds;
  final _GenreStyle style;
  const _MergedGenre({required this.label, required this.genreIds, required this.style});
}

// ─── Genre Style ────────────────────────────────────────────────

class _GenreStyle {
  final String emoji;
  final List<Color> colors;
  const _GenreStyle({required this.emoji, required this.colors});
}

// ─── Genre Card ──────────────────────────────────────────────────

class _GenreCard extends StatelessWidget {
  final String label;
  final _GenreStyle style;
  final VoidCallback onTap;

  const _GenreCard({
    required this.label,
    required this.style,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: style.colors,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                style.emoji,
                style: const TextStyle(fontSize: 36),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  shadows: [Shadow(blurRadius: 4, color: Colors.black)],
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
