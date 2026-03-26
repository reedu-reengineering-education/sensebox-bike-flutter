import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sensebox_bike/l10n/app_localizations.dart';

class AppHome extends StatelessWidget {
  const AppHome({
    required this.navigationShell,
    super.key,
  });

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      extendBody: true,
      body: navigationShell,
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 32, 16, 0),
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(36),
            border: isDark ? Border.all(color: Colors.white12, width: 1) : null,
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? const Color.fromARGB(255, 0, 0, 0)
                    : Colors.black26,
                blurRadius: 32,
                offset: Offset(0, 8),
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
                onDestinationSelected: (index) {
                  navigationShell.goBranch(
                    index,
                    initialLocation: index == navigationShell.currentIndex,
                  );
                },
                selectedIndex: navigationShell.currentIndex,
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
