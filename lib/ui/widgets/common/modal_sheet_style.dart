import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:modal_bottom_sheet/modal_bottom_sheet.dart';

Color modalBarrierColor(ThemeData theme) {
  return theme.brightness == Brightness.dark
      ? Colors.black.withValues(alpha: 0.72)
      : Colors.black.withValues(alpha: 0.38);
}

Widget buildModalSheetSurface(
  BuildContext context,
  Widget child, {
  bool showHandle = true,
}) {
  final theme = Theme.of(context);
  final handleColor = theme.colorScheme.onSurface.withValues(alpha: 0.28);

  return Material(
    color: Colors.transparent,
    child: Container(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(
          top: BorderSide(
            color: theme.colorScheme.onSurface.withValues(
              alpha: theme.brightness == Brightness.dark ? 0.14 : 0.08,
            ),
            width: 1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: theme.brightness == Brightness.dark ? 0.46 : 0.26,
            ),
            blurRadius: theme.brightness == Brightness.dark ? 30 : 24,
            spreadRadius: theme.brightness == Brightness.dark ? 2 : 0,
            offset: const Offset(0, -8),
          ),
          if (theme.brightness == Brightness.dark)
            BoxShadow(
              color: Colors.white.withValues(alpha: 0.03),
              blurRadius: 2,
              spreadRadius: -1,
              offset: const Offset(0, 1),
            ),
          if (theme.brightness == Brightness.dark)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.22),
              blurRadius: 44,
              spreadRadius: 4,
              offset: const Offset(0, -12),
            ),
        ],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showHandle)
              Padding(
                padding: const EdgeInsets.only(top: 10, bottom: 6),
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: handleColor,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
            child,
          ],
        ),
      ),
    ),
  );
}

Future<T?> showAppModalSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool useRootNavigator = true,
  bool scaleBackground = true,
  bool showHandle = true,
  bool expand = false,
}) {
  unawaited(HapticFeedback.selectionClick());
  final barrier = modalBarrierColor(Theme.of(context));

  Widget wrappedBuilder(BuildContext modalContext) {
    return buildModalSheetSurface(
      modalContext,
      builder(modalContext),
      showHandle: showHandle,
    );
  }

  if (scaleBackground) {
    return CupertinoScaffold.showCupertinoModalBottomSheet<T>(
      context: context,
      useRootNavigator: useRootNavigator,
      backgroundColor: Colors.transparent,
      barrierColor: barrier,
      expand: expand,
      builder: wrappedBuilder,
    );
  }

  return showCupertinoModalBottomSheet<T>(
    context: context,
    useRootNavigator: useRootNavigator,
    backgroundColor: Colors.transparent,
    barrierColor: barrier,
    expand: expand,
    builder: wrappedBuilder,
  );
}
