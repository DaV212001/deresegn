import 'package:flutter/material.dart';

class AppTheme {
  static final ThemeData lightTheme = ThemeData(
    fontFamily: 'Inter',
    brightness: Brightness.light,
    scaffoldBackgroundColor: const Color(0xFFF5F5F5),
    primaryColor: const Color(0xFF2F3283),
    colorScheme: const ColorScheme.light(
      primary: Color(0xFF2F3283),
      onPrimary: Colors.white,
      secondary: Color(0xFFE6004C), // Slightly darker pink for light mode
      surface: Color(0xFFFFFFFF),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFFFFFFFF),
      foregroundColor: Colors.black,
      elevation: 0,
      titleTextStyle: TextStyle(
        fontFamily: 'Inter',
        color: Colors.black,
        fontSize: 20,
        fontWeight: FontWeight.w600,
      ),
    ),
    cardColor: const Color(0xFFFFFFFF),
    iconTheme: const IconThemeData(color: Color(0xFF2F3283)),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: Color(0xFFFFFFFF),
      selectedItemColor: Color(0xFF2F3283),
      unselectedItemColor: Colors.grey,
    ),
    inputDecorationTheme: const InputDecorationTheme(
      fillColor: Color(0xFFEEEEEE),
    ),
    dividerColor: Colors.grey[300],
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF2F3283),
        foregroundColor: Colors.white,
        textStyle: const TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: Color(0xFF2F3283),
      foregroundColor: Colors.white,
    ),
  );

  static final ThemeData darkTheme = ThemeData(
    fontFamily: 'Inter',
    brightness: Brightness.dark,
    scaffoldBackgroundColor: const Color(0xFF121212),
    primaryColor: const Color(0xFFFEB101),
    colorScheme: const ColorScheme.dark(
      primary: Color(0xFFFEB101),
      onPrimary: Colors.black,
      secondary: Color(0xFFFF3366),
      surface: Color(0xFF1F1F1F), // Card background color
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF121212),
      foregroundColor: Colors.white,
      elevation: 0,
      titleTextStyle: TextStyle(
        fontFamily: 'Inter',
        color: Colors.white,
        fontSize: 20,
        fontWeight: FontWeight.w600,
      ),
    ),
    cardColor: const Color(0xFF1F1F1F),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: Color(0xFF1F1F1F),
      selectedItemColor: Color(0xFFFEB101),
      unselectedItemColor: Colors.grey,
    ),
    inputDecorationTheme: const InputDecorationTheme(
      fillColor: Color(0xFF2C2C2C),
    ),
    dividerColor: Colors.grey[800],
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFFFEB101),
        foregroundColor: Colors.black,
        textStyle: const TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: Color(0xFFFEB101),
      foregroundColor: Colors.black,
    ),
  );
}

