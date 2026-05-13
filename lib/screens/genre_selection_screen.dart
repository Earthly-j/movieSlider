import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../models/movie.dart';
import '../services/tmdb_service.dart';
import '../services/jikan_service.dart';
import '../services/swipe_history.dart';
import 'genre_movie_screen.dart';
import 'anime_browse_screen.dart';


/// Main categories for the top-level navigation.
enum _MainTab {
  movies('Movies', '🎬', [Color(0xFF6366F1), Color(0xFF818CF8)],
      'Discover top-rated movies across every genre and era'),
  anime('Anime', '👺', [Color(0xFFEC4899), Color(0xFFF472B6)],
      'Explore the best anime series and films'),
  songs('Songs', '🎵', [Color(0xFFF59E0B), Color(0xFFFBBF24)],
      'Find trending songs and soundtracks'),
  indieGames('Indie Games', '🕹️', [Color(0xFF10B981), Color(0xFF34D399)],
      'Discover creative and unique indie games');

  const _MainTab(this.label, this.emoji, this.colors, this.subtitle);
  final String label;
  final String emoji;
  final List<Color> colors;
  final String subtitle;
}

/// Era definitions for filtering movies by decade.
enum _Era {
  eighties('80–89', 1980, 1989),
  nineties('90–99', 1990, 1999),
  zeroes('00–09', 2000, 2009),
  tens('10–19', 2010, 2019),
  twenties('20–Now', 2020, 2100);

  const _Era(this.label, this.start, this.end);
  final String label;
  final int start;
  final int end;
  static const all = [_Era.eighties, _Era.nineties, _Era.zeroes, _Era.tens, _Era.twenties];
}

/// Style for the Anime section (used by top-level widgets).
const _animeStyle = _GenreStyle(emoji: '👺', colors: [Color(0xFFEC4899), Color(0xFFF472B6)]);

class GenreSelectionScreen extends StatefulWidget {
  const GenreSelectionScreen({super.key});

  @override
  State<GenreSelectionScreen> createState() => _GenreSelectionScreenState();
}

class _GenreSelectionScreenState extends State<GenreSelectionScreen> {
  final TmdbService _tmdbService = TmdbService();
  final JikanService _jikanService = JikanService();
  List<_MergedGenre> _mergedGenres = [];
  bool _isLoading = true;
  String? _errorMessage;
  _MainTab _selectedTab = _MainTab.movies;

  // ── Anime state ──
  List<Anime> _allTopAnime = [];
  bool _animeLoading = false;

  // Controllers
  late final PageController _categoryController;
  late final PageController _verticalPageController;
  static const int _vMiddle = 50000;
  static const int _catMiddle = 50000;
  late final FixedExtentScrollController _genreWheelController;

  // ── Movie cache per genre label ──
  final Map<String, List<Movie>> _genreMovieCache = {};
  final Set<String> _genreLoading = {};

  /// Incremented when user returns from a swipe screen so era cards reload progress.
  int _progressRefreshKey = 0;

  // TMDB genre IDs → merged category key
  static const _mergeMap = <int, String>{
    28: 'Action & Thriller', 53: 'Action & Thriller',
    12: 'History & Adventure', 37: 'History & Adventure', 36: 'History & Adventure',
    80: 'Crime & Horror', 27: 'Crime & Horror', 9648: 'Crime & Horror',
    35: 'Comedy & Family', 10751: 'Comedy & Family',
    18: 'Drama & Romance', 10749: 'Drama & Romance',
    10770: 'Documentary & Arts', 99: 'Documentary & Arts', 10402: 'Documentary & Arts',
    878: 'Sci-Fi & Fantasy', 14: 'Sci-Fi & Fantasy', 16: 'Sci-Fi & Fantasy',
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
    _categoryController = PageController(initialPage: _catMiddle, viewportFraction: 0.40);
    _verticalPageController = PageController(initialPage: _vMiddle, viewportFraction: 0.65);
    _genreWheelController = FixedExtentScrollController(initialItem: _vMiddle);
    _loadGenres();
  }

  @override
  void dispose() {
    _categoryController.dispose();
    _verticalPageController.dispose();
    _genreWheelController.dispose();
    super.dispose();
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
          .map((e) => _MergedGenre(label: e.key, genreIds: e.value, style: _styles[e.key]!))
          .toList()
        ..sort((a, b) => a.label.compareTo(b.label));

      if (mounted) setState(() { _mergedGenres = merged; _isLoading = false; });
    } catch (e) {
      if (mounted) setState(() { _errorMessage = e.toString(); _isLoading = false; });
    }
  }

  /// Fetch movies for a genre — caches the result so it only loads once.
  Future<void> _fetchGenreMovies(String label, List<int> genreIds) async {
    if (_genreMovieCache.containsKey(label) || _genreLoading.contains(label)) return;
    _genreLoading.add(label);
    try {
      final movies = await _tmdbService.fetchMoviesByGenre(genreIds);
      _genreMovieCache[label] = movies;
    } catch (_) {
      _genreMovieCache[label] = [];
    } finally {
      _genreLoading.remove(label);
      if (mounted) setState(() {});
    }
  }

  /// Fetch all top anime once — each section filters by era internally.
  Future<void> _fetchAllTopAnime() async {
    if (_allTopAnime.isNotEmpty || _animeLoading) return;
    _animeLoading = true;
    if (mounted) setState(() {});
    try {
      final anime = await _jikanService.fetchTopAnime(pages: 6);
      _allTopAnime = anime;
    } catch (_) {
      _allTopAnime = [];
    } finally {
      _animeLoading = false;
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: _isLoading
          ? const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              CircularProgressIndicator(), SizedBox(height: 16),
              Text('Loading genres...', style: TextStyle(color: Colors.white54)),
            ]))
          : _errorMessage != null
              ? Center(child: Padding(padding: const EdgeInsets.all(32), child: Column(
                  mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
                    const SizedBox(height: 16),
                    Text(_errorMessage!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70)),
                    const SizedBox(height: 16),
                    ElevatedButton(onPressed: _loadGenres, child: const Text('Retry')),
                  ])))
              : _mainContent(),
    );
  }

  Widget _mainContent() {
    return Column(
      children: [
        // ─── Fixed Header ───
        SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 2),
            child: Row(
              children: [


              ],
            ),
          ),
        ),

        // ─── Category Slot Carousel (Game / Anime Song / Movie) ───
        SizedBox(
          height: 100,
          child: PageView.builder(
            controller: _categoryController,
            itemCount: null, // infinite — wraps via modulo
            onPageChanged: (page) {
              final tabIndex = page % _MainTab.values.length;
              if (_selectedTab != _MainTab.values[tabIndex]) {
                setState(() => _selectedTab = _MainTab.values[tabIndex]);
                // Trigger anime load when switching to anime tab
                if (_MainTab.values[tabIndex] == _MainTab.anime &&
                    _allTopAnime.isEmpty && !_animeLoading) {
                  _fetchAllTopAnime();
                }
              }
            },
            itemBuilder: (context, index) {
              final tab = _MainTab.values[index % _MainTab.values.length];
              return _CategoryCard(
                tab: tab,
                isSelected: _selectedTab == tab,
                onTap: () {
                  // Animate to the nearest occurrence of this tab
                  final currentPage = _categoryController.page?.round() ?? _catMiddle;
                  final currentTab = currentPage % _MainTab.values.length;
                  final targetTab = _MainTab.values.indexOf(tab);
                  int diff = targetTab - currentTab;
                  if (diff > _MainTab.values.length / 2) diff -= _MainTab.values.length;
                  if (diff < -_MainTab.values.length / 2) diff += _MainTab.values.length;
                  _categoryController.animateToPage(
                    currentPage + diff,
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeInOut,
                  );
                  // Preload anime when tapping the anime tab card
                  if (tab == _MainTab.anime && _allTopAnime.isEmpty && !_animeLoading) {
                    _fetchAllTopAnime();
                  }
                },
              );
            },
          ),
        ),
        const SizedBox(height: 8),

        // ─── Content below synced to selected tab ───
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: _buildTabContent(),
          ),
        ),
      ],
    );
  }

  Widget _buildTabContent() {
    switch (_selectedTab) {
      case _MainTab.movies:
        return ListWheelScrollView.useDelegate(
          key: const ValueKey('movies'),
          controller: _genreWheelController,
          itemExtent: MediaQuery.of(context).size.height * 0.35,
          diameterRatio: 100.0,
          perspective: 0.0001,
          squeeze: 1.0,
          physics: const BouncingScrollPhysics(),
          childDelegate: ListWheelChildBuilderDelegate(
            childCount: null,
            builder: (context, index) {
              final genreIndex = index % _mergedGenres.length;
              final genre = _mergedGenres[genreIndex];
              // Trigger fetch if not cached yet
              _fetchGenreMovies(genre.label, genre.genreIds);
              final movies = _genreMovieCache[genre.label] ?? [];
              final loading = _genreLoading.contains(genre.label) && movies.isEmpty;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _GenreSection(
                  key: ValueKey('genre_${genreIndex}_$_progressRefreshKey'),
                  genre: genre,
                  movies: movies,
                  isLoading: loading,
                  onTapExplore: () => _openGenre(genre),
                  onTapEra: (era) => _openGenre(genre, era: era),
                ),
              );
            },
          ),
        );
      case _MainTab.anime:
        // Trigger the single bulk fetch on first build
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_allTopAnime.isEmpty && !_animeLoading) _fetchAllTopAnime();
        });
        return ListWheelScrollView.useDelegate(
          key: const ValueKey('anime'),
          controller: _genreWheelController,
          itemExtent: MediaQuery.of(context).size.height * 0.35,
          diameterRatio: 100.0,
          perspective: 0.0001,
          squeeze: 1.0,
          physics: const BouncingScrollPhysics(),
          childDelegate: ListWheelChildBuilderDelegate(
            childCount: null,
            builder: (context, index) {
              final eraIndex = index % _Era.all.length;
              final era = _Era.all[eraIndex];
              final loading = _animeLoading && _allTopAnime.isEmpty;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _AnimeEraSection(
                  key: ValueKey('anime_era_${era.label}_$_progressRefreshKey'),
                  era: era,
                  allAnime: _allTopAnime,
                  isLoading: loading,
                  onTapExplore: () => _openAnimeEra(era),
                  onTapEra: (e) => _openAnimeEra(e),
                ),
              );
            },
          ),
        );
      case _MainTab.songs:
      case _MainTab.indieGames:
        return _ComingSoonPage(
          key: ValueKey(_selectedTab.label),
          tab: _selectedTab,
        );
    }
  }

  void _openGenre(_MergedGenre genre, {_Era? era}) async {
    await Navigator.push(context, MaterialPageRoute(
      builder: (_) => GenreMovieScreenWidget(
        genreName: genre.label,
        genreIds: genre.genreIds,
        eraLabel: era?.label,
        eraStart: era?.start,
        eraEnd: era?.end,
      ),
    ));
    // User returned — refresh progress on era cards
    if (mounted) {
      setState(() => _progressRefreshKey++);
    }
  }

  // ── Anime (Jikan API) ──

  void _openAnimeEra(_Era era) async {
    await Navigator.push(context, MaterialPageRoute(
      builder: (_) => AnimeBrowseScreen(
        genreName: 'Anime',
        eraLabel: era.label,
        eraStart: era.start,
        eraEnd: era.end,
      ),
    ));
    if (mounted) {
      setState(() => _progressRefreshKey++);
    }
  }
}

// ════════════════════════════════════════════════════════════════
// Category Card — swipeable card for Movie / Anime / Song
// ════════════════════════════════════════════════════════════════

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({required this.tab, required this.isSelected, required this.onTap});
  final _MainTab tab;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: tab.colors),
          borderRadius: BorderRadius.circular(18),
          border: isSelected
              ? Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1.5)
              : Border.all(color: Colors.white.withValues(alpha: 0.06), width: 1),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: tab.colors.first.withValues(alpha: 0.5),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                    spreadRadius: 2,
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(tab.emoji, style: TextStyle(fontSize: isSelected ? 30 : 22)),
            const SizedBox(height: 8),
            Text(
              tab.label,
              style: TextStyle(
                color: Colors.white,
                fontSize: isSelected ? 14 : 12,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
            if (isSelected) ...[
              const SizedBox(height: 4),
              Container(
                height: 3,
                width: 24,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
            // ── Placeholder content area — add your specifics here ──
            const Spacer(),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// Coming Soon Page — placeholder for Anime / Song tabs
// ════════════════════════════════════════════════════════════════

class _ComingSoonPage extends StatelessWidget {
  const _ComingSoonPage({super.key, required this.tab});
  final _MainTab tab;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: tab.colors),
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: tab.colors.first.withValues(alpha: 0.3),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Text(tab.emoji, style: const TextStyle(fontSize: 52)),
          ),
          const SizedBox(height: 20),
          Text(
            '${tab.label} is coming soon!',
            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            'Swipe to Movies to start exploring',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 13),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// Genre Section — one row per genre with horizontal era carousel
// ════════════════════════════════════════════════════════════════

class _GenreSection extends StatefulWidget {
  const _GenreSection({
    super.key,
    required this.genre,
    required this.movies,
    required this.isLoading,
    required this.onTapExplore,
    required this.onTapEra,
  });
  final _MergedGenre genre;
  final List<Movie> movies;
  final bool isLoading;
  final VoidCallback onTapExplore;
  final void Function(_Era era) onTapEra;

  @override
  State<_GenreSection> createState() => _GenreSectionState();
}

class _GenreSectionState extends State<_GenreSection> {
  /// completion fraction per era label (0.0 → 1.0)
  final Map<String, double> _eraFractions = {};
  bool _fractionsLoaded = false;
  late final PageController _pageController;
  static const int _middle = 50000;

  @override
  void initState() {
    super.initState();
    _loadFractions();
    _pageController = PageController(initialPage: _middle, viewportFraction: 0.85);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _GenreSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.movies.length != widget.movies.length && !_fractionsLoaded) {
      _loadFractions();
    }
  }

  Future<void> _loadFractions() async {
    try {
      for (final era in _Era.all) {
        final f = await SwipeHistory.loadGenreEraFraction(
          genreName: widget.genre.label,
          eraLabel: era.label,
        );
        if (f != null && f > 0) _eraFractions[era.label] = f;
      }
    } catch (_) {
      // Ignore — show cards with no progress if loading fails
    }
    if (mounted) setState(() => _fractionsLoaded = true);
  }

  List<Movie> _moviesForEra(_Era era) {
    return widget.movies.where((m) {
      if (m.year.isEmpty) return false;
      final y = int.tryParse(m.year) ?? 0;
      return y >= era.start && y <= era.end;
    }).toList();
  }

  Movie? _topMovieForEra(_Era era) {
    final list = _moviesForEra(era);
    return list.isEmpty ? null : list.first;
  }

  @override
  Widget build(BuildContext context) {
    final style = widget.genre.style;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Genre header row ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Text(style.emoji, style: const TextStyle(fontSize: 22)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(widget.genre.label, style: const TextStyle(
                    color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700,
                  )),
                ),
                GestureDetector(
                  onTap: widget.onTapExplore,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: style.colors),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Explore All', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                        SizedBox(width: 4),
                        Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 15),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // ── Content: infinite era carousel ──
          Expanded(
            child: widget.isLoading
                ? const Center(child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white24))
                : PageView.builder(
                    controller: _pageController,
                    padEnds: true,
                    itemCount: null,
                    itemBuilder: (context, index) {
                      final era = _Era.all[index % _Era.all.length];
                      final movie = _topMovieForEra(era);
                      final count = _moviesForEra(era).length;
                      final fraction = _eraFractions[era.label] ?? 0.0;

                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: _EraCard(
                          genre: widget.genre,
                          era: era,
                          movie: movie,
                          movieCount: count,
                          completionFraction: fraction,
                          onTap: () => widget.onTapEra(era),
                        ),
                      );
                    },
              ),
            ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// Era Card — shows top movie for genre + era with water-rise effect
// ════════════════════════════════════════════════════════════════

class _EraCard extends StatefulWidget {
  const _EraCard({
    required this.genre,
    required this.era,
    required this.movie,
    required this.movieCount,
    required this.onTap,
    this.completionFraction = 0.0,
    this.fullWidth = false,
    this.sections = const [],
  });

  final _MergedGenre genre;
  final _Era era;
  final Movie? movie;
  final int movieCount;
  final VoidCallback onTap;
  final double completionFraction;
  final bool fullWidth;
  final List<Widget> sections;

  @override
  State<_EraCard> createState() => _EraCardState();
}

class _EraCardState extends State<_EraCard> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOutCubic,
    );
    // Animate to the current completion fraction on appear
    _controller.forward();
  }

  @override
  void didUpdateWidget(covariant _EraCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.completionFraction != widget.completionFraction) {
      // Re-animate from current to new fraction
      _controller.value = oldWidget.completionFraction;
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final style = widget.genre.style;
    final width = widget.fullWidth
        ? MediaQuery.of(context).size.width - 32
        : MediaQuery.of(context).size.width * 0.90;
    final m = widget.movie;
    final fraction = widget.completionFraction;

    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        width: width,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: style.colors.first.withValues(alpha: 0.4),
              blurRadius: 20,
              offset: const Offset(0, 12),
              spreadRadius: 2,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: AnimatedBuilder(
            animation: _animation,
            builder: (context, _) {
              final animFraction = fraction * _animation.value;
              // When animFraction is 0, water is pushed fully below the card (invisible).
              // When animFraction is 1, water fills the entire card.
              final waterOffset = Offset(0, 1.0 - animFraction);
              return Stack(
                fit: StackFit.expand,
                children: [
                  // ── Background ──
                  if (m != null && m.posterPath.isNotEmpty)
                    Image.network(m.fullPosterUrl, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _gradientBg(style))
                  else
                    _gradientBg(style),

                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          style.colors.first.withValues(alpha: 0.3),
                          style.colors.last.withValues(alpha: 0.9),
                        ],
                        stops: const [0.3, 0.6, 1.0],
                      ),
                    ),
                  ),

                  // ── Water-rise overlay (covers the card partially based on fraction) ──
                  Positioned.fill(
                    child: FractionalTranslation(
                      translation: waterOffset,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              style.colors.first.withValues(alpha: 0.2),
                              style.colors.first.withValues(alpha: 0.5),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  // ── Water surface wave line ──
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: FractionalTranslation(
                      translation: waterOffset,
                      child: Container(
                        height: 2,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.6),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.white.withValues(alpha: 0.4),
                              blurRadius: 10,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // ── Content ──
                  Padding(
                    padding: const EdgeInsets.all(18),
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.4),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(style.emoji, style: const TextStyle(fontSize: 15)),
                                    const SizedBox(width: 5),
                                    Text(widget.era.label, style: const TextStyle(
                                      color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700,
                                    )),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.3),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text('${widget.movieCount} movies',
                                    style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 11, fontWeight: FontWeight.w500)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // ── Additional sections ──
                          if (widget.sections.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            ...widget.sections,
                          ],
                        ],
                      ),
                    ),
                  ),

                  Positioned(top: -20, right: -20, child: CircleAvatar(
                    radius: 50, backgroundColor: Colors.white.withValues(alpha: 0.04),
                  )),

                  Positioned(
                    top: 14, right: 14,
                    child: Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 22),
                    ),
                  ),

                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _gradientBg(_GenreStyle style) => Container(
    decoration: BoxDecoration(gradient: LinearGradient(
      begin: Alignment.topLeft, end: Alignment.bottomRight, colors: style.colors,
    )),
    alignment: Alignment.center,
    child: Text(style.emoji, style: TextStyle(fontSize: 60, color: Colors.white.withValues(alpha: 0.08))),
  );
}

// ════════════════════════════════════════════════════════════════
// Anime Era Section — mirrors _GenreSection but for anime by decade
// ════════════════════════════════════════════════════════════════

class _AnimeEraSection extends StatefulWidget {
  const _AnimeEraSection({
    super.key,
    required this.era,
    required this.allAnime,
    required this.isLoading,
    required this.onTapExplore,
    required this.onTapEra,
  });
  final _Era era;
  final List<Anime> allAnime;
  final bool isLoading;
  final VoidCallback onTapExplore;
  final void Function(_Era era) onTapEra;

  @override
  State<_AnimeEraSection> createState() => _AnimeEraSectionState();
}

class _AnimeEraSectionState extends State<_AnimeEraSection> {
  final Map<String, double> _eraFractions = {};
  bool _fractionsLoaded = false;
  late final PageController _pageController;
  static const int _middle = 50000;

  @override
  void initState() {
    super.initState();
    _loadFractions();
    _pageController = PageController(initialPage: _middle, viewportFraction: 0.85);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _AnimeEraSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.allAnime.length != widget.allAnime.length && !_fractionsLoaded) {
      _loadFractions();
    }
  }

  Future<void> _loadFractions() async {
    try {
      for (final era in _Era.all) {
        final f = await SwipeHistory.loadGenreEraFraction(
          genreName: 'Anime',
          eraLabel: era.label,
        );
        if (f != null && f > 0) _eraFractions[era.label] = f;
      }
    } catch (_) {}
    if (mounted) setState(() => _fractionsLoaded = true);
  }

  /// Filter the full list to anime within a specific era.
  List<Anime> _animeForEra(_Era era) {
    return widget.allAnime.where((a) {
      if (a.year <= 0) return false;
      return a.year >= era.start && a.year <= era.end;
    }).toList();
  }

  Anime? _topAnimeForEra(_Era era) {
    final list = _animeForEra(era);
    return list.isEmpty ? null : list.first;
  }

  @override
  Widget build(BuildContext context) {
    final style = _animeStyle;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Anime header row ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Text(style.emoji, style: const TextStyle(fontSize: 22)),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text('Anime', style: TextStyle(
                    color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700,
                  )),
                ),
                GestureDetector(
                  onTap: widget.onTapExplore,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: style.colors),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Explore All', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                        SizedBox(width: 4),
                        Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 15),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // ── Content: infinite era carousel ──
          Expanded(
            child: widget.isLoading
                ? const Center(child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white24))
                : PageView.builder(
                    controller: _pageController,
                    padEnds: true,
                    itemCount: null,
                    itemBuilder: (context, index) {
                      final era = _Era.all[index % _Era.all.length];
                      final anime = _topAnimeForEra(era);
                      final count = _animeForEra(era).length;
                      final fraction = _eraFractions[era.label] ?? 0.0;

                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: _AnimeEraCard(
                          era: era,
                          anime: anime,
                          animeCount: count,
                          completionFraction: fraction,
                          onTap: () => widget.onTapEra(era),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// Anime Era Card — shows top anime image for that era
// ════════════════════════════════════════════════════════════════

class _AnimeEraCard extends StatefulWidget {
  const _AnimeEraCard({
    required this.era,
    required this.anime,
    required this.animeCount,
    required this.onTap,
    this.completionFraction = 0.0,
  });

  final _Era era;
  final Anime? anime;
  final int animeCount;
  final VoidCallback onTap;
  final double completionFraction;

  @override
  State<_AnimeEraCard> createState() => _AnimeEraCardState();
}

class _AnimeEraCardState extends State<_AnimeEraCard> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeInOutCubic);
    _controller.forward();
  }

  @override
  void didUpdateWidget(covariant _AnimeEraCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.completionFraction != widget.completionFraction) {
      _controller.value = oldWidget.completionFraction;
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final style = _animeStyle;
    final width = MediaQuery.of(context).size.width * 0.90;
    final a = widget.anime;
    final fraction = widget.completionFraction;

    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        width: width,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: style.colors.first.withValues(alpha: 0.4),
              blurRadius: 20,
              offset: const Offset(0, 12),
              spreadRadius: 2,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: AnimatedBuilder(
            animation: _animation,
            builder: (context, _) {
              final animFraction = fraction * _animation.value;
              final waterOffset = Offset(0, 1.0 - animFraction);
              return Stack(
                fit: StackFit.expand,
                children: [
                  // ── Background: anime image ──
                  if (a != null && a.imageUrl.isNotEmpty)
                    CachedNetworkImage(
                      imageUrl: a.imageUrl,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => _gradientBg(style),
                      errorWidget: (_, __, ___) => _gradientBg(style),
                    )
                  else
                    _gradientBg(style),

                  // ── Gradient overlay ──
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          style.colors.first.withValues(alpha: 0.3),
                          style.colors.last.withValues(alpha: 0.9),
                        ],
                        stops: const [0.3, 0.6, 1.0],
                      ),
                    ),
                  ),

                  // ── Water-rise overlay ──
                  Positioned.fill(
                    child: FractionalTranslation(
                      translation: waterOffset,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              style.colors.first.withValues(alpha: 0.2),
                              style.colors.first.withValues(alpha: 0.5),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  // ── Water surface wave line ──
                  Positioned(
                    left: 0, right: 0, bottom: 0,
                    child: FractionalTranslation(
                      translation: waterOffset,
                      child: Container(
                        height: 2,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.6),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.white.withValues(alpha: 0.4),
                              blurRadius: 10,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // ── Content ──
                  Padding(
                    padding: const EdgeInsets.all(18),
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.4),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(style.emoji, style: const TextStyle(fontSize: 15)),
                                    const SizedBox(width: 5),
                                    Text(widget.era.label, style: const TextStyle(
                                      color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700,
                                    )),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.3),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text('${widget.animeCount} anime',
                                    style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 11, fontWeight: FontWeight.w500)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // ── Top anime title ──
                          if (a != null) ...[
                            Text(
                              '#1 ${a.displayTitle}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(Icons.star_rounded, color: Colors.amber, size: 14),
                                const SizedBox(width: 3),
                                Text(a.scoreText,
                                    style: const TextStyle(color: Colors.amber, fontSize: 13, fontWeight: FontWeight.w600)),
                                if (a.yearString.isNotEmpty) ...[
                                  const SizedBox(width: 8),
                                  Text(a.yearString,
                                      style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12)),
                                ],
                                if (a.episodes > 0) ...[
                                  const SizedBox(width: 8),
                                  Text('${a.episodes} eps',
                                      style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 11)),
                                ],
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),

                  // ── Decorative circle ──
                  Positioned(top: -20, right: -20, child: CircleAvatar(
                    radius: 50, backgroundColor: Colors.white.withValues(alpha: 0.04),
                  )),

                  // ── Play icon ──
                  Positioned(
                    top: 14, right: 14,
                    child: Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 22),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _gradientBg(_GenreStyle style) => Container(
    decoration: BoxDecoration(gradient: LinearGradient(
      begin: Alignment.topLeft, end: Alignment.bottomRight, colors: style.colors,
    )),
    alignment: Alignment.center,
    child: Text(style.emoji, style: TextStyle(fontSize: 60, color: Colors.white.withValues(alpha: 0.08))),
  );
}

// ════════════════════════════════════════════════════════════════
// Data classes
// ════════════════════════════════════════════════════════════════

class _MergedGenre {
  final String label;
  final List<int> genreIds;
  final _GenreStyle style;
  final List<String> subLabels;
  _MergedGenre({required this.label, required this.genreIds, required this.style})
      : subLabels = label.split(' & ');
}

class _GenreStyle {
  final String emoji;
  final List<Color> colors;
  const _GenreStyle({required this.emoji, required this.colors});
}
