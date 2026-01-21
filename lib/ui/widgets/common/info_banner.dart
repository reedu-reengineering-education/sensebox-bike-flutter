import 'package:flutter/material.dart';
import 'package:sensebox_bike/services/error_service.dart';
import 'package:sensebox_bike/theme.dart';
import 'package:url_launcher/url_launcher.dart';

class InfoBanner extends StatelessWidget {
  final String text;
  final Color color;
  final EdgeInsetsGeometry? outerPadding;
  final String? url;
  final double? horizontalPadding;

  const InfoBanner({
    super.key,
    required this.text,
    this.color = Colors.blue,
    this.outerPadding,
    this.url,
    this.horizontalPadding,
  });

  Future<void> _openUrl(BuildContext context) async {
    if (url == null) return;
    try {
      await launchUrl(
        Uri.parse(url!),
        mode: LaunchMode.externalApplication,
      );
    } catch (error, stack) {
      ErrorService.handleError(error, stack);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasUrl = url != null;
    
    EdgeInsetsGeometry effectivePadding;
    if (outerPadding != null) {
      effectivePadding = outerPadding!;
    } else if (horizontalPadding != null) {
      effectivePadding = EdgeInsets.symmetric(
        vertical: spacing / 4,
        horizontal: horizontalPadding!,
      );
    } else {
      effectivePadding = const EdgeInsets.symmetric(
        vertical: spacing / 4,
        horizontal: spacing / 2,
      );
    }
    
    final content = Row(
      children: [
        Icon(
          Icons.info_outline,
          size: iconSize,
          color: color,
        ),
        const SizedBox(width: spacing / 2),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodySmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        if (hasUrl)
          Icon(
            Icons.open_in_new,
            size: iconSize * 0.8,
            color: color,
          ),
      ],
    );

    final container = Container(
      width: double.infinity,
      padding: const EdgeInsets.all(spacing),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(borderRadiusSmall),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: hasUrl
          ? Ink(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(borderRadiusSmall),
              ),
              child: InkWell(
                onTap: () => _openUrl(context),
                borderRadius: BorderRadius.circular(borderRadiusSmall),
                child: content,
              ),
            )
          : content,
    );

    return Padding(
      padding: effectivePadding,
      child: container,
    );
  }
}
