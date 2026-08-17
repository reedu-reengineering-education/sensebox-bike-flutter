import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sensebox_bike/constants.dart';
import 'package:sensebox_bike/l10n/app_localizations.dart';
import 'package:sensebox_bike/theme.dart';
import 'package:sensebox_bike/ui/widgets/common/modal_sheet_style.dart';
import 'package:sensebox_bike/ui/widgets/common/surface_outlined_icon_button.dart';
import 'package:sensebox_bike/utils/changelog_utils.dart';

/// Whether the "what's new" modal should be shown for this app start.
///
/// Shown whenever the stored last-seen version differs from the current one
/// — including the very first check after installing this feature itself,
/// where [lastSeenVersion] is `null` because the pref didn't exist yet. That
/// also means a brand-new install sees the current version's changelog once;
/// there's no reliable signal here to tell "upgraded from a version that
/// predates this pref" apart from "never launched before".
bool shouldShowChangelogModal({
  required String? lastSeenVersion,
  required String currentVersion,
}) {
  return lastSeenVersion != currentVersion;
}

/// Checks whether the app was just upgraded and, if so, shows a modal with
/// the current version's `CHANGELOG.md` section. Best-effort: any failure
/// (missing asset, platform channel error, ...) is swallowed so this never
/// blocks app startup. Safe to call on every cold start.
Future<void> maybeShowChangelogModal(BuildContext context) async {
  try {
    final packageInfo = await PackageInfo.fromPlatform();
    final currentVersion = packageInfo.version;

    final prefs = await SharedPreferences.getInstance();
    final lastSeenVersion =
        prefs.getString(SharedPreferencesKeys.lastSeenAppVersion);

    final shouldShow = shouldShowChangelogModal(
      lastSeenVersion: lastSeenVersion,
      currentVersion: currentVersion,
    );

    if (!shouldShow) {
      await prefs.setString(
          SharedPreferencesKeys.lastSeenAppVersion, currentVersion);
      return;
    }

    final sections = await _loadChangelogSections(currentVersion);

    await prefs.setString(
        SharedPreferencesKeys.lastSeenAppVersion, currentVersion);

    if (sections.isEmpty || !context.mounted) {
      return;
    }

    await showChangelogModal(
      context,
      version: currentVersion,
      sections: sections,
    );
  } catch (_) {
    // Best-effort UI nicety; never let this break app startup.
  }
}

/// Shows the current app version's changelog on demand (e.g. the user
/// tapping the version number in Settings), regardless of whether it's
/// already been seen. Silently does nothing if the version isn't
/// documented in `CHANGELOG.md` or the lookup fails.
Future<void> showChangelogModalForCurrentVersion(BuildContext context) async {
  try {
    final packageInfo = await PackageInfo.fromPlatform();
    final sections = await _loadChangelogSections(packageInfo.version);

    if (sections.isEmpty || !context.mounted) {
      return;
    }

    await showChangelogModal(
      context,
      version: packageInfo.version,
      sections: sections,
    );
  } catch (_) {
    // Best-effort; a failed manual lookup just does nothing.
  }
}

Future<List<ChangelogSection>> _loadChangelogSections(String version) async {
  final changelog = await rootBundle.loadString('CHANGELOG.md');
  return parseChangelogVersionSection(changelog, version);
}

Future<void> showChangelogModal(
  BuildContext context, {
  required String version,
  required List<ChangelogSection> sections,
}) {
  return showAppModalSheet<void>(
    context: context,
    useRootNavigator: true,
    builder: (sheetContext) => _ChangelogSheet(
      version: version,
      sections: sections,
    ),
  );
}

class _ChangelogSheet extends StatelessWidget {
  final String version;
  final List<ChangelogSection> sections;

  const _ChangelogSheet({required this.version, required this.sections});

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: spacing * 2),
          child: Text(
            localizations.changelogModalTitle(version),
            style: Theme.of(context).textTheme.headlineMedium,
            textAlign: TextAlign.center,
          ),
        ),
        SizedBox(
          height: MediaQuery.of(context).size.height * 0.6,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              spacing * 2,
              spacing * 2,
              spacing * 2,
              spacing,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final section in sections)
                  Padding(
                    padding: const EdgeInsets.only(bottom: spacing * 2),
                    child: _ChangelogSectionView(section: section),
                  ),
              ],
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.only(
            left: spacing,
            right: spacing,
            top: spacing,
            bottom: spacing * 2 + MediaQuery.of(context).viewPadding.bottom,
          ),
          child: SurfaceOutlinedIconButton(
            icon: Icons.check,
            label: localizations.generalClose,
            onPressed: () => Navigator.pop(context),
          ),
        ),
      ],
    );
  }
}

class _ChangelogSectionView extends StatelessWidget {
  final ChangelogSection section;

  const _ChangelogSectionView({required this.section});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (section.category.isNotEmpty) ...[
          Text(
            section.category,
            style: theme.textTheme.titleSmall
                ?.copyWith(color: theme.colorScheme.primary),
          ),
          const SizedBox(height: spacing),
        ],
        for (final item in section.items)
          Padding(
            padding: const EdgeInsets.only(bottom: spacing),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Icon(
                    Icons.circle,
                    size: 6,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: spacing),
                Expanded(
                  child: Text(
                    item,
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
