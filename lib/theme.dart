import 'package:flutter/material.dart';

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
  colorScheme:
      const ColorScheme.light(
      primary: Colors.black,
      primaryFixedDim: Colors.grey,
      secondary: Colors.black12,
      tertiary: Colors.lightGreen,
      surface: Color(0xFF121212),
      surfaceVariant: Color.fromRGBO(255, 255, 255, 0.18)),
  canvasColor: Colors.grey[50],
  cardTheme: CardTheme(
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(24),
    ),
  ),
  textTheme: const TextTheme(
    bodySmall: TextStyle(
      fontSize: 12,
    ),
    headlineLarge: TextStyle(fontSize: 32),
    headlineMedium: TextStyle(fontSize: 24),
    headlineSmall: TextStyle(fontSize: 20),
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
      tertiary: Colors.green,
      surface: Color(0xFF121212),
      surfaceVariant: Color.fromRGBO(255, 255, 255, 0.18)),
  cardTheme: CardTheme(
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(24),
    ),
  ),
  textTheme: const TextTheme(
    bodySmall: TextStyle(
      fontSize: 12,
    ),
    headlineLarge: TextStyle(fontSize: 32),
    headlineMedium: TextStyle(fontSize: 24),
    headlineSmall: TextStyle(fontSize: 20),
  ),
);

const double circleSize = 16.0;
const double iconSize = 12.0;
const double iconSizeLarge = 20.0;
const double spacing = 12.0;
const double borderWidth = 1.5;
const double borderWidthRegular = 2.0;
const double padding = 8.0;
const double borderRadius = 24.0;

extension CustomThemeData on ThemeData {
  BorderRadius get buttonBorderRadius =>
      const BorderRadius.all(Radius.circular(16));
  BorderRadius get tileBorderRadius =>
      const BorderRadius.all(Radius.circular(16));
  BorderRadius get imageBorderRadius =>
      const BorderRadius.all(Radius.circular(9));
}
