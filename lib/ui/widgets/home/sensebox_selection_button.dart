import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sensebox_bike/blocs/configuration_bloc.dart';
import 'package:sensebox_bike/blocs/opensensemap_bloc.dart';
import 'package:sensebox_bike/blocs/settings_bloc.dart';
import 'package:sensebox_bike/l10n/app_localizations.dart';
import 'package:sensebox_bike/theme.dart';
import 'package:sensebox_bike/ui/widgets/common/loader.dart';
import 'package:sensebox_bike/ui/widgets/opensensemap/sensebox_selection_modal.dart';

class SenseBoxSelectionButton extends StatelessWidget {
  const SenseBoxSelectionButton({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<OpenSenseMapBloc, OpenSenseMapState>(
      builder: (context, osemState) {
        return BlocBuilder<SettingsBloc, SettingsState>(
          builder: (context, settingsState) {
            final osemBloc = context.read<OpenSenseMapBloc>();
            final colorScheme = Theme.of(context).colorScheme;
            final textTheme = Theme.of(context).textTheme;

            final isAuthenticated = osemState.isAuthenticated;
            final isAuthenticating = osemState.isAuthenticating;
            final selectedBox = osemState.selectedSenseBox;
            final noBox = selectedBox == null;

            Color backgroundColor;
            Color textColor;
            Color borderColor;
            IconData icon;
            String label;
            VoidCallback? onTap;

            if (isAuthenticating) {
              backgroundColor = colorScheme.surface.withValues(alpha: 0.5);
              textColor = colorScheme.onSurface.withValues(alpha: 0.6);
              borderColor = colorScheme.outline.withValues(alpha: 0.3);
              icon = Icons.hourglass_empty;
              label = AppLocalizations.of(context)!.generalLoading;
              onTap = null;
            } else if (!isAuthenticated) {
              backgroundColor = loginRequiredColor;
              textColor = loginRequiredTextColor;
              borderColor = loginRequiredColor;
              icon = Icons.login;
              label = AppLocalizations.of(context)!.loginRequiredMessage;
              final configBloc = context.read<ConfigurationBloc>();
              onTap = () => showSenseBoxManager(context, osemBloc, configBloc);
            } else {
              textColor = Theme.of(context).colorScheme.onTertiaryContainer;
              backgroundColor = Theme.of(context).colorScheme.tertiary;
              borderColor = Theme.of(context).colorScheme.tertiary;
              icon = noBox
                  ? Icons.add_box_outlined
                  : Icons.emergency_share_rounded;
              label = noBox
                  ? AppLocalizations.of(context)!.selectOrCreateBox
                  : selectedBox.name ?? '';
              final configBloc = context.read<ConfigurationBloc>();
              onTap = () => showSenseBoxManager(context, osemBloc, configBloc);
            }

            final modeLabel = settingsState.directUploadMode
                ? AppLocalizations.of(context)!.settingsUploadModeDirect
                : AppLocalizations.of(context)!.settingsUploadModePostRide;
            final modeIcon = settingsState.directUploadMode
                ? Icons.bolt_rounded
                : Icons.schedule_rounded;
            final showModeBadge = isAuthenticated && !isAuthenticating;

            return InkWell(
              onTap: onTap,
              child: Container(
                width: double.infinity,
                constraints: const BoxConstraints(minHeight: 48),
                decoration: BoxDecoration(
                  color: backgroundColor,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: borderColor,
                    width: 1.0,
                    style: BorderStyle.solid,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: colorScheme.shadow.withOpacity(0.03),
                      blurRadius: 1.5,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(
                      height: 24,
                      width: 24,
                      child: Center(
                        child: isAuthenticating
                            ? const Loader(light: true)
                            : Icon(
                                icon,
                                color: textColor,
                                size: 20,
                              ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        label,
                        style: textTheme.bodyLarge?.copyWith(
                          color: textColor,
                          fontWeight: FontWeight.w600,
                          height: 1.2,
                        ),
                        maxLines: 3,
                      ),
                    ),
                    if (isAuthenticated && !isAuthenticating && noBox)
                      Padding(
                        padding: const EdgeInsets.only(left: 8.0),
                        child: Icon(Icons.arrow_forward,
                            color: textColor, size: 16),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
