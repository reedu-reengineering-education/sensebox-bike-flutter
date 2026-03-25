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
    return Scaffold(
      body: navigationShell,
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
    );
  }
}
