import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_card_swiper/flutter_card_swiper.dart';
import '../models/movie.dart';
import '../services/tmdb_service.dart';
import '../services/swipe_history.dart';
import '../widgets/swipe_card.dart';

/// Page 2 — swipe through movies in a specific genre, sorted high→low rating.
/// Movies already watched or skipped (persisted) are filtered out.
class GenreMovieScreenWidget extends StatefulWidget {
  final String genreName;
  final List<int> genreIds;
  final String? eraLabel;
  final int? eraStart;
  final int? eraEnd;
  const GenreMovieScreenWidget({
    super.key,
    required this.genreName,
    required this.genreIds,
    this.eraLabel,
    this.eraStart,
    this.eraEnd,
  });

  @override
  State<GenreMovieScreenWidget> createState() => _GenreMovieScreenWidgetState();
}

class _GenreMovieScreenWidgetState extends State<GenreMovieScreenWidget> {
  final TmdbService _tmdbService = TmdbService();
  final CardSwiperController _swiperController = CardSwiperController();

  int _swiperKey = 0;
  int _swipedCount = 0;

  List<Movie> _movies = []; // filtered (no watched/skipped)
  final List<Movie> _watched = [];
  final List<Movie> _skipped = [];
  Set<int> _watchedIds = {};
  Set<int> _skippedIds = {};
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      _watchedIds = await SwipeHistory.loadWatchedIds();
      _skippedIds = await SwipeHistory.loadSkippedIds();
    } catch (_) {
      // SharedPreferences not available — start with empty history
      _watchedIds = {};
      _skippedIds = {};
    }
    if (!mounted) return;
    await _loadMovies();
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
      final movies = await _tmdbService.fetchMoviesByGenre(
        widget.genreIds,
        yearFrom: widget.eraStart,
        yearTo: widget.eraEnd,
      );
      if (!mounted) return;
      setState(() {
        _movies = movies
            .where((m) => !_watchedIds.contains(m.id) && !_skippedIds.contains(m.id))
            .toList();
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  int get _remaining => _movies.length - _swipedCount;
  int get _currentIndex => _swipedCount;

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(widget.eraLabel != null
            ? '${widget.genreName} (${widget.eraLabel})'
            : '${widget.genreName} Movies'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        actions: [
          _AnimatedCounterBadge(
            label: 'Watched',
            count: _watched.length,
            color: Colors.green,
            onTap: () => _showHistorySheet(watched: true),
          ),
          _AnimatedCounterBadge(
            label: 'Skipped',
            count: _skipped.length,
            color: Colors.redAccent,
            onTap: () => _showHistorySheet(watched: false),
          ),
        ],
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
            Text('Loading movies...', style: TextStyle(color: Colors.white54)),
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
              ElevatedButton(onPressed: _loadMovies, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    if (_movies.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('📭', style: TextStyle(fontSize: 64)),
            const SizedBox(height: 16),
            Text(
              'No new movies in ${widget.genreName}!',
              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text('You\'ve already gone through them all.',
                style: TextStyle(color: Colors.white54)),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Pick Another Genre'),
            ),
          ],
        ),
      );
    }

    if (_remaining == 0) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🎬', style: TextStyle(fontSize: 64)),
            const SizedBox(height: 16),
            Text(
              'You\'ve gone through all ${widget.genreName} movies!',
              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
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
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => _HistoryScreen(watched: _watched, skipped: _skipped),
                      ),
                    );
                  },
                  child: const Text('📋 View History'),
                ),
                const SizedBox(width: 12),
                OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('🔀 Another Genre'),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Row(
            children: [
              Text('$_currentIndex of ${_movies.length}',
                  style: const TextStyle(color: Colors.white54, fontSize: 13)),
              const Spacer(),
              Text('⬅️ Skip   Watched ➡️',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 12)),
            ],
          ),
        ),
        if (_currentIndex == 0)
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text(
              '← Swipe left to skip  •  Swipe right to mark watched →',
              style: TextStyle(color: Colors.white38, fontSize: 12),
            ),
          ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: CardSwiper(
              key: ValueKey(_swiperKey),
              controller: _swiperController,
              cardsCount: _movies.length,
              numberOfCardsDisplayed: 3,
              backCardOffset: const Offset(0, 40),
              padding: const EdgeInsets.symmetric(horizontal: 4),
              onSwipe: _onSwipe,
              onEnd: _onEnd,
              cardBuilder: (context, index, percentThresholdX, percentThresholdY) {
                if (index >= _movies.length) return Container();
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
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _ActionButton(
                icon: Icons.close_rounded,
                label: 'Skip',
                color: Colors.redAccent,
                onTap: () => _swiperController.swipe(CardSwiperDirection.left),
              ),
              const SizedBox(width: 24),
              _ActionButton(
                icon: Icons.info_outline_rounded,
                label: 'Info',
                color: Colors.white54,
                size: 50,
                onTap: () {
                  final idx = _swipedCount;
                  if (idx < _movies.length) _showMovieDetail(_movies[idx]);
                },
              ),
              const SizedBox(width: 24),
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

  bool _onSwipe(int previousIndex, int? currentIndex, CardSwiperDirection direction) {
    if (previousIndex >= _movies.length) return false;

    final movie = _movies[previousIndex];
    if (direction == CardSwiperDirection.right) {
      _watched.add(movie);
      SwipeHistory.addWatched(movie.id);
    } else {
      _skipped.add(movie);
      SwipeHistory.addSkipped(movie.id);
    }

    setState(() => _swipedCount++);

    return true;
  }

  void _onEnd() {}

  void _showHistorySheet({required bool watched}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _HistorySheet(
        title: watched ? '✅ Watched (${_watched.length})' : '⏭️ Skipped (${_skipped.length})',
        movies: watched ? _watched : _skipped,
        emptyMessage: watched
            ? 'No movies marked as watched yet. Swipe right!'
            : 'No skipped movies yet. Swipe left to skip.',
      ),
    );
  }
}

// ─── Action Button ──────────────────────────────────────────────

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
              color: color.withValues(alpha: 0.15),
              border: Border.all(color: color, width: 2),
            ),
            child: Icon(icon, color: color, size: 30),
          ),
        ),
        const SizedBox(height: 6),
        Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w500)),
      ],
    );
  }
}

// ─── Counter Badge ──────────────────────────────────────────────

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
              transitionBuilder: (child, animation) => ScaleTransition(scale: animation, child: child),
              child: Text(
                '$count',
                key: ValueKey(count),
                style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Movie Detail Sheet ─────────────────────────────────────────

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
              Center(
                child: Container(
                  width: 40, height: 4,
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              if (movie.backdropPath.isNotEmpty)
                ClipRRect(
                  child: Image.network(movie.fullBackdropUrl, width: double.infinity, height: 200, fit: BoxFit.cover),
                ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(movie.title, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        if (movie.year.isNotEmpty)
                          Text(movie.year, style: const TextStyle(color: Colors.white70, fontSize: 15)),
                        if (movie.year.isNotEmpty) const SizedBox(width: 16),
                        const Icon(Icons.star_rounded, color: Colors.amber, size: 18),
                        const SizedBox(width: 4),
                        Text('${movie.ratingText} (${movie.voteCount} votes)',
                            style: const TextStyle(color: Colors.white70, fontSize: 15)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text('Overview', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text(
                      movie.overview.isNotEmpty ? movie.overview : 'No overview available.',
                      style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.5),
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

// ─── History Bottom Sheet ───────────────────────────────────────

class _HistorySheet extends StatelessWidget {
  final String title;
  final List<Movie> movies;
  final String emptyMessage;

  const _HistorySheet({required this.title, required this.movies, required this.emptyMessage});

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
            Center(
              child: Container(
                width: 40, height: 4,
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            ),

            if (movies.isEmpty)
              Padding(
                padding: const EdgeInsets.all(32),
                child: Text(emptyMessage, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white54)),
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
                        child: Text('${index + 1}', style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
                      ),
                      title: Text(movie.title, style: const TextStyle(color: Colors.white), maxLines: 1, overflow: TextOverflow.ellipsis),
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

// ─── Full History Screen (Page 3) ──────────────────────────────

class _HistoryScreen extends StatefulWidget {
  final List<Movie> watched;
  final List<Movie> skipped;

  const _HistoryScreen({required this.watched, required this.skipped});

  @override
  State<_HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<_HistoryScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _clearAll() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Clear All?', style: TextStyle(color: Colors.white)),
        content: const Text(
          'This will reset all your watched and skipped movies across all genres.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Clear All', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await SwipeHistory.clearAll();
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('📋 My History'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          if (widget.watched.isNotEmpty || widget.skipped.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_rounded),
              onPressed: _clearAll,
              tooltip: 'Clear all history',
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 2,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white54,
          tabs: [
            Tab(text: '✅ Watched (${widget.watched.length})'),
            Tab(text: '⏭️ Skipped (${widget.skipped.length})'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildMovieList(widget.watched, 'No movies marked as watched yet.'),
          _buildMovieList(widget.skipped, 'No skipped movies yet.'),
        ],
      ),
    );
  }

  Widget _buildMovieList(List<Movie> movies, String emptyMsg) {
    if (movies.isEmpty) {
      return Center(
        child: Text(emptyMsg, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white54)),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: movies.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) => _HistoryCard(movie: movies[index], rank: index + 1),
    );
  }
}

// ─── History Card with poster ───────────────────────────────────

class _HistoryCard extends StatelessWidget {
  final Movie movie;
  final int rank;

  const _HistoryCard({required this.movie, required this.rank});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 6, offset: const Offset(0, 3)),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            alignment: Alignment.center,
            child: Text('#$rank', style: const TextStyle(color: Colors.amber, fontSize: 14, fontWeight: FontWeight.bold)),
          ),
          ClipRRect(
            borderRadius: const BorderRadius.only(topLeft: Radius.circular(14), bottomLeft: Radius.circular(14)),
            child: movie.posterPath.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: movie.fullPosterUrl,
                    width: 60,
                    height: 90,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(width: 60, height: 90, color: Colors.white10, child: const Icon(Icons.movie, color: Colors.white24)),
                    errorWidget: (_, __, ___) => Container(width: 60, height: 90, color: Colors.white10, child: const Icon(Icons.movie, color: Colors.white24)),
                  )
                : Container(width: 60, height: 90, color: Colors.white10, child: const Icon(Icons.movie, color: Colors.white24)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(movie.title, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.star_rounded, color: Colors.amber, size: 14),
                      const SizedBox(width: 3),
                      Text(movie.ratingText, style: const TextStyle(color: Colors.amber, fontSize: 13)),
                      if (movie.year.isNotEmpty) ...[
                        const SizedBox(width: 10),
                        Text(movie.year, style: const TextStyle(color: Colors.white54, fontSize: 13)),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    movie.overview.isNotEmpty ? movie.overview : '',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12, height: 1.3),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
