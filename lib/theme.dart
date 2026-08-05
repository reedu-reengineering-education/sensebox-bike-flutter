import 'package:flutter/material.dart';

// Custom colors for specific use cases
const Color loginRequiredColor =
    Color.fromARGB(255, 58, 2, 88); // Dark red for login requirement
const Color loginRequiredTextColor =
    Colors.white; // White text for login requirement

ButtonStyle _filledButtonStyle(ColorScheme scheme) {
  return FilledButton.styleFrom(
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(borderRadius),
    ),
    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
    overlayColor: scheme.brightness == Brightness.light
        ? scheme.onPrimary.withValues(alpha: 0.16)
        : scheme.onPrimary.withValues(alpha: 0.20),
  );
}

ButtonStyle _outlinedButtonStyle(ColorScheme scheme) {
  return OutlinedButton.styleFrom(
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(borderRadius),
    ),
    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
    overlayColor: scheme.brightness == Brightness.light
        ? scheme.primary.withValues(alpha: 0.12)
        : scheme.primary.withValues(alpha: 0.16),
  );
}

ButtonStyle _iconButtonStyle(ColorScheme scheme) {
  return IconButton.styleFrom(
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(borderRadiusSmall),
    ),
    overlayColor: scheme.brightness == Brightness.light
        ? scheme.primary.withValues(alpha: 0.12)
        : scheme.primary.withValues(alpha: 0.16),
  );
}

final lightTheme = ThemeData(
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: Colors.grey[50],
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
      primary: Colors.black,
      primaryFixedDim: Colors.grey,
      secondary: Colors.black12,
      tertiary: Color.fromRGBO(2, 59, 35, 1),
      onTertiaryContainer: Colors.white),
  canvasColor: Colors.grey[50],
  cardTheme: CardThemeData(
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(24),
    ),
  ),
  textTheme: const TextTheme(
    headlineLarge: TextStyle(fontSize: 28),
    headlineMedium: TextStyle(fontSize: 24),
    headlineSmall: TextStyle(fontSize: 20),
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: _filledButtonStyle(const ColorScheme.light(
      primary: Colors.black,
      onPrimary: Colors.white,
    )),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: _outlinedButtonStyle(const ColorScheme.light(
      primary: Colors.black,
    )),
  ),
  iconButtonTheme: IconButtonThemeData(
    style: _iconButtonStyle(const ColorScheme.light(
      primary: Colors.black,
    )),
  ),
);

final darkTheme = ThemeData(
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: const Color.fromARGB(255, 24, 24, 24),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12.0),
    ),
  ),
  snackBarTheme: SnackBarThemeData(
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(24),
    ),
  ),
  canvasColor: const Color.fromARGB(255, 24, 24, 24),
  colorScheme: const ColorScheme.dark(
      primary: Colors.white,
      primaryFixedDim: Colors.grey,
      secondary: Colors.white,
      tertiary: Color.fromRGBO(2, 59, 35, 1),
      onTertiaryContainer: Colors.white,
      surface: Color(0xFF121212)),
  cardTheme: CardThemeData(
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(24),
    ),
  ),
  textTheme: const TextTheme(
    headlineLarge: TextStyle(fontSize: 28),
    headlineMedium: TextStyle(fontSize: 24),
    headlineSmall: TextStyle(fontSize: 20),
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: _filledButtonStyle(const ColorScheme.dark(
      primary: Colors.white,
      onPrimary: Colors.black,
    )),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: _outlinedButtonStyle(const ColorScheme.dark(
      primary: Colors.white,
    )),
  ),
  iconButtonTheme: IconButtonThemeData(
    style: _iconButtonStyle(const ColorScheme.dark(
      primary: Colors.white,
    )),
  ),
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
const double borderRadius = 24.0;
const double borderRadiusSmall = 8.0;
