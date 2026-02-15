import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'palm_tokens.dart';

class PalmTheme {
  static ThemeData light() {
    final scheme = const ColorScheme.light(
      primary: PalmTokens.primary,
      onPrimary: PalmTokens.neutralDark,
      secondary: PalmTokens.primary,
      onSecondary: PalmTokens.neutralDark,
      surface: PalmTokens.surface,
      onSurface: PalmTokens.textMain,
      error: PalmTokens.danger,
      onError: Colors.white,
    );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: PalmTokens.background,
    );

    final textTheme =
        GoogleFonts.plusJakartaSansTextTheme(base.textTheme).apply(
      bodyColor: PalmTokens.textMain,
      displayColor: PalmTokens.textMain,
    );

    return base.copyWith(
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: PalmTokens.surface,
        foregroundColor: PalmTokens.textMain,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w800,
          color: PalmTokens.textMain,
        ),
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
      ),
      cardTheme: CardThemeData(
        color: PalmTokens.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(PalmTokens.radiusMd),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: Colors.black.withValues(alpha: 0.06),
        thickness: 1,
        space: 1,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return PalmTokens.primary.withValues(alpha: 0.35);
            }
            return PalmTokens.primary;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return PalmTokens.neutralDark.withValues(alpha: 0.55);
            }
            return PalmTokens.neutralDark;
          }),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          ),
          textStyle: WidgetStatePropertyAll(
            textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(PalmTokens.radiusMd),
            ),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: PalmTokens.textMain,
          side: BorderSide(color: Colors.black.withValues(alpha: 0.08)),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          textStyle:
              textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(PalmTokens.radiusMd),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.black.withValues(alpha: 0.03),
        hintStyle: textTheme.bodyLarge?.copyWith(color: PalmTokens.textSub),
        labelStyle: textTheme.bodyLarge?.copyWith(color: PalmTokens.textMain),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderSide: BorderSide.none,
          borderRadius: BorderRadius.circular(PalmTokens.radiusMd),
        ),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide.none,
          borderRadius: BorderRadius.circular(PalmTokens.radiusMd),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide:
              BorderSide(color: PalmTokens.primary.withValues(alpha: 0.7)),
          borderRadius: BorderRadius.circular(PalmTokens.radiusMd),
        ),
      ),
    );
  }
}
