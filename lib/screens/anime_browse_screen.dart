import 'dart:math' as math;
import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_card_swiper/flutter_card_swiper.dart';
import '../services/jikan_service.dart';
import '../services/swipe_history.dart';

/// Anime browse screen — swipe through top anime sorted by score.
/// Mirrors GenreMovieScreenWidget but uses Jikan API instead of TMDB.
class AnimeBrowseScreen extends StatefulWidget {
  final String genreName;
  final int? genreId;
  final String? eraLabel;
  final int? eraStart;
  final int? eraEnd;
  final bool isCurrentlyAiring;

  const AnimeBrowseScreen({
    super.key,
    required this.genreName,
    this.genreId,
    this.eraLabel,
    this.eraStart,
    this.eraEnd,
    this.isCurrentlyAiring = false,
  });

  @override
  State<AnimeBrowseScreen> createState() => _AnimeBrowseScreenState();
}

class _AnimeBrowseScreenState extends State<AnimeBrowseScreen> {
  final JikanService _jikanService = JikanService();
  final CardSwiperController _swiperController = CardSwiperController();

  int _swiperKey = 0;
  int _swipedCount = 0;

  List<Anime> _animeList = [];
  int _totalAnime = 0;
  final List<Anime> _watched = [];
  final List<Anime> _skipped = [];
  Set<int> _watchedIds = {};
  Set<int> _skippedIds = {};
  bool _isLoading = true;
  String? _errorMessage;

  bool _isLoadingMore = false;
  StreamSubscription? _genreLoadSub;

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
      _watchedIds = {};
      _skippedIds = {};
    }
    if (!mounted) return;
    await _loadAnime();
  }

  @override
  void dispose() {
    _genreLoadSub?.cancel();
    _swiperController.dispose();
    super.dispose();
  }

  /// Apply filtering + history separation and update state.
  /// If [onlyIfIdle] is true, skip the update if the user has already started swiping.
  void _applyFilterAndSetState(List<Anime> allAnime, {bool onlyIfIdle = false}) {
    if (!mounted) return;
    if (onlyIfIdle && _swipedCount > 0) return;
    final watched = allAnime.where((a) => _watchedIds.contains(a.malId)).toList();
    final skipped = allAnime.where((a) => _skippedIds.contains(a.malId)).toList();
    setState(() {
      _animeList = allAnime
          .where((a) => !_watchedIds.contains(a.malId) && !_skippedIds.contains(a.malId))
          .toList();
      _watched.clear();
      _watched.addAll(watched);
      _skipped.clear();
      _skipped.addAll(skipped);
      _totalAnime = allAnime.length;
      _isLoading = false;
    });
    SwipeHistory.saveGenreEraProgress(
      genreName: widget.genreName,
      eraLabel: widget.eraLabel ?? 'All',
      total: allAnime.length,
      watched: _watched.length,
      skipped: _skipped.length,
    );
  }

  Future<void> _loadAnime() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _isLoadingMore = false;
    });
    try {
      if (widget.genreId != null) {
        // Progressive loading — show cards as each page arrives
        _genreLoadSub?.cancel();
        _genreLoadSub = _jikanService.fetchAnimeByGenre(widget.genreId!).listen(
          (allAnime) {
            // Filter by era if provided
            var filtered = allAnime;
            if (widget.eraStart != null || widget.eraEnd != null) {
              filtered = allAnime.where((a) {
                if (a.year <= 0) return false;
                if (widget.eraStart != null && a.year < widget.eraStart!) return false;
                if (widget.eraEnd != null && widget.eraEnd! < 2100 && a.year > widget.eraEnd!) return false;
                return true;
              }).toList();
            }
            _applyFilterAndSetState(filtered);
          },
          onError: (e) {
            if (!mounted) return;
            setState(() {
              _errorMessage = e.toString();
              _isLoading = false;
            });
          },
          onDone: () {
            setState(() => _isLoadingMore = false);
          },
        );
        setState(() => _isLoadingMore = true);
      } else if (widget.isCurrentlyAiring) {
        final allAnime = await _jikanService.fetchRecommendations();
        if (!mounted) return;
        _applyFilterAndSetState(allAnime);
      } else {
        final allAnime = await _jikanService.fetchTopAnime(pages: 2);
        if (!mounted) return;
        _applyFilterAndSetState(allAnime);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  int get _remaining => _animeList.length - _swipedCount;
  int get _currentIndex => _swipedCount;

  void _showAnimeDetail(Anime anime) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _AnimeDetailSheet(anime: anime),
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
            : widget.genreName),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        actions: [
          _CounterBadge(
            label: 'Watched',
            count: _watched.length,
            color: Colors.green,
            onTap: () => _showHistorySheet(watched: true),
          ),
          _CounterBadge(
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
            Text('Loading anime...', style: TextStyle(color: Colors.white54)),
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
              ElevatedButton(onPressed: _loadAnime, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    if (_animeList.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🎌', style: TextStyle(fontSize: 64)),
            const SizedBox(height: 16),
            Text(
              'No new anime in ${widget.genreName}!',
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
            const Text('🎌', style: TextStyle(fontSize: 64)),
            const SizedBox(height: 16),
            Text(
              'You\'ve gone through all ${widget.genreName} anime!',
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
                        builder: (_) => _AnimeHistoryScreen(watched: _watched, skipped: _skipped),
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
              Text('$_currentIndex of ${_animeList.length}',
                  style: const TextStyle(color: Colors.white54, fontSize: 13)),
              if (_isLoadingMore) ...[
                const SizedBox(width: 10),
                const SizedBox(
                  width: 14, height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white38),
                ),
              ],
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
            padding: const EdgeInsets.only(top: 4, bottom: 4),
            child: CardSwiper(
              key: ValueKey(_swiperKey),
              controller: _swiperController,
              cardsCount: math.max(1, _animeList.length),
              numberOfCardsDisplayed: math.max(1, _animeList.length < 3 ? _animeList.length : 3),
              backCardOffset: const Offset(0, 30),
              padding: const EdgeInsets.symmetric(horizontal: 4),
              onSwipe: _onSwipe,
              onEnd: _onEnd,
              cardBuilder: (context, index, percentThresholdX, percentThresholdY) {
                if (index >= _animeList.length) return Container();
                return _AnimeSwipeCard(anime: _animeList[index]);
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
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
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
                    if (idx < _animeList.length) _showAnimeDetail(_animeList[idx]);
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
        ),
      ],
    );
  }

  bool _onSwipe(int previousIndex, int? currentIndex, CardSwiperDirection direction) {
    if (previousIndex >= _animeList.length) return false;
    final anime = _animeList[previousIndex];
    if (direction == CardSwiperDirection.right) {
      _watched.add(anime);
      SwipeHistory.addWatched(anime.malId);
    } else {
      _skipped.add(anime);
      SwipeHistory.addSkipped(anime.malId);
    }
    setState(() => _swipedCount++);
    if (_totalAnime > 0) {
      SwipeHistory.saveGenreEraProgress(
        genreName: widget.genreName,
        eraLabel: widget.eraLabel ?? 'All',
        total: _totalAnime,
        watched: _watched.length,
        skipped: _skipped.length,
      );
    }
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
      builder: (context) => _AnimeHistorySheet(
        title: watched ? '✅ Watched (${_watched.length})' : '⏭️ Skipped (${_skipped.length})',
        anime: watched ? _watched : _skipped,
        emptyMessage: watched
            ? 'No anime marked as watched yet. Swipe right!'
            : 'No skipped anime yet. Swipe left to skip.',
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// Anime Swipe Card
// ════════════════════════════════════════════════════════════════

class _AnimeSwipeCard extends StatelessWidget {
  final Anime anime;
  const _AnimeSwipeCard({required this.anime});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 6)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Poster
          Expanded(
            flex: 3,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (anime.imageUrl.isNotEmpty)
                  CachedNetworkImage(
                    imageUrl: anime.imageUrl,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(
                      color: const Color(0xFF2A1A2A),
                      child: const Center(child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white24)),
                    ),
                    errorWidget: (_, __, ___) => Container(
                      color: const Color(0xFF2A1A2A),
                      child: const Icon(Icons.movie, color: Colors.white24, size: 48),
                    ),
                  )
                else
                  Container(
                    color: const Color(0xFF2A1A2A),
                    child: const Center(child: Text('🎌', style: TextStyle(fontSize: 48))),
                  ),
                // Gradient overlay at bottom
                Positioned(
                  left: 0, right: 0, bottom: 0,
                  child: Container(
                    height: 120,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.black.withValues(alpha: 0.85)],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Info
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Type badge
                  if (anime.type.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEC4899).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        anime.typeLabel,
                        style: const TextStyle(color: Color(0xFFF472B6), fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                    ),
                  const SizedBox(height: 8),
                  Text(
                    anime.displayTitle,
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  if (anime.genres.isNotEmpty)
                    Text(
                      anime.genres.take(3).join(' • '),
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  const Spacer(),
                  Row(
                    children: [
                      const Icon(Icons.star_rounded, color: Colors.amber, size: 16),
                      const SizedBox(width: 3),
                      Text(anime.scoreText,
                          style: const TextStyle(color: Colors.amber, fontSize: 13, fontWeight: FontWeight.w600)),
                      if (anime.yearString.isNotEmpty) ...[
                        const SizedBox(width: 10),
                        Text(anime.yearString,
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 13)),
                      ],
                      const Spacer(),
                      if (anime.episodes > 0)
                        Text('${anime.episodes} eps',
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 11)),
                    ],
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

// ════════════════════════════════════════════════════════════════
// Supporting Widgets
// ════════════════════════════════════════════════════════════════

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

class _CounterBadge extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final VoidCallback onTap;

  const _CounterBadge({
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
            Text(
              '$count',
              style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// Anime Detail Sheet
// ════════════════════════════════════════════════════════════════

class _AnimeDetailSheet extends StatelessWidget {
  final Anime anime;
  const _AnimeDetailSheet({required this.anime});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
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
              if (anime.imageUrl.isNotEmpty)
                ClipRRect(
                  child: CachedNetworkImage(
                    imageUrl: anime.imageUrl,
                    width: double.infinity, height: 220, fit: BoxFit.cover,
                    placeholder: (_, __) => Container(height: 220, color: const Color(0xFF2A1A2A)),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(anime.displayTitle,
                        style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                    if (anime.titleEnglish.isNotEmpty && anime.title != anime.titleEnglish) ...[
                      const SizedBox(height: 4),
                      Text(anime.title,
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 14)),
                    ],
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 10,
                      runSpacing: 6,
                      children: [
                        if (anime.score > 0)
                          _InfoChip(icon: Icons.star_rounded, text: '${anime.scoreText} (${anime.scoredBy})', color: Colors.amber),
                        if (anime.type.isNotEmpty)
                          _InfoChip(icon: Icons.tv, text: anime.typeLabel, color: const Color(0xFFEC4899)),
                        if (anime.yearString.isNotEmpty)
                          _InfoChip(icon: Icons.calendar_today, text: anime.yearString, color: Colors.blueAccent),
                        if (anime.rating.isNotEmpty)
                          _InfoChip(icon: Icons.label, text: anime.rating, color: Colors.purple),
                        if (anime.status.isNotEmpty)
                          _InfoChip(icon: Icons.info_outline, text: anime.status, color: Colors.green),
                      ],
                    ),
                    if (anime.genres.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: anime.genres.map((g) => Chip(
                          label: Text(g, style: const TextStyle(color: Colors.white, fontSize: 12)),
                          backgroundColor: const Color(0xFFEC4899).withValues(alpha: 0.15),
                          side: BorderSide.none,
                          padding: EdgeInsets.zero,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        )).toList(),
                      ),
                    ],
                    const SizedBox(height: 16),
                    const Text('Synopsis', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text(
                      anime.synopsis.isNotEmpty ? anime.synopsis : 'No synopsis available.',
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

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;

  const _InfoChip({required this.icon, required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 4),
        Text(text, style: TextStyle(color: Colors.white70, fontSize: 13)),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════
// History Sheet & Screen
// ════════════════════════════════════════════════════════════════

class _AnimeHistorySheet extends StatelessWidget {
  final String title;
  final List<Anime> anime;
  final String emptyMessage;

  const _AnimeHistorySheet({
    required this.title,
    required this.anime,
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
            if (anime.isEmpty)
              Padding(
                padding: const EdgeInsets.all(32),
                child: Text(emptyMessage, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white54)),
              )
            else
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: anime.length,
                  itemBuilder: (context, index) {
                    final a = anime[index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: const Color(0xFFEC4899).withValues(alpha: 0.2),
                        child: Text('${index + 1}', style: const TextStyle(color: Color(0xFFF472B6), fontWeight: FontWeight.bold)),
                      ),
                      title: Text(a.displayTitle, style: const TextStyle(color: Colors.white), maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text(
                        '⭐ ${a.scoreText}${a.yearString.isNotEmpty ? ' • ${a.yearString}' : ''}',
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

class _AnimeHistoryScreen extends StatefulWidget {
  final List<Anime> watched;
  final List<Anime> skipped;
  const _AnimeHistoryScreen({required this.watched, required this.skipped});

  @override
  State<_AnimeHistoryScreen> createState() => _AnimeHistoryScreenState();
}

class _AnimeHistoryScreenState extends State<_AnimeHistoryScreen> with SingleTickerProviderStateMixin {
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
          'This will reset all your watched and skipped anime across all genres.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Clear All', style: TextStyle(color: Colors.redAccent))),
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
        leading: IconButton(icon: const Icon(Icons.arrow_back_rounded), onPressed: () => Navigator.pop(context)),
        title: const Text('🎌 My Anime History'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          if (widget.watched.isNotEmpty || widget.skipped.isNotEmpty)
            IconButton(icon: const Icon(Icons.delete_sweep_rounded), onPressed: _clearAll),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFFEC4899),
          indicatorWeight: 2,
          indicatorSize: TabBarIndicatorSize.label,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white54,
          labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          unselectedLabelStyle: const TextStyle(fontSize: 14),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          tabAlignment: TabAlignment.fill,
          tabs: [
            Tab(text: 'Watched (${widget.watched.length})'),
            Tab(text: 'Skipped (${widget.skipped.length})'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildList(widget.watched, 'No anime marked as watched yet.'),
          _buildList(widget.skipped, 'No skipped anime yet.'),
        ],
      ),
    );
  }

  Widget _buildList(List<Anime> anime, String empty) {
    if (anime.isEmpty) return Center(child: Text(empty, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white54)));
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: anime.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) => _AnimeHistoryCard(anime: anime[index], rank: index + 1),
    );
  }
}

class _AnimeHistoryCard extends StatelessWidget {
  final Anime anime;
  final int rank;
  const _AnimeHistoryCard({required this.anime, required this.rank});

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
            width: 36, alignment: Alignment.center,
            child: Text('#$rank', style: const TextStyle(color: Color(0xFFF472B6), fontSize: 14, fontWeight: FontWeight.bold)),
          ),
          ClipRRect(
            borderRadius: const BorderRadius.only(topLeft: Radius.circular(14), bottomLeft: Radius.circular(14)),
            child: anime.imageUrl.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: anime.imageUrl,
                    width: 60, height: 90, fit: BoxFit.cover,
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
                  Text(anime.displayTitle, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.star_rounded, color: Colors.amber, size: 14),
                      const SizedBox(width: 3),
                      Text(anime.scoreText, style: const TextStyle(color: Colors.amber, fontSize: 13)),
                      if (anime.yearString.isNotEmpty) ...[
                        const SizedBox(width: 10),
                        Text(anime.yearString, style: const TextStyle(color: Colors.white54, fontSize: 13)),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    anime.synopsis.isNotEmpty ? anime.synopsis : '',
                    maxLines: 2, overflow: TextOverflow.ellipsis,
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
