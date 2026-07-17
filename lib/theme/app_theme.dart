import 'package:flutter/material.dart';

class AppTheme {
  static final ThemeData lightTheme = ThemeData.light().copyWith(
    scaffoldBackgroundColor: const Color(0xFFF5F5F5),
    primaryColor: const Color(0xFF00FFB3),
    colorScheme: const ColorScheme.light(
      primary: Color(0xFF00C896), // Slightly darker teal for light mode contrast
      secondary: Color(0xFFE6004C), // Slightly darker pink for light mode
      surface: Color(0xFFFFFFFF),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFFFFFFFF),
      foregroundColor: Colors.black,
      elevation: 0,
    ),
    cardColor: const Color(0xFFFFFFFF),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: Color(0xFFFFFFFF),
      selectedItemColor: Color(0xFF00C896),
      unselectedItemColor: Colors.grey,
    ),
    inputDecorationTheme: const InputDecorationTheme(
      fillColor: Color(0xFFEEEEEE),
    ),
    dividerColor: Colors.grey[300],
  );

  static final ThemeData darkTheme = ThemeData.dark().copyWith(
    scaffoldBackgroundColor: const Color(0xFF121212),
    primaryColor: const Color(0xFF00FFB3),
    colorScheme: const ColorScheme.dark(
      primary: Color(0xFF00FFB3),
      secondary: Color(0xFFFF3366),
      surface: Color(0xFF1F1F1F), // Card background color
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF121212),
      foregroundColor: Colors.white,
      elevation: 0,
    ),
    cardColor: const Color(0xFF1F1F1F),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: Color(0xFF1F1F1F),
      selectedItemColor: Color(0xFF00FFB3),
      unselectedItemColor: Colors.grey,
    ),
    inputDecorationTheme: const InputDecorationTheme(
      fillColor: Color(0xFF2C2C2C),
    ),
    dividerColor: Colors.grey[800],
  );
}
