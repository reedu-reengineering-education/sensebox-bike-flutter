import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sensebox_bike/ui/layout/form_factor.dart';

/// Pumps a widget at [size] and hands the resulting context to [onContext].
Future<void> pumpAtSize(
  WidgetTester tester,
  Size size,
  void Function(BuildContext context) onContext,
) async {
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(size: size),
      child: Builder(
        builder: (context) {
          onContext(context);
          return const SizedBox.shrink();
        },
      ),
    ),
  );
}

void main() {
  group('FormFactorX', () {
    testWidgets('phone sizes are not tablets', (tester) async {
      late bool isTablet;
      await pumpAtSize(tester, const Size(390, 844), (context) {
        isTablet = context.isTablet;
      });
      expect(isTablet, isFalse);
    });

    testWidgets('phone landscape is not a tablet', (tester) async {
      late bool isTablet;
      late bool isLandscape;
      await pumpAtSize(tester, const Size(844, 390), (context) {
        isTablet = context.isTablet;
        isLandscape = context.isLandscape;
      });
      expect(isTablet, isFalse);
      expect(isLandscape, isTrue);
    });

    testWidgets('tablet portrait and landscape both count as tablet',
        (tester) async {
      late bool portraitIsTablet;
      await pumpAtSize(tester, const Size(768, 1024), (context) {
        portraitIsTablet = context.isTablet;
      });
      expect(portraitIsTablet, isTrue);

      late bool landscapeIsTablet;
      late bool isLandscape;
      await pumpAtSize(tester, const Size(1024, 768), (context) {
        landscapeIsTablet = context.isTablet;
        isLandscape = context.isLandscape;
      });
      expect(landscapeIsTablet, isTrue);
      expect(isLandscape, isTrue);
    });

    testWidgets('side rail is landscape-tablet only', (tester) async {
      late bool tabletLandscape;
      await pumpAtSize(tester, const Size(1194, 834), (context) {
        tabletLandscape = context.useSideRail;
      });
      expect(tabletLandscape, isTrue);

      // Tablet portrait keeps the stacked phone layout.
      late bool tabletPortrait;
      await pumpAtSize(tester, const Size(834, 1194), (context) {
        tabletPortrait = context.useSideRail;
      });
      expect(tabletPortrait, isFalse);

      // Phone landscape is too small for a rail.
      late bool phoneLandscape;
      await pumpAtSize(tester, const Size(844, 390), (context) {
        phoneLandscape = context.useSideRail;
      });
      expect(phoneLandscape, isFalse);
    });

    testWidgets('shortest side exactly at the breakpoint is a tablet',
        (tester) async {
      late bool isTablet;
      await pumpAtSize(tester, const Size(Breakpoints.tablet, 900), (context) {
        isTablet = context.isTablet;
      });
      expect(isTablet, isTrue);
    });

    testWidgets('side rail width is clamped', (tester) async {
      late double narrowRail;
      await pumpAtSize(tester, const Size(900, 700), (context) {
        narrowRail = context.sideRailWidth;
      });
      // 900 * 0.32 = 288, clamped up to the 320 minimum.
      expect(narrowRail, 320.0);

      late double wideRail;
      await pumpAtSize(tester, const Size(1600, 1200), (context) {
        wideRail = context.sideRailWidth;
      });
      // 1600 * 0.32 = 512, clamped down to the 440 maximum.
      expect(wideRail, 440.0);

      // iPad Pro 11" landscape sits inside the clamp.
      late double midRail;
      await pumpAtSize(tester, const Size(1194, 834), (context) {
        midRail = context.sideRailWidth;
      });
      expect(midRail, closeTo(382.08, 0.01));
    });
  });
}
