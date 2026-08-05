import 'package:flutter/material.dart';
import 'package:sensebox_bike/ui/screens/home_screen.dart';
import 'package:sensebox_bike/ui/screens/settings_screen.dart';
import 'package:sensebox_bike/ui/screens/tracks_screen.dart';
import 'package:sensebox_bike/l10n/app_localizations.dart';

class AppHome extends StatefulWidget {
  const AppHome({super.key});

  @override
  _AppHomeState createState() => _AppHomeState();
}

class _AppHomeState extends State<AppHome> {
  static const int _tabCount = 3;

  int _selectedIndex = 0;
  late final PageController _pageController;

  final GlobalKey<TracksScreenState> _tracksScreenKey =
      GlobalKey<TracksScreenState>();

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onDestinationSelected(int index) {
    if (index < 0 || index >= _tabCount) return;

    // Re-tapping Tracks refreshes once without animating.
    if (index == _selectedIndex) {
      if (index == 1) {
        _tracksScreenKey.currentState?.refreshTracks();
      }
      return;
    }

    setState(() => _selectedIndex = index);
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
    );
    // Tracks refresh happens in _onPageChanged when the page settles.
  }

  void _onPageChanged(int index) {
    setState(() => _selectedIndex = index);
    if (index == 1) {
      _tracksScreenKey.currentState?.refreshTracks();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      // No KeepAlive: keeping the Mapbox platform view alive inside a
      // PageView steals gestures on every tab. Home rebuilds when you return.
      body: PageView(
        controller: _pageController,
        onPageChanged: _onPageChanged,
        children: [
          const HomeScreen(),
          TracksScreen(key: _tracksScreenKey),
          const SettingsScreen(),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          borderRadius: BorderRadius.only(
              topRight: Radius.circular(24), topLeft: Radius.circular(24)),
          boxShadow: [
            BoxShadow(color: Colors.black38, spreadRadius: 0, blurRadius: 12),
          ],
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
          child: NavigationBar(
            onDestinationSelected: _onDestinationSelected,
            selectedIndex: _selectedIndex,
            destinations: [
              NavigationDestination(
                icon: const Icon(Icons.map),
                label: l10n.homeBottomBarHome,
              ),
              NavigationDestination(
                icon: const Icon(Icons.route),
                label: l10n.homeBottomBarTracks,
              ),
              NavigationDestination(
                icon: const Icon(Icons.settings),
                label: l10n.generalSettings,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
