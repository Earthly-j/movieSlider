import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_card_swiper/flutter_card_swiper.dart';
import '../models/movie.dart';
import '../services/tmdb_service.dart';
import '../widgets/swipe_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TmdbService _tmdbService = TmdbService();
  final CardSwiperController _swiperController = CardSwiperController();

  int _swiperKey = 0;
  int _swipedCount = 0;

  List<Movie> _movies = [];
  List<Movie> _watched = [];
  List<Movie> _skipped = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadMovies();
  }

  @override
  void dispose() {
    _swiperController.dispose();
    super.dispose();
  }

  Future<void> _loadMovies() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final movies = await _tmdbService.fetchOfficialTopRated();
      setState(() {
        _movies = movies;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  /// Remaining unswiped movies.
  int get _remaining => _movies.length - _swipedCount;
  int get _currentIndex => _swipedCount;

  void _showWatchedBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _HistorySheet(
        title: '✅ Watched (${_watched.length})',
        movies: _watched,
        emptyMessage: 'No movies marked as watched yet. Swipe right!',
      ),
    );
  }

  void _showSkippedBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _HistorySheet(
        title: '⏭️ Skipped (${_skipped.length})',
        movies: _skipped,
        emptyMessage: 'No skipped movies yet. Swipe left to skip.',
      ),
    );
  }

  void _showMovieDetail(Movie movie) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _MovieDetailSheet(movie: movie),
    );
  }

  void _resetSwipes() {
    setState(() {
      _watched.clear();
      _skipped.clear();
      _swipedCount = 0;
      _swiperKey++;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        title: const Text('🎬 Movie Swiper'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        actions: [
          // Watched count
          _AnimatedCounterBadge(
            label: 'Watched',
            count: _watched.length,
            color: Colors.green,
            onTap: _showWatchedBottomSheet,
          ),

          // Skipped count
          _AnimatedCounterBadge(
            label: 'Skipped',
            count: _skipped.length,
            color: Colors.redAccent,
            onTap: _showSkippedBottomSheet,
          ),

          // Reset
          if (_watched.isNotEmpty || _skipped.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.restore_rounded),
              onPressed: _resetSwipes,
              tooltip: 'Reset all swipes',
            ),

          // Refresh from API
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadMovies,
            tooltip: 'Refresh movies',
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    // Loading
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading movies...', style: TextStyle(color: Colors.white54)),
          ],
        ),
      );
    }

    // Error
    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline,
                color: Colors.redAccent,
                size: 48,
              ),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadMovies,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    // All swiped
    if (_remaining == 0) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🎬', style: TextStyle(fontSize: 64)),
            const SizedBox(height: 16),
            Text(
              'You\'ve gone through all movies!',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Watched: ${_watched.length} • Skipped: ${_skipped.length}',
              style: const TextStyle(color: Colors.white54),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ElevatedButton(
                  onPressed: _resetSwipes,
                  child: const Text('🔄 Swipe Again'),
                ),
                const SizedBox(width: 12),
                OutlinedButton(
                  onPressed: _loadMovies,
                  child: const Text('📥 New Movies'),
                ),
              ],
            ),
          ],
        ),
      );
    }

    // Card swiper
    return Column(
      children: [
        // Progress indicator
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Row(
            children: [
              Text(
                '$_currentIndex of ${_movies.length}',
                style: const TextStyle(color: Colors.white54, fontSize: 13),
              ),
              const Spacer(),
              Text(
                '⬅️ Skip   Watched ➡️',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.3),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),

        // Swipe hint — only show for first card
        if (_currentIndex == 0)
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text(
              '← Swipe left to skip  •  Swipe right to mark watched →',
              style: TextStyle(color: Colors.white38, fontSize: 12),
            ),
          ),

        // Swiper
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: CardSwiper(
              key: ValueKey(_swiperKey),
              controller: _swiperController,
              cardsCount: math.max(1, _movies.length),
              numberOfCardsDisplayed: math.max(1, _movies.length < 3 ? _movies.length : 3),
              backCardOffset: const Offset(0, 40),
              padding: const EdgeInsets.symmetric(horizontal: 4),
              onSwipe: _onSwipe,
              onEnd: _onEnd,
              cardBuilder:
                  (context, index, percentThresholdX, percentThresholdY) {
                    if (index >= _movies.length) {
                      return Container();
                    }
                    return SwipeCard(movie: _movies[index]);
                  },
              scale: 0.9,
              isLoop: false,
              duration: const Duration(milliseconds: 400),
              allowedSwipeDirection: const AllowedSwipeDirection.symmetric(
                horizontal: true,
                vertical: false,
              ),
            ),
          ),
        ),

        // Action buttons
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Skip button
              _ActionButton(
                icon: Icons.close_rounded,
                label: 'Skip',
                color: Colors.redAccent,
                onTap: () => _swiperController.swipe(CardSwiperDirection.left),
              ),
              const SizedBox(width: 24),

              // Details button
              _ActionButton(
                icon: Icons.info_outline_rounded,
                label: 'Info',
                color: Colors.white54,
                size: 50,
                onTap: () {
                  final idx = _swipedCount;
                  if (idx < _movies.length) {
                    _showMovieDetail(_movies[idx]);
                  }
                },
              ),
              const SizedBox(width: 24),

              // Watched button
              _ActionButton(
                icon: Icons.check_rounded,
                label: 'Watched',
                color: Colors.green,
                onTap: () => _swiperController.swipe(CardSwiperDirection.right),
              ),
            ],
          ),
        ),
      ],
    );
  }

  bool _onSwipe(
    int previousIndex,
    int? currentIndex,
    CardSwiperDirection direction,
  ) {
    if (previousIndex >= _movies.length) return false;

    final movie = _movies[previousIndex];

    if (direction == CardSwiperDirection.right) {
      _watched.add(movie);
    } else {
      _skipped.add(movie);
    }

    setState(() => _swipedCount++);

    return true;
  }

  void _onEnd() {
    // All cards have been swiped; the UI rebuilds automatically via _remaining == 0
  }
}

// ─── Action Button ─────────────────────────────────────────────

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final double size;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    this.size = 60,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.08),
              border: Border.all(color: color.withValues(alpha: 0.4), width: 2),
            ),
            child: Icon(icon, size: size * 0.55, color: color),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

// ─── Counter Badge ─────────────────────────────────────────────

class _AnimatedCounterBadge extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final VoidCallback onTap;

  const _AnimatedCounterBadge({
    required this.label,
    required this.count,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: TextStyle(color: color, fontSize: 12)),
            const SizedBox(width: 6),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (child, animation) {
                return ScaleTransition(scale: animation, child: child);
              },
              child: Text(
                '$count',
                key: ValueKey(count),
                style: TextStyle(
                  color: color,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Movie Detail Sheet ────────────────────────────────────────

class _MovieDetailSheet extends StatelessWidget {
  final Movie movie;

  const _MovieDetailSheet({required this.movie});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return SingleChildScrollView(
          controller: scrollController,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Backdrop
              if (movie.backdropPath.isNotEmpty)
                ClipRRect(
                  child: Image.network(
                    movie.fullBackdropUrl,
                    width: double.infinity,
                    height: 200,
                    fit: BoxFit.cover,
                  ),
                ),

              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      movie.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        if (movie.year.isNotEmpty)
                          Text(
                            movie.year,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 15,
                            ),
                          ),
                        if (movie.year.isNotEmpty) const SizedBox(width: 16),
                        const Icon(
                          Icons.star_rounded,
                          color: Colors.amber,
                          size: 18,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${movie.ratingText} (${movie.voteCount} votes)',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Overview',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      movie.overview.isNotEmpty
                          ? movie.overview
                          : 'No overview available.',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─── History Sheet ─────────────────────────────────────────────

class _HistorySheet extends StatelessWidget {
  final String title;
  final List<Movie> movies;
  final String emptyMessage;

  const _HistorySheet({
    required this.title,
    required this.movies,
    required this.emptyMessage,
  });

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            // Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Title
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            // List
            if (movies.isEmpty)
              Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  emptyMessage,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white54),
                ),
              )
            else
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: movies.length,
                  itemBuilder: (context, index) {
                    final movie = movies[index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.amber.withValues(alpha: 0.2),
                        child: Text(
                          '${index + 1}',
                          style: const TextStyle(
                            color: Colors.amber,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      title: Text(
                        movie.title,
                        style: const TextStyle(color: Colors.white),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        '⭐ ${movie.ratingText}${movie.year.isNotEmpty ? ' • ${movie.year}' : ''}',
                        style: const TextStyle(color: Colors.white54),
                      ),
                    );
                  },
                ),
              ),
          ],
        );
      },
    );
  }
}
