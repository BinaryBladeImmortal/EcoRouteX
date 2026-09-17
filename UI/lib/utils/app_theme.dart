// lib/utils/app_theme.dart
// EcoRouteX – Map-inspired Smart Mobility Theme

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // ── Core Palette ───────────────────────────────────────────
  static const Color primaryDark = Color(0xFF0D1B2A); // deep navy
  static const Color primaryGreen = Color(0xFF00C896); // vivid teal-green
  static const Color secondaryGreen = Color(0xFF00E5A0); // bright mint
  static const Color accentBlue = Color(0xFF4FC3F7); // sky blue
  static const Color accentAmber = Color(0xFFFFB300); // warm amber
  static const Color warningAmber = Color(0xFFFFB300); // warning amber
  static const Color mapDark = Color(0xFF142030); // map background
  static const Color cardDark = Color(0xFF1A2D3E); // card surface
  static const Color cardMid = Color(0xFF1F3448); // elevated card
  static const Color textWhite = Color(0xFFECF4FF); // primary text
  static const Color textSoft = Color(0xFF8BAFC8); // secondary text
  static const Color textFaint = Color(0xFF4A6A82); // hint text
  static const Color success = Color(0xFF00C896);
  static const Color warning = Color(0xFFFFB300);
  static const Color danger = Color(0xFFFF5252);
  static const Color surface = Color(0xFF112436);

  // ── Gradients ──────────────────────────────────────────────
  static const LinearGradient heroGradient = LinearGradient(
    colors: [Color(0xFF0D1B2A), Color(0xFF142030), Color(0xFF1A2D3E)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient greenGradient = LinearGradient(
    colors: [Color(0xFF00C896), Color(0xFF00E5A0)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient blueGradient = LinearGradient(
    colors: [Color(0xFF1565C0), Color(0xFF4FC3F7)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient cardGradient = LinearGradient(
    colors: [Color(0xFF1A2D3E), Color(0xFF1F3448)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ── Shadows ────────────────────────────────────────────────
  static List<BoxShadow> greenGlow = [
    BoxShadow(
        color: primaryGreen.withOpacity(0.3),
        blurRadius: 20,
        offset: const Offset(0, 6)),
  ];

  static List<BoxShadow> cardShadow = [
    BoxShadow(
        color: Colors.black.withOpacity(0.3),
        blurRadius: 16,
        offset: const Offset(0, 4)),
  ];

  static List<BoxShadow> blueGlow = [
    BoxShadow(
        color: accentBlue.withOpacity(0.25),
        blurRadius: 16,
        offset: const Offset(0, 4)),
  ];

  // ── ThemeData ──────────────────────────────────────────────
  static ThemeData get theme => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: primaryDark,
        colorScheme: const ColorScheme.dark(
          primary: primaryGreen,
          secondary: accentBlue,
          surface: cardDark,
        ),
        textTheme: ThemeData.dark().textTheme.copyWith(
              displayLarge: const TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w700,
                  color: textWhite,
                  letterSpacing: 1),
              displayMedium: const TextStyle(
                  fontSize: 28, fontWeight: FontWeight.w600, color: textWhite),
              headlineMedium: const TextStyle(
                  fontSize: 22, fontWeight: FontWeight.w700, color: textWhite),
              headlineSmall: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w600, color: textWhite),
              titleLarge: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w600, color: textWhite),
              titleMedium: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w500, color: textSoft),
              bodyLarge: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w400, color: textWhite),
              bodyMedium: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w400, color: textSoft),
              labelLarge: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: textWhite,
                  letterSpacing: 0.5),
            ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          titleTextStyle: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: textWhite,
              letterSpacing: 1),
          iconTheme: IconThemeData(color: textWhite),
        ),
        cardTheme: CardThemeData(
          color: cardDark,
          elevation: 0,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          margin: EdgeInsets.zero,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryGreen,
            foregroundColor: primaryDark,
            elevation: 0,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            textStyle: GoogleFonts.spaceGrotesk(
                fontSize: 15, fontWeight: FontWeight.w700),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: cardDark,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: textFaint.withOpacity(0.5)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: primaryGreen, width: 1.5),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          labelStyle: GoogleFonts.spaceGrotesk(color: textSoft, fontSize: 14),
          hintStyle: GoogleFonts.spaceGrotesk(color: textFaint, fontSize: 14),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: cardDark,
          selectedItemColor: primaryGreen,
          unselectedItemColor: textFaint,
          elevation: 0,
          type: BottomNavigationBarType.fixed,
        ),
      );
}
