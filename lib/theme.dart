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
      tertiary: Color.fromRGBO(27, 94, 32, 1),
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
);

const double circleSize = 16.0;
const double iconSize = 12.0;
const double iconSizeLarge = 16.0;
const double spacing = 12.0;
const double borderWidth = 1.5;
const double padding = 8.0;
const double borderRadius = 24.0;
const double borderRadiusSmall = 8.0;
