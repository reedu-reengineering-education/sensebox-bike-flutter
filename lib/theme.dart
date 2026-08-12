import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

// Custom colors for specific use cases
const Color loginRequiredColor =
    Color.fromARGB(255, 58, 2, 88); // Original purple login requirement
const Color loginRequiredTextColor =
    Colors.white; // White text for login requirement

const _lightBackground = Color(0xFFf5f3f0);
const _lightSurface = Color(0xFFfbfaf9);
const _lightOnSurface = Color(0xFF1C1C1A);
const _lightOnSurfaceVariant = Color(0xFF5E5E58);

const _darkBackground = Color(0xFF171513);
const _darkSurface = Color(0xFF201D1A);
const _darkSurfaceContainer = Color(0xFF2B2722);
const _darkOnSurface = Color(0xFFF4EFE6);
const _darkOnSurfaceVariant = Color(0xFFCEC4B6);

// Swap this single value to A/B test headline families quickly.
const String kHeadlineFontFamily = 'Space Grotesk';

TextStyle _headlineStyle({
  required double fontSize,
  required FontWeight fontWeight,
  required double height,
  double? letterSpacing,
  required Color color,
}) {
  return GoogleFonts.getFont(
    kHeadlineFontFamily,
    fontSize: fontSize,
    fontWeight: fontWeight,
    height: height,
    letterSpacing: letterSpacing,
    color: color,
  );
}

TextTheme _appTextTheme(Brightness brightness) {
  final base = GoogleFonts.spaceGroteskTextTheme();

  final headingColor =
      brightness == Brightness.dark ? _darkOnSurface : _lightOnSurface;

  return base.copyWith(
    headlineLarge: _headlineStyle(
      fontSize: 30,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.4,
      height: 1.12,
      color: headingColor,
    ),
    headlineMedium: _headlineStyle(
      fontSize: 25,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.2,
      height: 1.16,
      color: headingColor,
    ),
    headlineSmall: _headlineStyle(
      fontSize: 21,
      fontWeight: FontWeight.w700,
      height: 1.2,
      color: headingColor,
    ),
    titleLarge: base.titleLarge?.copyWith(
      fontWeight: FontWeight.w600,
      letterSpacing: -0.1,
      height: 1.25,
      color: headingColor,
    ),
    titleMedium: base.titleMedium?.copyWith(
      fontWeight: FontWeight.w500,
      height: 1.26,
      color: headingColor,
    ),
    titleSmall: base.titleSmall?.copyWith(
      fontWeight: FontWeight.w500,
      height: 1.25,
      color: headingColor,
    ),
    bodyLarge: base.bodyLarge?.copyWith(
      height: 1.38,
      color: headingColor,
    ),
    bodyMedium: base.bodyMedium?.copyWith(
      height: 1.36,
      color: headingColor,
    ),
    bodySmall: base.bodySmall?.copyWith(
      height: 1.34,
      color: headingColor,
    ),
    labelLarge: base.labelLarge?.copyWith(
      fontWeight: FontWeight.w600,
      letterSpacing: 0.1,
      color: headingColor,
    ),
  );
}

final lightTheme = ThemeData(
  useMaterial3: true,
  scaffoldBackgroundColor: _lightBackground,
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: _lightSurface,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12.0),
    ),
  ),
  snackBarTheme: SnackBarThemeData(
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(24),
    ),
  ),
  colorScheme: const ColorScheme.light(
    primary: _lightOnSurface,
    primaryFixedDim: Colors.grey,
    secondary: Color(0xFFE0E0DA),
    tertiary: Color.fromRGBO(2, 59, 35, 1),
    onTertiaryContainer: Colors.white,
    surface: _lightSurface,
    onSurface: _lightOnSurface,
    onSurfaceVariant: _lightOnSurfaceVariant,
    outline: Color(0xFFBBBAB3),
  ),
  canvasColor: _lightSurface,
  appBarTheme: const AppBarTheme(
    centerTitle: true,
    backgroundColor: Colors.transparent,
    elevation: 0,
    scrolledUnderElevation: 0,
    systemOverlayStyle: SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
    ),
  ),
  cardTheme: CardThemeData(
    elevation: 1,
    shadowColor: Color(0x15000000),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(24),
    ),
    color: _lightSurface,
  ),
  textTheme: _appTextTheme(Brightness.light),
);

final darkTheme = ThemeData(
  useMaterial3: true,
  scaffoldBackgroundColor: _darkBackground,
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: _darkSurface,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12.0),
    ),
  ),
  snackBarTheme: SnackBarThemeData(
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(24),
    ),
  ),
  canvasColor: _darkSurface,
  colorScheme: const ColorScheme.dark(
    primary: _darkOnSurface,
    primaryFixedDim: Colors.grey,
    secondary: _darkOnSurfaceVariant,
    tertiary: Color.fromRGBO(2, 59, 35, 1),
    onTertiaryContainer: Colors.white,
    surface: _darkSurface,
    surfaceContainerHigh: _darkSurfaceContainer,
    onSurface: _darkOnSurface,
    onSurfaceVariant: _darkOnSurfaceVariant,
    outline: Color(0xFF5A5249),
  ),
  appBarTheme: const AppBarTheme(
    centerTitle: true,
    backgroundColor: Colors.transparent,
    elevation: 0,
    scrolledUnderElevation: 0,
    systemOverlayStyle: SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
    ),
  ),
  cardTheme: CardThemeData(
    elevation: 1,
    shadowColor: Color(0x15000000),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(24),
    ),
    color: _darkSurface,
  ),
  textTheme: _appTextTheme(Brightness.dark),
);

extension CustomColors on ColorScheme {
  Color get success =>
      brightness == Brightness.light ? Colors.green : Colors.green;
  Color get info => brightness == Brightness.light ? Colors.blue : Colors.blue;
}

const double circleSize = 16.0;
const double iconSize = 12.0;
const double iconSizeLarge = 16.0;
const double spacing = 12.0;
const double borderWidth = 1.5;
const double padding = 8.0;

const cardBoxShadow = [
  BoxShadow(
    color: Color(0x0F000000),
    blurRadius: 8,
    offset: Offset(0, 2),
  ),
];
const double borderRadius = 24.0;
const double borderRadiusSmall = 8.0;
