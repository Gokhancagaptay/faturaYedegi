// lib/core/constants/dashboard_constants.dart
import 'package:flutter/material.dart';

class DashboardConstants {
  // Responsive Breakpoints
  static const double mobileBreakpoint = 600;
  static const double tabletBreakpoint = 900;
  static const double desktopBreakpoint = 1200;

  // Responsive Spacing
  static double getResponsivePadding(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < mobileBreakpoint) return 16.0;
    if (width < tabletBreakpoint) return 20.0;
    if (width < desktopBreakpoint) return 24.0;
    return 32.0;
  }

  static double getResponsiveSpacing(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < mobileBreakpoint) return 16.0;
    if (width < tabletBreakpoint) return 20.0;
    if (width < desktopBreakpoint) return 24.0;
    return 32.0;
  }

  // Responsive Font Sizes
  static double getResponsiveFontSize(BuildContext context, double baseSize) {
    final width = MediaQuery.of(context).size.width;
    if (width < mobileBreakpoint) return baseSize * 0.9;
    if (width < tabletBreakpoint) return baseSize;
    if (width < desktopBreakpoint) return baseSize * 1.1;
    return baseSize * 1.2;
  }

  // Responsive Container Sizes
  static double getResponsiveContainerSize(
      BuildContext context, double baseSize) {
    final width = MediaQuery.of(context).size.width;
    if (width < mobileBreakpoint) return baseSize * 0.8;
    if (width < tabletBreakpoint) return baseSize;
    if (width < desktopBreakpoint) return baseSize * 1.1;
    return baseSize * 1.3;
  }

  // Theme Colors - Light Mode
  static const Color lightPrimaryBlue = Color(0xFF1E3A8A);
  static const Color lightBackground = Color(0xFFF3F4F6);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightText = Color(0xFF323232);
  static const Color lightTextSecondary = Color(0xFF6B7280);
  static const Color lightAccentAmber = Color(0xFFF59E0B);
  static const Color lightSuccessGreen = Color(0xFF10B981);
  static const Color lightErrorRed = Color(0xFFEF4444);
  static const Color lightWhite = Color(0xFFFFFFFF);

  // Theme Colors - Dark Mode
  static const Color darkPrimaryBlue = Color(0xFF3B82F6);
  static const Color darkBackground = Color(0xFF0F172A);
  static const Color darkSurface = Color(0xFF1E293B);
  static const Color darkSurfaceSecondary = Color(0xFF334155);
  static const Color darkText = Color(0xFFF8FAFC); // Daha açık beyaz
  static const Color darkTextSecondary = Color(0xFFCBD5E1); // Daha açık gri
  static const Color darkAccentAmber = Color(0xFFF59E0B);
  static const Color darkSuccessGreen = Color(0xFF10B981);
  static const Color darkErrorRed = Color(0xFFEF4444);
  static const Color darkWhite = Color(0xFFFFFFFF);

  // Border Radius
  static const double cardRadius = 12.0;
  static const double buttonRadius = 12.0;
  static const double imageRadius = 8.0;

  // Shadows
  static List<BoxShadow> getCardShadow(bool isDark) {
    return [
      BoxShadow(
        color: isDark
            ? Colors.black.withOpacity(0.3)
            : Colors.black.withOpacity(0.05),
        blurRadius: 8,
        offset: const Offset(0, 4),
      ),
    ];
  }

  static List<BoxShadow> getHeaderShadow(bool isDark) {
    return [
      BoxShadow(
        color: isDark
            ? Colors.black.withOpacity(0.4)
            : Colors.black.withOpacity(0.1),
        blurRadius: 20,
        offset: const Offset(0, 10),
      ),
    ];
  }

  // Get Colors for Theme
  static Map<String, dynamic> getColors(bool isDarkMode) {
    if (isDarkMode) {
      return {
        'primaryBlue': darkPrimaryBlue,
        'background': darkBackground,
        'surface': darkSurface,
        'text': darkText,
        'textSecondary': darkTextSecondary,
        'cardBackground': darkSurface,
        'accentAmber': darkAccentAmber,
        'successGreen': darkSuccessGreen,
        'errorRed': darkErrorRed,
        'white': darkWhite,
        'isDark': true,
      };
    } else {
      return {
        'primaryBlue': lightPrimaryBlue,
        'background': lightBackground,
        'surface': lightSurface,
        'text': lightText,
        'textSecondary': lightTextSecondary,
        'cardBackground': lightSurface,
        'accentAmber': lightAccentAmber,
        'successGreen': lightSuccessGreen,
        'errorRed': lightErrorRed,
        'white': lightWhite,
        'isDark': false,
      };
    }
  }
}
