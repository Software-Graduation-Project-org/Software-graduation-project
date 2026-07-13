import 'package:flutter/material.dart';

class AppTheme {
  // Medical Lab Color Scheme - Lighter Blues & Professional Medical Colors
  static const Color primaryBlue = Color(0xFF4A90E2); // Light medical blue
  static const Color primaryLightBlue = Color(0xFF7BC9FF); // Very light blue
  static const Color secondaryTeal = Color(0xFF5AC8FA); // Light teal
  static const Color accentMint = Color(0xFF7DD3FC); // Mint accent
  static const Color accentOrange = Color(0xFFFFB347); // Soft orange for alerts
  static const Color accentCoral = Color(0xFFFF8A80); // Soft coral for urgent
  static const Color backgroundColor = Color(
    0xFFF8FBFF,
  ); // Very light blue-gray
  static const Color surfaceColor = Color(0xFFFFFFFF); // Pure white
  static const Color cardColor = Color(0xFFFEFEFE); // Off-white
  static const Color textDark = Color(0xFF1E293B); // Dark slate
  static const Color textMedium = Color(0xFF64748B); // Medium gray
  static const Color textLight = Color(0xFF94A3B8); // Light gray
  static const Color successGreen = Color(0xFF10B981); // Medical green
  static const Color successLight = Color(0xFFD1FAE5); // Light green
  static const Color warningYellow = Color(0xFFF59E0B); // Medical amber
  static const Color warningLight = Color(0xFFFEF3C7); // Light yellow
  static const Color errorRed = Color(0xFFEF4444); // Medical red
  static const Color errorLight = Color(0xFFFEE2E2); // Light red
  static const Color dividerColor = Color(0xFFE2E8F0); // Light blue-gray
  static const Color borderColor = Color(0xFFCBD5E1); // Soft border

  // Medical Status Colors
  static const Color inProgressColor = Color(
    0xFF3B82F6,
  ); // Blue for in progress
  static const Color completedColor = Color(0xFF10B981); // Green for completed
  static const Color pendingColor = Color(0xFFF59E0B); // Amber for pending

  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.light(
      primary: primaryBlue,
      secondary: secondaryTeal,
      tertiary: accentMint,
      surface: surfaceColor,
      error: errorRed,
      onPrimary: Colors.white,
      onSecondary: textDark,
      onSurface: textDark,
      onError: Colors.white,
    ),
    scaffoldBackgroundColor: backgroundColor,

    // AppBar Theme - Medical professional
    appBarTheme: AppBarTheme(
      elevation: 0,
      centerTitle: false,
      backgroundColor: surfaceColor,
      foregroundColor: textDark,
      iconTheme: IconThemeData(color: textDark),
      titleTextStyle: TextStyle(
        color: textDark,
        fontSize: 20,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.5,
      ),
      shadowColor: Colors.transparent,
    ),

    // Card Theme - Medical cards
    cardTheme: CardThemeData(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: cardColor,
      margin: const EdgeInsets.all(8),
      shadowColor: Colors.black.withValues(alpha: 0.04),
    ),

    // Elevated Button Theme - Medical buttons
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryBlue,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 0,
        shadowColor: primaryBlue.withValues(alpha: 0.3),
        textStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    ),

    // Text Button Theme
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: primaryBlue,
        textStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    ),

    // Input Decoration Theme - Medical professional styling
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surfaceColor,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: borderColor, width: 1.5),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: borderColor, width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: primaryBlue, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: errorRed, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: errorRed, width: 2),
      ),
      labelStyle: TextStyle(
        color: textMedium,
        fontSize: 16,
        fontWeight: FontWeight.w500,
      ),
      hintStyle: TextStyle(
        color: textLight,
        fontSize: 14,
        fontWeight: FontWeight.w400,
      ),
      errorStyle: TextStyle(
        color: errorRed,
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
      floatingLabelStyle: TextStyle(
        color: primaryBlue,
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
      prefixIconColor: textMedium,
      suffixIconColor: textMedium,
    ),

    // Text Theme - Medical professional typography
    textTheme: TextTheme(
      displayLarge: TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.w800,
        color: textDark,
        letterSpacing: -0.5,
        height: 1.2,
      ),
      displayMedium: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        color: textDark,
        letterSpacing: -0.25,
        height: 1.3,
      ),
      displaySmall: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: textDark,
        letterSpacing: 0,
        height: 1.4,
      ),
      headlineLarge: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        color: textDark,
        letterSpacing: 0,
        height: 1.4,
      ),
      headlineMedium: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: textDark,
        letterSpacing: 0.15,
        height: 1.4,
      ),
      titleLarge: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: textDark,
        letterSpacing: 0.15,
        height: 1.4,
      ),
      titleMedium: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: textDark,
        letterSpacing: 0.15,
        height: 1.5,
      ),
      bodyLarge: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: textMedium,
        letterSpacing: 0.5,
        height: 1.5,
      ),
      bodyMedium: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: textMedium,
        letterSpacing: 0.25,
        height: 1.5,
      ),
      bodySmall: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: textLight,
        letterSpacing: 0.4,
        height: 1.5,
      ),
      labelLarge: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: textDark,
        letterSpacing: 0.1,
        height: 1.4,
      ),
      labelMedium: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: textMedium,
        letterSpacing: 0.5,
        height: 1.4,
      ),
      labelSmall: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: textLight,
        letterSpacing: 0.5,
        height: 1.4,
      ),
    ),

    // Chip Theme - Medical status chips
    chipTheme: ChipThemeData(
      backgroundColor: surfaceColor,
      disabledColor: dividerColor,
      selectedColor: primaryBlue.withValues(alpha: 0.1),
      secondarySelectedColor: secondaryTeal.withValues(alpha: 0.1),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      labelStyle: TextStyle(
        color: textDark,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
      secondaryLabelStyle: TextStyle(
        color: primaryBlue,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
      brightness: Brightness.light,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: borderColor),
      ),
    ),

    // Floating Action Button Theme - Medical FAB
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: primaryBlue,
      foregroundColor: Colors.white,
      elevation: 6,
      focusElevation: 8,
      hoverElevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
  );

  // Gradient for hero sections - Medical themed
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primaryBlue, primaryLightBlue, secondaryTeal],
    stops: [0.0, 0.5, 1.0],
  );

  // Medical card gradients
  static const LinearGradient successGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [successGreen, Color(0xFF34D399)],
  );

  static const LinearGradient warningGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [warningYellow, Color(0xFFFCD34D)],
  );

  static const LinearGradient errorGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [errorRed, Color(0xFFF87171)],
  );

  // Status specific gradients
  static const LinearGradient inProgressGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [inProgressColor, primaryLightBlue],
  );

  static const LinearGradient completedGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [completedColor, Color(0xFF34D399)],
  );

  // Utility methods for medical-themed widgets
  static BoxDecoration medicalCardDecoration({
    LinearGradient? gradient,
    double borderRadius = 16,
    bool withShadow = true,
  }) {
    return BoxDecoration(
      gradient: gradient,
      color: gradient == null ? cardColor : null,
      borderRadius: BorderRadius.circular(borderRadius),
      boxShadow: withShadow ? cardShadow : null,
      border: Border.all(color: borderColor.withValues(alpha: 0.5), width: 1),
    );
  }

  static BoxDecoration statusCardDecoration(String status) {
    LinearGradient gradient;
    switch (status.toLowerCase()) {
      case 'completed':
        gradient = completedGradient;
        break;
      case 'in_progress':
      case 'in progress':
        gradient = inProgressGradient;
        break;
      case 'pending':
        gradient = warningGradient;
        break;
      default:
        gradient = primaryGradient;
    }
    return medicalCardDecoration(gradient: gradient);
  }

  static TextStyle medicalTextStyle({
    double fontSize = 14,
    FontWeight fontWeight = FontWeight.w400,
    Color? color,
    double letterSpacing = 0.25,
  }) {
    return TextStyle(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color ?? textDark,
      letterSpacing: letterSpacing,
      height: 1.5,
    );
  }

  static ButtonStyle medicalButtonStyle({
    Color? backgroundColor,
    Color? foregroundColor,
    double borderRadius = 12,
  }) {
    return ElevatedButton.styleFrom(
      backgroundColor: backgroundColor ?? primaryBlue,
      foregroundColor: foregroundColor ?? Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      elevation: 0,
      shadowColor: (backgroundColor ?? primaryBlue).withValues(alpha: 0.3),
      textStyle: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
      ),
    );
  }

  // Box shadows
  static List<BoxShadow> cardShadow = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.08),
      blurRadius: 10,
      offset: const Offset(0, 4),
    ),
  ];

  static List<BoxShadow> elevatedShadow = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.12),
      blurRadius: 20,
      offset: const Offset(0, 8),
    ),
  ];
}
