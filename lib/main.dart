import 'package:flutter/material.dart';
import 'screens/genre_selection_screen.dart';

void main() {
  runApp(const TmdbSliderApp());
}

class TmdbSliderApp extends StatelessWidget {
  const TmdbSliderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "Movie Swiper",
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF1DB954),
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      home: const MainShell(),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// Main Shell — Bottom Navigation with 4 tabs
// ════════════════════════════════════════════════════════════════

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  final List<_NavTab> _tabs = const [
    _NavTab(icon: Icons.movie_filter_rounded, label: 'Watched'),
    _NavTab(icon: Icons.upcoming_rounded, label: 'Upcoming'),
    _NavTab(icon: Icons.people_rounded, label: 'Friends'),
    _NavTab(icon: Icons.tune_rounded, label: 'Customize'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: _buildBody(),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF111111),
          border: Border(
            top: BorderSide(
              color: Colors.white.withValues(alpha: 0.06),
              width: 1,
            ),
          ),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              children: List.generate(_tabs.length, (i) {
                final tab = _tabs[i];
                final isActive = _currentIndex == i;
                return Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => setState(() => _currentIndex = i),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Active indicator dot
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            width: isActive ? 18 : 0,
                            height: 3,
                            margin: const EdgeInsets.only(bottom: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1DB954),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          // Icon
                          Icon(
                            tab.icon,
                            size: 22,
                            color: isActive
                                ? const Color(0xFF1DB954)
                                : Colors.white.withValues(alpha: 0.35),
                          ),
                          const SizedBox(height: 4),
                          // Label
                          AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 250),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                              color: isActive
                                  ? const Color(0xFF1DB954)
                                  : Colors.white.withValues(alpha: 0.35),
                            ),
                            child: Text(tab.label),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    switch (_currentIndex) {
      case 0:
        return const GenreSelectionScreen();
      case 1:
        return const _PlaceholderPage(
          icon: Icons.upcoming_rounded,
          title: 'Upcoming',
          subtitle: 'Track upcoming releases and premieres',
        );
      case 2:
        return const _PlaceholderPage(
          icon: Icons.people_rounded,
          title: 'Friends',
          subtitle: 'See what your friends are watching',
        );
      case 3:
        return const _PlaceholderPage(
          icon: Icons.tune_rounded,
          title: 'Customization',
          subtitle: 'Personalize your experience',
        );
      default:
        return const GenreSelectionScreen();
    }
  }
}

// ════════════════════════════════════════════════════════════════
// Nav tab data
// ════════════════════════════════════════════════════════════════

class _NavTab {
  final IconData icon;
  final String label;
  const _NavTab({required this.icon, required this.label});
}

// ════════════════════════════════════════════════════════════════
// Placeholder page for tabs not yet built
// ════════════════════════════════════════════════════════════════

class _PlaceholderPage extends StatelessWidget {
  const _PlaceholderPage({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF1DB954).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(28),
            ),
            child: Icon(icon, size: 48, color: const Color(0xFF1DB954)),
          ),
          const SizedBox(height: 20),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.4),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
