import 'package:flutter/material.dart';

/// Utility class for responsive text sizing and spacing
class ResponsiveUtils {
  /// Get responsive font size based on screen width
  static double getResponsiveFontSize(BuildContext context, double baseSize) {
    final screenWidth = MediaQuery.of(context).size.width;

    // Breakpoints for different screen sizes
    if (screenWidth < 360) {
      // Small phones
      return baseSize * 0.75;
    } else if (screenWidth < 480) {
      // Medium phones
      return baseSize * 0.85;
    } else if (screenWidth < 768) {
      // Large phones/small tablets
      return baseSize * 0.9;
    } else if (screenWidth < 1024) {
      // Tablets
      return baseSize * 0.95;
    } else {
      // Desktop
      return baseSize;
    }
  }

  /// Get responsive padding based on screen width
  static EdgeInsets getResponsivePadding(
    BuildContext context, {
    double horizontal = 16,
    double vertical = 16,
  }) {
    final screenWidth = MediaQuery.of(context).size.width;
    final scale = screenWidth < 480
        ? 0.8
        : screenWidth < 768
        ? 0.9
        : 1.0;

    return EdgeInsets.symmetric(
      horizontal: horizontal * scale,
      vertical: vertical * scale,
    );
  }

  /// Get responsive spacing based on screen width
  static double getResponsiveSpacing(BuildContext context, double baseSpacing) {
    final screenWidth = MediaQuery.of(context).size.width;

    if (screenWidth < 360) {
      return baseSpacing * 0.7;
    } else if (screenWidth < 480) {
      return baseSpacing * 0.8;
    } else if (screenWidth < 768) {
      return baseSpacing * 0.9;
    } else {
      return baseSpacing;
    }
  }

  /// Check if device is mobile
  static bool isMobile(BuildContext context) {
    return MediaQuery.of(context).size.width < 768;
  }

  /// Check if device is tablet
  static bool isTablet(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= 768 && width < 1024;
  }

  /// Check if device is desktop
  static bool isDesktop(BuildContext context) {
    return MediaQuery.of(context).size.width >= 1024;
  }

  /// Get responsive icon size
  static double getResponsiveIconSize(BuildContext context, double baseSize) {
    final screenWidth = MediaQuery.of(context).size.width;

    if (screenWidth < 360) {
      return baseSize * 0.8;
    } else if (screenWidth < 480) {
      return baseSize * 0.9;
    } else {
      return baseSize;
    }
  }

  /// Get responsive card height
  static double getResponsiveCardHeight(
    BuildContext context,
    double baseHeight,
  ) {
    final screenWidth = MediaQuery.of(context).size.width;

    if (screenWidth < 360) {
      return baseHeight * 0.9;
    } else if (screenWidth < 480) {
      return baseHeight * 0.95;
    } else {
      return baseHeight;
    }
  }
}

/// Extension methods for responsive text
extension ResponsiveTextExtension on Text {
  /// Make text responsive
  Text responsive(BuildContext context) {
    final responsiveFontSize = ResponsiveUtils.getResponsiveFontSize(
      context,
      style?.fontSize ?? 14,
    );

    return Text(
      data!,
      key: key,
      style: (style ?? const TextStyle()).copyWith(
        fontSize: responsiveFontSize,
      ),
      strutStyle: strutStyle,
      textAlign: textAlign,
      textDirection: textDirection,
      locale: locale,
      softWrap: softWrap,
      overflow: overflow,
      textScaler: const TextScaler.linear(1.0), // Disable system text scaling
      maxLines: maxLines,
      semanticsLabel: semanticsLabel,
      textWidthBasis: textWidthBasis,
      textHeightBehavior: textHeightBehavior,
      selectionColor: selectionColor,
    );
  }
}

/// Responsive text widget
class ResponsiveText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;

  const ResponsiveText(
    this.text, {
    super.key,
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
  });

  @override
  Widget build(BuildContext context) {
    final responsiveFontSize = ResponsiveUtils.getResponsiveFontSize(
      context,
      style?.fontSize ?? 14,
    );

    return Text(
      text,
      style: (style ?? const TextStyle()).copyWith(
        fontSize: responsiveFontSize,
      ),
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
      textScaler: const TextScaler.linear(1.0), // Disable system text scaling
    );
  }
}
