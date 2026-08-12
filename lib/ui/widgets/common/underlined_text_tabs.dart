import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class UnderlinedTextTabs extends StatelessWidget {
  final List<String> items;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final EdgeInsetsGeometry padding;
  final bool showBottomDivider;
  final double itemSpacing;
  final double tabHorizontalPadding;
  final double tabVerticalPadding;
  final double indicatorHeight;
  final Duration animationDuration;
  final Curve animationCurve;

  const UnderlinedTextTabs({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
    this.padding = const EdgeInsets.fromLTRB(16, 10, 16, 0),
    this.showBottomDivider = true,
    this.itemSpacing = 20,
    this.tabHorizontalPadding = 4,
    this.tabVerticalPadding = 10,
    this.indicatorHeight = 3,
    this.animationDuration = const Duration(milliseconds: 240),
    this.animationCurve = Curves.easeOutCubic,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();

    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final activeColor = Theme.of(context).colorScheme.onSurface;
    final inactiveColor = Theme.of(context).colorScheme.onSurfaceVariant;
    final textStyle = textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
          letterSpacing: -0.1,
        ) ??
        const TextStyle(fontWeight: FontWeight.w600);
    final textDirection = Directionality.of(context);
    final textScaler = MediaQuery.textScalerOf(context);
    final tabWidths = items
        .map(
          (label) =>
              _measureTextWidth(
                label,
                textStyle,
                textDirection,
                textScaler,
              ) +
              (tabHorizontalPadding * 2),
        )
        .toList(growable: false);
    final clampedIndex = selectedIndex.clamp(0, items.length - 1);

    double leftFor(int index) {
      var offset = 0.0;
      for (var i = 0; i < index; i++) {
        offset += tabWidths[i];
        if (i < items.length - 1) offset += itemSpacing;
      }
      return offset;
    }

    final indicatorLeft = leftFor(clampedIndex);
    final indicatorWidth = tabWidths[clampedIndex];
    final totalWidth = tabWidths.fold<double>(0, (sum, value) => sum + value) +
        (itemSpacing * (items.length - 1));

    Widget tab(int index) {
      final isActive = clampedIndex == index;
      final label = items[index];
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          if (!isActive) {
            HapticFeedback.selectionClick();
            onSelected(index);
          }
        },
        child: Padding(
          padding: EdgeInsets.only(
            right: index == items.length - 1 ? 0 : itemSpacing,
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: tabHorizontalPadding,
              vertical: tabVerticalPadding,
            ),
            child: AnimatedDefaultTextStyle(
              duration: animationDuration,
              curve: animationCurve,
              style: textStyle.copyWith(
                color: isActive ? activeColor : inactiveColor,
              ),
              child: Text(label),
            ),
          ),
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: totalWidth,
              child: Stack(
                children: [
                  Row(
                    children: List.generate(items.length, tab),
                  ),
                  AnimatedPositioned(
                    duration: animationDuration,
                    curve: animationCurve,
                    left: indicatorLeft,
                    width: indicatorWidth,
                    bottom: 0,
                    child: Container(
                      height: indicatorHeight,
                      decoration: BoxDecoration(
                        color: activeColor,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (showBottomDivider)
            Divider(
              height: 1,
              thickness: 1,
              color: colorScheme.outline.withValues(alpha: 0.42),
            ),
        ],
      ),
    );
  }

  double _measureTextWidth(
    String label,
    TextStyle style,
    TextDirection textDirection,
    TextScaler textScaler,
  ) {
    final painter = TextPainter(
      text: TextSpan(text: label, style: style),
      textDirection: textDirection,
      textScaler: textScaler,
      maxLines: 1,
    )..layout();

    return painter.width;
  }
}
