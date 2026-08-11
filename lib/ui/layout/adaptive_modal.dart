import 'package:flutter/material.dart';
import 'package:sensebox_bike/ui/layout/form_factor.dart';

/// Bottom sheet on phone; centered width-capped dialog on tablet.
Future<T?> showAdaptiveModal<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = true,
  bool showDragHandle = false,
  Clip clipBehavior = Clip.none,
}) {
  if (context.isTablet) {
    return showDialog<T>(
      context: context,
      builder: (dialogContext) {
        final height = MediaQuery.sizeOf(dialogContext).height;
        // iPadOS can synthesize a ghost barrier tap ~300–500ms after opening a
        // dialog from the upper screen (e.g. landscape side-rail Connect).
        // Ignore pops during that window; keep explicit Navigator.pop working.
        // See https://github.com/flutter/flutter/issues/185881
        final openTime = DateTime.now();
        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, result) {
            if (didPop) return;
            if (DateTime.now().difference(openTime) > const Duration(milliseconds: 500)) {
              Navigator.of(dialogContext).pop(result);
            }
          },
          child: Dialog(
            clipBehavior: clipBehavior == Clip.none
                ? Clip.antiAlias
                : clipBehavior,
            insetPadding:
                const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: Breakpoints.modalMaxWidth,
                maxHeight: height * 0.85,
              ),
              child: builder(dialogContext),
            ),
          ),
        );
      },
    );
  }

  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    showDragHandle: showDragHandle,
    clipBehavior: clipBehavior,
    builder: builder,
  );
}
