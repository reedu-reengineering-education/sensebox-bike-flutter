import 'package:flutter/material.dart';
import 'package:sensebox_bike/l10n/app_localizations.dart';
import 'package:sensebox_bike/ui/widgets/common/empty_state_message.dart';

/// A centered widget that displays a message when no tracks are available.
/// Used to inform users that they haven't recorded any tracks yet.
class NoTracksMessage extends StatelessWidget {
  const NoTracksMessage({super.key});

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    
    return EmptyStateMessage(
      icon: Icons.route_outlined,
      message: localizations.tracksNoTracks,
    );
  }
}