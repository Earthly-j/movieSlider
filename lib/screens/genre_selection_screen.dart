import 'package:flutter/material.dart';
import '../models/movie.dart';
import '../services/tmdb_service.dart';
import 'genre_movie_screen.dart';

/// Main categories for the top-level navigation.
enum _MainTab {
  movies('Movies', '🎬', [Color(0xFF6366F1), Color(0xFF818CF8)],
      'Discover top-rated movies across every genre and era'),
  anime('Anime', '👺', [Color(0xFFEC4899), Color(0xFFF472B6)],
      'Explore the best anime series and films'),
  songs('Songs', '🎵', [Color(0xFFF59E0B), Color(0xFFFBBF24)],
      'Find trending songs and soundtracks');

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
  _MainTab _selectedTab = _MainTab.movies;

  // Controllers
  late final PageController _categoryController;
  late final PageController _verticalPageController;
  static const int _vMiddle = 50000;
  static const int _catMiddle = 50000;

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
    _categoryController = PageController(initialPage: _catMiddle, viewportFraction: 0.82);
    _verticalPageController = PageController(initialPage: _vMiddle, viewportFraction: 0.88);
    _loadGenres();
  }

  @override
  void dispose() {
    _categoryController.dispose();
    _verticalPageController.dispose();
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
            child: Text('What are you in the mood for?',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 14)),
          ),
        ),

        // ─── Category Carousel (Movie / Anime / Song) ───
        SizedBox(
          height: 130,
          child: PageView.builder(
            controller: _categoryController,
            itemCount: null, // infinite — wraps via modulo
            onPageChanged: (page) {
              final tabIndex = page % _MainTab.values.length;
              if (_selectedTab != _MainTab.values[tabIndex]) {
                setState(() => _selectedTab = _MainTab.values[tabIndex]);
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
                },
              );
            },
          ),
        ),

        // ─── Tab indicator dots ───
        Padding(
          padding: const EdgeInsets.only(top: 10, bottom: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: _MainTab.values.map((tab) {
              final isActive = _selectedTab == tab;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: isActive ? 24 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: isActive ? tab.colors.first : Colors.white24,
                  borderRadius: BorderRadius.circular(4),
                ),
              );
            }).toList(),
          ),
        ),

        const SizedBox(height: 8),

        // ─── Content below synced to selected tab ───
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: _selectedTab == _MainTab.movies
                ? PageView.builder(
                    key: const ValueKey('movies'),
                    controller: _verticalPageController,
                    scrollDirection: Axis.vertical,
                    itemCount: null,
                    itemBuilder: (context, index) {
                      final genreIndex = index % _mergedGenres.length;
                      final genre = _mergedGenres[genreIndex];
                      return _GenreSection(
                        key: ValueKey('genre_$genreIndex'),
                        genre: genre,
                        onTapExplore: () => _openGenre(genre),
                        onTapEra: (era) => _openGenre(genre, era: era),
                      );
                    },
                  )
                : _ComingSoonPage(
                    key: ValueKey(_selectedTab.label),
                    tab: _selectedTab,
                  ),
          ),
        ),
      ],
    );
  }

  void _openGenre(_MergedGenre genre, {_Era? era}) {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => GenreMovieScreenWidget(
        genreName: genre.label,
        genreIds: genre.genreIds,
        eraLabel: era?.label,
        eraStart: era?.start,
        eraEnd: era?.end,
      ),
    ));
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
        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: tab.colors),
          borderRadius: BorderRadius.circular(22),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: tab.colors.first.withValues(alpha: 0.4),
                    blurRadius: 20,
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
          border: isSelected
              ? null
              : Border.all(color: Colors.white.withValues(alpha: 0.08), width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                Text(tab.emoji, style: TextStyle(fontSize: isSelected ? 36 : 28)),
                const SizedBox(width: 14),
                Text(
                  tab.label,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: isSelected ? 24 : 18,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
                if (isSelected) ...[
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check_rounded, color: Colors.white, size: 16),
                  ),
                ],
              ],
            ),
            if (isSelected) ...[
              const SizedBox(height: 6),
              Text(
                tab.subtitle,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
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
    required this.onTapExplore,
    required this.onTapEra,
  });
  final _MergedGenre genre;
  final VoidCallback onTapExplore;
  final void Function(_Era era) onTapEra;

  @override
  State<_GenreSection> createState() => _GenreSectionState();
}

class _GenreSectionState extends State<_GenreSection> {
  final TmdbService _tmdbService = TmdbService();
  List<Movie> _allMovies = [];
  bool _isLoading = false;
  late final PageController _pageController;

  static const int _middle = 50000;

  @override
  void initState() {
    super.initState();
    _fetchMovies();
    _pageController = PageController(initialPage: _middle, viewportFraction: 0.85);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _fetchMovies() async {
    if (mounted) setState(() => _isLoading = true);
    try {
      final movies = await _tmdbService.fetchMoviesByGenre(
        widget.genre.genreIds,
      );
      if (mounted) {
        setState(() {
          _allMovies = movies;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<Movie> _moviesForEra(_Era era) {
    return _allMovies.where((m) {
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
      padding: const EdgeInsets.only(bottom: 28),
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
          const SizedBox(height: 14),

          // ── Content: infinite era carousel ──
          if (_isLoading)
            const SizedBox(
              height: 220,
              child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white24)),
            )
          else
            SizedBox(
              height: 220,
              child: PageView.builder(
                controller: _pageController,
                padEnds: true,
                itemCount: null,
                itemBuilder: (context, index) {
                  final era = _Era.all[index % _Era.all.length];
                  final movie = _topMovieForEra(era);
                  final count = _moviesForEra(era).length;

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: _EraCard(
                      genre: widget.genre,
                      era: era,
                      movie: movie,
                      movieCount: count,
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
// Era Card — shows top movie for genre + era
// ════════════════════════════════════════════════════════════════

class _EraCard extends StatelessWidget {
  const _EraCard({
    required this.genre,
    required this.era,
    required this.movie,
    required this.movieCount,
    required this.onTap,
    this.fullWidth = false,
  });

  final _MergedGenre genre;
  final _Era era;
  final Movie? movie;
  final int movieCount;
  final VoidCallback onTap;
  final bool fullWidth;

  @override
  Widget build(BuildContext context) {
    final style = genre.style;
    final width = fullWidth
        ? MediaQuery.of(context).size.width - 32
        : MediaQuery.of(context).size.width * 0.90;
    final m = movie;

    return GestureDetector(
      onTap: onTap,
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
          child: Stack(
            fit: StackFit.expand,
            children: [
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

              Padding(
                padding: const EdgeInsets.all(18),
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
                              Text(era.label, style: const TextStyle(
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
                          child: Text('$movieCount movies',
                              style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 11, fontWeight: FontWeight.w500)),
                        ),
                      ],
                    ),

                    const Spacer(),

                    if (m != null) ...[
                      Text(
                        m.title,
                        style: const TextStyle(
                          color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800, height: 1.2,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.star_rounded, color: Colors.amber, size: 15),
                          const SizedBox(width: 3),
                          Text(m.ratingText, style: const TextStyle(
                            color: Colors.amber, fontSize: 13, fontWeight: FontWeight.w700,
                          )),
                          const SizedBox(width: 10),
                          Text(m.year, style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7), fontSize: 13, fontWeight: FontWeight.w500,
                          )),
                        ],
                      ),
                    ] else ...[
                      const Text('No movies yet', style: TextStyle(
                        color: Colors.white54, fontSize: 15, fontWeight: FontWeight.w600,
                      )),
                    ],
                  ],
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
