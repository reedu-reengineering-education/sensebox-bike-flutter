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
        return Dialog(
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
