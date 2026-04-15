import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/movie.dart';

class SwipeCard extends StatelessWidget {
  final Movie movie;

  const SwipeCard({super.key, required this.movie});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Backdrop or poster as background
          movie.backdropPath.isNotEmpty
              ? CachedNetworkImage(
                  imageUrl: movie.fullBackdropUrl,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    color: theme.colorScheme.surface,
                    child: const Center(
                      child: CircularProgressIndicator(),
                    ),
                  ),
                  errorWidget: (context, url, error) => _buildFallback(theme),
                )
              : movie.posterPath.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: movie.fullPosterUrl,
                      fit: BoxFit.cover,
                      errorWidget: (context, url, error) =>
                          _buildFallback(theme),
                    )
                  : _buildFallback(theme),

          // Dark gradient overlay for text readability
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(24, 40, 24, 28),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.5),
                    Colors.black.withValues(alpha: 0.85),
                  ],
                  stops: const [0.0, 0.4, 1.0],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Rating badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.star_rounded,
                          color: Colors.black87,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          movie.ratingText,
                          style: const TextStyle(
                            color: Colors.black87,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '(${movie.voteCount})',
                          style: TextStyle(
                            color: Colors.black54,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Title
                  Text(
                    movie.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      shadows: [
                        Shadow(
                          blurRadius: 8,
                          color: Colors.black,
                        ),
                      ],
                    ),
                  ),

                  // Year
                  if (movie.year.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      movie.year,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 14,
                      ),
                    ),
                  ],

                  // Overview
                  if (movie.overview.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      movie.overview,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFallback(ThemeData theme) {
    return Container(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Icon(
        Icons.movie_outlined,
        size: 80,
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}
