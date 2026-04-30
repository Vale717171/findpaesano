import 'package:flutter/material.dart';

class AppTheme {
  static const Color warmPaper = Color(0xFFFFF8EC);
  static const Color travelBlue = Color(0xFF256D85);
  static const Color terracotta = Color(0xFFD97845);
  static const Color postcardYellow = Color(0xFFF2C14E);
  static const Color sageGreen = Color(0xFF5B8C6A);
  static const Color mutedRed = Color(0xFFB94E48);
  static const Color ink = Color(0xFF2B2B2B);
  static const Color mutedInk = Color(0xFF6F6A61);
  static const Color warmGray = Color(0xFFB4A796);

  static const double radiusSm = 12;
  static const double radiusMd = 18;
  static const double radiusLg = 24;
  static const EdgeInsets screenPadding = EdgeInsets.all(20);

  static Color categoryColor(String label) {
    switch (label) {
      case 'Food':
        return terracotta;
      case 'Places':
        return sageGreen;
      case 'Transport':
        return travelBlue;
      case 'Warning':
        return mutedRed;
      default:
        return const Color(0xFF8F7E68);
    }
  }

  static String categoryDescription(String label) {
    switch (label) {
      case 'Food':
        return 'Where to eat without surrendering your wallet.';
      case 'Transport':
        return 'Tickets, transfers and the ancient mysteries of local buses.';
      case 'Places':
        return 'The city between the postcards.';
      case 'Warning':
        return 'Small traps, odd rules and things locals learn the hard way.';
      default:
        return 'Tiny wisdom that refuses to fit in a box.';
    }
  }

  static ThemeData lightTheme() {
    const scheme = ColorScheme(
      brightness: Brightness.light,
      primary: travelBlue,
      onPrimary: Colors.white,
      secondary: terracotta,
      onSecondary: Colors.white,
      error: mutedRed,
      onError: Colors.white,
      surface: Color(0xFFFFFCF6),
      onSurface: ink,
      surfaceContainerHighest: Color(0xFFF5E9D8),
      onSurfaceVariant: mutedInk,
      outline: Color(0xFFD7C8B6),
      outlineVariant: Color(0xFFE9DDCF),
      shadow: Color(0x1F000000),
      scrim: Color(0x33000000),
      inverseSurface: Color(0xFF2F3437),
      onInverseSurface: Color(0xFFF7F1E8),
      inversePrimary: Color(0xFF8EC4D3),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: warmPaper,
      canvasColor: warmPaper,
      cardColor: const Color(0xFFFFFCF6),
      dividerColor: const Color(0xFFE7D8C7),
      appBarTheme: const AppBarTheme(
        backgroundColor: warmPaper,
        foregroundColor: ink,
        elevation: 0,
        centerTitle: false,
        scrolledUnderElevation: 0,
        titleTextStyle: TextStyle(
          color: ink,
          fontSize: 22,
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: const Color(0xFFFFFBF4),
        indicatorColor: travelBlue.withValues(alpha: 0.14),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontSize: 12,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
            color: states.contains(WidgetState.selected) ? ink : mutedInk,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected) ? travelBlue : mutedInk,
          ),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: terracotta,
        foregroundColor: Colors.white,
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFFFFFCF6),
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          side: const BorderSide(color: Color(0xFFE8DAC8)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFFFFCF7),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        hintStyle: const TextStyle(color: mutedInk),
        labelStyle: const TextStyle(color: mutedInk),
        prefixIconColor: travelBlue,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSm),
          borderSide: const BorderSide(color: Color(0xFFD8C8B8)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSm),
          borderSide: const BorderSide(color: Color(0xFFD8C8B8)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSm),
          borderSide: const BorderSide(color: travelBlue, width: 1.6),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: ink,
        contentTextStyle: const TextStyle(color: Colors.white),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusSm),
        ),
        behavior: SnackBarBehavior.floating,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: const Color(0xFFF8EFE1),
        side: const BorderSide(color: Color(0xFFE4D2BC)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
        ),
        labelStyle: const TextStyle(color: ink),
      ),
      tabBarTheme: const TabBarThemeData(
        labelColor: travelBlue,
        unselectedLabelColor: mutedInk,
        indicatorColor: travelBlue,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Color(0xFFFFFCF6),
        modalBackgroundColor: Color(0xFFFFFCF6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(radiusLg)),
        ),
      ),
    );
  }

  static ThemeData darkTheme() {
    const scheme = ColorScheme(
      brightness: Brightness.dark,
      primary: Color(0xFF79AFC0),
      onPrimary: Color(0xFF102A34),
      secondary: Color(0xFFE39B73),
      onSecondary: Color(0xFF341B10),
      error: Color(0xFFE18A85),
      onError: Color(0xFF3D1512),
      surface: Color(0xFF181A1C),
      onSurface: Color(0xFFF1ECE4),
      surfaceContainerHighest: Color(0xFF2A2D30),
      onSurfaceVariant: Color(0xFFC9C0B6),
      outline: Color(0xFF5D5853),
      outlineVariant: Color(0xFF3E4347),
      shadow: Colors.black,
      scrim: Colors.black,
      inverseSurface: Color(0xFFF1ECE4),
      onInverseSurface: Color(0xFF1A1C1E),
      inversePrimary: travelBlue,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: const Color(0xFF121416),
      canvasColor: const Color(0xFF121416),
      cardColor: const Color(0xFF1A1D20),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF121416),
        foregroundColor: Color(0xFFF1ECE4),
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: const Color(0xFF171A1C),
        indicatorColor: const Color(0xFF2B4450),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: terracotta,
        foregroundColor: Colors.white,
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFF1A1D20),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          side: const BorderSide(color: Color(0xFF31363A)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF1D2124),
        hintStyle: const TextStyle(color: Color(0xFFC9C0B6)),
        labelStyle: const TextStyle(color: Color(0xFFC9C0B6)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSm),
          borderSide: const BorderSide(color: Color(0xFF40464B)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSm),
          borderSide: const BorderSide(color: Color(0xFF40464B)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSm),
          borderSide: const BorderSide(color: Color(0xFF79AFC0), width: 1.5),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Color(0xFF181B1E),
        modalBackgroundColor: Color(0xFF181B1E),
      ),
    );
  }

  static BoxDecoration paperCardDecoration(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return BoxDecoration(
      color: isDark ? const Color(0xFF1A1D20) : const Color(0xFFFFFCF6),
      borderRadius: BorderRadius.circular(radiusMd),
      border: Border.all(
        color: isDark ? const Color(0xFF31363A) : const Color(0xFFE8DAC8),
      ),
      boxShadow: isDark
          ? const []
          : [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
    );
  }

  static BoxDecoration tintedPanel(
    BuildContext context, {
    required Color accent,
    double tint = 0.08,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return BoxDecoration(
      color: isDark
          ? accent.withValues(alpha: 0.14)
          : accent.withValues(alpha: tint),
      borderRadius: BorderRadius.circular(radiusMd),
      border: Border.all(
        color: accent.withValues(alpha: isDark ? 0.32 : 0.18),
      ),
    );
  }
}
