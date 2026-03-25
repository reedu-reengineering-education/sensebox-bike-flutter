import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sensebox_bike/services/isar_service.dart';
import 'package:sensebox_bike/services/error_service.dart';
import 'package:sensebox_bike/models/track_data.dart';
import 'package:sensebox_bike/ui/screens/app_home.dart';
import 'package:sensebox_bike/ui/screens/exclusion_zones_screen.dart';
import 'package:sensebox_bike/ui/screens/home_screen.dart';
import 'package:sensebox_bike/ui/screens/initial_screen.dart';
import 'package:sensebox_bike/ui/screens/privacy_policy_screen.dart';
import 'package:sensebox_bike/ui/screens/settings_screen.dart';
import 'package:sensebox_bike/ui/screens/track_detail_screen.dart';
import 'package:sensebox_bike/ui/screens/track_statistics_screen.dart';
import 'package:sensebox_bike/ui/screens/tracks_screen.dart';

abstract final class AppRoutes {
  static const initial = '/';
  static const privacyPolicy = '/privacy-policy';
  static const home = '/home';
  static const tracks = '/tracks';
  static const settings = '/settings';
  static const exclusionZones = '/settings/exclusion-zones';
  static const trackStatistics = '/settings/track-statistics';
  static const trackDetail = '/tracks/detail';
}

class TrackDetailRouteData {
  const TrackDetailRouteData({
    required this.track,
    this.onTrackUploaded,
  });

  final TrackData track;
  final VoidCallback? onTrackUploaded;
}

GoRouter createAppRouter({
  required IsarService isarService,
}) {
  return GoRouter(
    navigatorKey: ErrorService.navigatorKey,
    initialLocation: AppRoutes.initial,
    routes: [
      GoRoute(
        path: AppRoutes.initial,
        builder: (context, state) => const InitialScreen(),
      ),
      GoRoute(
        path: AppRoutes.privacyPolicy,
        builder: (context, state) => const PrivacyPolicyScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return AppHome(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.home,
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.tracks,
                builder: (context, state) => const TracksScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.settings,
                builder: (context, state) => const SettingsScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.exclusionZones,
        builder: (context, state) => const ExclusionZonesScreen(),
      ),
      GoRoute(
        path: AppRoutes.trackStatistics,
        builder: (context, state) =>
            TrackStatisticsScreen(isarService: isarService),
      ),
      GoRoute(
        path: AppRoutes.trackDetail,
        builder: (context, state) {
          final routeData = state.extra! as TrackDetailRouteData;
          return TrackDetailScreen(
            track: routeData.track,
            onTrackUploaded: routeData.onTrackUploaded,
          );
        },
      ),
    ],
  );
}
