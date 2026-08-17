import 'package:flutter/material.dart';
import 'package:sensebox_bike/l10n/app_localizations.dart';
import 'package:sensebox_bike/ui/screens/home_screen.dart';
import 'package:sensebox_bike/ui/screens/login_screen.dart';
import 'package:sensebox_bike/ui/screens/settings_screen.dart';
import 'package:sensebox_bike/ui/screens/tracks_screen.dart';
import 'package:sensebox_bike/ui/widgets/common/changelog_modal.dart';

/// Global Y (logical pixels, screen coordinates) of the floating pill nav
/// bar's top edge, updated after every layout pass. Null until first
/// measured. Full-bleed map layouts (tablet landscape) read this to keep map
/// ornaments clear of the bar without hardcoding its height/position.
final ValueNotifier<double?> bottomNavBarTopNotifier = ValueNotifier<double?>(null);

class AppHome extends StatefulWidget {
  const AppHome({super.key});

  @override
  State<AppHome> createState() => _AppHomeState();
}

class _AppHomeState extends State<AppHome> {
  int _selectedIndex = 0;

  final GlobalKey<TracksScreenState> _tracksScreenKey =
      GlobalKey<TracksScreenState>();
  final GlobalKey _navBarKey = GlobalKey();

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      const HomeScreen(),
      TracksScreen(key: _tracksScreenKey),
      const SettingsScreen(),
      const LoginScreen(),
    ];
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      maybeShowChangelogModal(context);
    });
  }

  @override
  void dispose() {
    bottomNavBarTopNotifier.value = null;
    super.dispose();
  }

  void _publishNavBarTop(Duration _) {
    final box = _navBarKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.attached) return;
    bottomNavBarTopNotifier.value = box.localToGlobal(Offset.zero).dy;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    WidgetsBinding.instance.addPostFrameCallback(_publishNavBarTop);

    return Scaffold(
      extendBody: true,
      body: IndexedStack(
        index: _selectedIndex,
        children: _pages,
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 32, 16, 0),
        child: Container(
          key: _navBarKey,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(36),
            border: isDark ? Border.all(color: Colors.white12, width: 1) : null,
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? Colors.black.withValues(alpha: 0.34)
                    : Colors.black26,
                blurRadius: isDark ? 22 : 32,
                spreadRadius: isDark ? -2 : 0,
                offset: const Offset(0, 8),
              ),
              if (isDark)
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 42,
                  spreadRadius: -12,
                  offset: const Offset(0, 14),
                ),
              if (isDark)
                BoxShadow(
                  color: Colors.white.withValues(alpha: 0.04),
                  blurRadius: 2,
                  spreadRadius: -1,
                  offset: const Offset(0, 1),
                ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(36),
            child: NavigationBarTheme(
              data: NavigationBarThemeData(
                height: 72,
                backgroundColor: Theme.of(context).colorScheme.surface,
                elevation: 0,
              ),
              child: NavigationBar(
                onDestinationSelected: (value) {
                  setState(() {
                    _selectedIndex = value;
                    // Refresh tracks when navigating to tracks tab
                    if (value == 1) {
                      _tracksScreenKey.currentState?.refreshTracks();
                    }
                  });
                },
                selectedIndex: _selectedIndex,
                destinations: [
                  NavigationDestination(
                      icon: Icon(Icons.map),
                      label: AppLocalizations.of(context)!.homeBottomBarHome),
                  NavigationDestination(
                      icon: Icon(Icons.route),
                      label: AppLocalizations.of(context)!.homeBottomBarTracks),
                  NavigationDestination(
                      icon: Icon(Icons.settings),
                      label: AppLocalizations.of(context)!.generalSettings),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
