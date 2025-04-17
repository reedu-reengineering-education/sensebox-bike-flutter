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
      secondary: Colors.black12,
      tertiary: Colors.lightGreen,
      surfaceContainerLow: Colors.grey),
  canvasColor: Colors.grey[50],
  cardTheme: CardTheme(
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(24),
    ),
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
      secondary: Colors.white,
      tertiary: Colors.green,
      surface: Color(0xFF121212),
      surfaceContainerLow: Color(0xFF424242)),
  cardTheme: CardTheme(
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(24),
    ),
  ),
);
