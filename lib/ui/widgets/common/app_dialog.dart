import 'dart:math' as math;

import 'package:flutter/material.dart';

Future<T?> showAppDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
  bool useRootNavigator = true,
}) {
  return showDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    useRootNavigator: useRootNavigator,
    builder: builder,
  );
}

class AppAlertDialog extends StatelessWidget {
  final Widget? title;
  final Widget? content;
  final List<Widget> actions;
  final EdgeInsets insetPadding;
  final EdgeInsetsGeometry titlePadding;
  final EdgeInsetsGeometry contentPadding;
  final EdgeInsetsGeometry actionsPadding;
  final double borderRadius;
  final double maxWidth;

  const AppAlertDialog({
    super.key,
    this.title,
    this.content,
    this.actions = const [],
    this.insetPadding =
        const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
    this.titlePadding = const EdgeInsets.fromLTRB(24, 24, 24, 14),
    this.contentPadding = const EdgeInsets.fromLTRB(24, 0, 24, 16),
    this.actionsPadding = const EdgeInsets.fromLTRB(16, 4, 16, 14),
    this.borderRadius = 20,
    this.maxWidth = 560,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final targetMaxWidth = math.min(maxWidth, screenWidth - 32);

    return Dialog(
      insetPadding: insetPadding,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: targetMaxWidth,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (title != null)
              Padding(
                padding: titlePadding,
                child: title!,
              ),
            if (content != null)
              Padding(
                padding: contentPadding,
                child: content!,
              ),
            if (actions.isNotEmpty)
              Padding(
                padding: actionsPadding,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    for (var i = 0; i < actions.length; i++) ...[
                      if (i > 0) const SizedBox(width: 8),
                      actions[i],
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
