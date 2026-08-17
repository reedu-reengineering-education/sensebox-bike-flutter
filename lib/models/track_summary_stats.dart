/// Aggregate stats for the tracks overview screen, computed entirely from
/// TrackData's cached* columns via DB-side sum/count/min queries - no
/// GeolocationData row is ever loaded to produce these. See
/// [TrackService.getSummaryStats].
class TrackSummaryStats {
  final int totalTrackCount;
  final double totalDistanceKm;
  final Duration totalDuration;
  final DateTime? earliestStartTimestamp;

  final int recentTrackCount;
  final double recentDistanceKm;
  final Duration recentDuration;

  const TrackSummaryStats({
    required this.totalTrackCount,
    required this.totalDistanceKm,
    required this.totalDuration,
    required this.earliestStartTimestamp,
    required this.recentTrackCount,
    required this.recentDistanceKm,
    required this.recentDuration,
  });

  static const empty = TrackSummaryStats(
    totalTrackCount: 0,
    totalDistanceKm: 0,
    totalDuration: Duration.zero,
    earliestStartTimestamp: null,
    recentTrackCount: 0,
    recentDistanceKm: 0,
    recentDuration: Duration.zero,
  );
}
