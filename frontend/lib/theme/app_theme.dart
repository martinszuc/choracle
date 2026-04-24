import 'package:flutter/material.dart';

const kPrimaryColor = Color(0xFF741DED);
const kSecondaryColor = Color(0xFF6200EE);
const kBackgroundColor = Color(0xFFF7F7F7);
const kTextColor = Color(0xFF333333);

ThemeData buildAppTheme() {
  return ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: kPrimaryColor,
      primary: kPrimaryColor,
      secondary: kSecondaryColor,
      surface: kBackgroundColor,
    ),
    scaffoldBackgroundColor: kBackgroundColor,
    fontFamily: 'Roboto',
    textTheme: const TextTheme(
      bodyMedium: TextStyle(color: kTextColor),
      bodyLarge: TextStyle(color: kTextColor),
      titleMedium: TextStyle(color: kTextColor, fontWeight: FontWeight.w600),
      titleLarge: TextStyle(color: kTextColor, fontWeight: FontWeight.bold),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: kPrimaryColor),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: kPrimaryColor,
      foregroundColor: Colors.white,
      elevation: 0,
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: kPrimaryColor,
      foregroundColor: Colors.white,
    ),
    navigationBarTheme: NavigationBarThemeData(
      indicatorColor: kPrimaryColor.withOpacity(0.15),
      labelTextStyle: WidgetStateProperty.all(
        const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: kTextColor),
      ),
    ),
    useMaterial3: true,
  );
}
