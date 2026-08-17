import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sensebox_bike/blocs/configuration_bloc.dart';
import 'package:sensebox_bike/blocs/opensensemap_bloc.dart';
import 'package:sensebox_bike/l10n/app_localizations.dart';
import 'package:sensebox_bike/theme.dart';
import 'package:sensebox_bike/ui/widgets/common/loader.dart';
import 'package:sensebox_bike/ui/widgets/opensensemap/sensebox_selection_modal.dart';

class SenseBoxSelectionButton extends StatelessWidget {
  const SenseBoxSelectionButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<OpenSenseMapBloc>(
      builder: (context, osemState, _) {
        final osemBloc = context.read<OpenSenseMapBloc>();
        final colorScheme = Theme.of(context).colorScheme;
        final textTheme = Theme.of(context).textTheme;

        final isAuthenticated = osemState.isAuthenticated;
        final isAuthenticating = osemState.isAuthenticating;
        final selectedBox = osemState.selectedSenseBox;
        final noBox = selectedBox == null;

        // pill = colored status badge inside the bar. The outer bar stays
        // neutral so the login-required / no-box / box-selected states
        // don't hide the rest of the bar's chrome (trailing action icon).
        Color pillColor;
        Color pillTextColor;
        String label;
        // The login-required and no-box prompts are full sentences and don't
        // fit the pill at body size - shrink just those two.
        bool compactLabel;
        VoidCallback? onTap;

        if (isAuthenticating) {
          pillColor = colorScheme.surfaceContainerHighest;
          pillTextColor = colorScheme.onSurface.withValues(alpha: 0.6);
          label = AppLocalizations.of(context)!.generalLoading;
          compactLabel = false;
          onTap = null;
        } else if (!isAuthenticated) {
          pillColor = loginRequiredColor;
          pillTextColor = loginRequiredTextColor;
          label = AppLocalizations.of(context)!.loginRequiredMessage;
          compactLabel = true;
          final configBloc = context.read<ConfigurationBloc>();
          onTap = () => showSenseBoxManager(context, osemBloc, configBloc);
        } else {
          pillTextColor = colorScheme.onTertiaryContainer;
          pillColor = colorScheme.tertiary;
          label = noBox
              ? AppLocalizations.of(context)!.selectOrCreateBox
              : selectedBox.name ?? '';
          compactLabel = noBox;
          final configBloc = context.read<ConfigurationBloc>();
          onTap = () => showSenseBoxManager(context, osemBloc, configBloc);
        }

        // Trailing indicator: hints the whole bar is tappable and what
        // tapping leads to (login prompt / box picker / box settings).
        final trailingIcon = onTap == null
            ? null
            : (!isAuthenticated || noBox)
                ? Icons.arrow_forward
                : Icons.tune_rounded;

        return InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            width: double.infinity,
            constraints: const BoxConstraints(minHeight: 48),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: colorScheme.outline.withValues(alpha: 0.2),
                width: 1.0,
              ),
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: 8.0,
              vertical: 8.0,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14.0,
                      vertical: 8.0,
                    ),
                    decoration: BoxDecoration(
                      color: pillColor,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isAuthenticating)
                          const Padding(
                            padding: EdgeInsets.only(right: 12),
                            child: SizedBox(
                              height: 16,
                              width: 16,
                              child: Loader(light: true),
                            ),
                          ),
                        Flexible(
                          child: Text(
                            label,
                            style: (compactLabel
                                    ? textTheme.bodyMedium
                                    : textTheme.bodyLarge)
                                ?.copyWith(
                              color: pillTextColor,
                              fontWeight: FontWeight.w600,
                              height: 1.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (trailingIcon != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10.0),
                    child: Icon(trailingIcon,
                        color: colorScheme.onSurfaceVariant, size: 18),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
