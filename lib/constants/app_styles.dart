import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppStyles {
  static const List<String> _fallbacks = ['Segoe UI', 'Roboto', 'Helvetica Neue', 'Arial', 'sans-serif'];

  static TextStyle logoBlack({double fontSize = 24}) {
    try {
      return GoogleFonts.poppins(
        fontSize: fontSize,
        fontWeight: FontWeight.w800,
        color: AppColors.textPrimary,
        letterSpacing: -0.5,
      );
    } catch (_) {
      return TextStyle(
        fontSize: fontSize,
        fontWeight: FontWeight.w800,
        color: AppColors.textPrimary,
        letterSpacing: -0.5,
        fontFamilyFallback: _fallbacks,
      );
    }
  }

  static TextStyle logoOrange({double fontSize = 24}) {
    try {
      return GoogleFonts.poppins(
        fontSize: fontSize,
        fontWeight: FontWeight.w800,
        color: AppColors.primaryOrange,
        letterSpacing: -0.5,
      );
    } catch (_) {
      return TextStyle(
        fontSize: fontSize,
        fontWeight: FontWeight.w800,
        color: AppColors.primaryOrange,
        letterSpacing: -0.5,
        fontFamilyFallback: _fallbacks,
      );
    }
  }

  static TextStyle get headingLarge {
    try {
      return GoogleFonts.poppins(
        fontSize: 26,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
        letterSpacing: -0.4,
      );
    } catch (_) {
      return const TextStyle(
        fontSize: 26,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
        letterSpacing: -0.4,
        fontFamilyFallback: _fallbacks,
      );
    }
  }

  static TextStyle get subtitle {
    try {
      return GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: AppColors.textSecondary,
        height: 1.45,
      );
    } catch (_) {
      return const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: AppColors.textSecondary,
        height: 1.45,
        fontFamilyFallback: _fallbacks,
      );
    }
  }

  static TextStyle get buttonText {
    try {
      return GoogleFonts.poppins(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: Colors.white,
        letterSpacing: 0.2,
      );
    } catch (_) {
      return const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: Colors.white,
        letterSpacing: 0.2,
        fontFamilyFallback: _fallbacks,
      );
    }
  }

  static TextStyle get socialButtonText {
    try {
      return GoogleFonts.poppins(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      );
    } catch (_) {
      return const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
        fontFamilyFallback: _fallbacks,
      );
    }
  }

  static TextStyle get inputText {
    try {
      return GoogleFonts.inter(
        fontSize: 15,
        fontWeight: FontWeight.w500,
        color: AppColors.textPrimary,
      );
    } catch (_) {
      return const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w500,
        color: AppColors.textPrimary,
        fontFamilyFallback: _fallbacks,
      );
    }
  }

  static TextStyle get inputHint {
    try {
      return GoogleFonts.inter(
        fontSize: 15,
        fontWeight: FontWeight.w400,
        color: AppColors.textMuted,
      );
    } catch (_) {
      return const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w400,
        color: AppColors.textMuted,
        fontFamilyFallback: _fallbacks,
      );
    }
  }

  static TextStyle get linkText {
    try {
      return GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: AppColors.linkOrange,
      );
    } catch (_) {
      return const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: AppColors.linkOrange,
        fontFamilyFallback: _fallbacks,
      );
    }
  }

  static TextStyle get linkTextBold {
    try {
      return GoogleFonts.poppins(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      );
    } catch (_) {
      return const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
        fontFamilyFallback: _fallbacks,
      );
    }
  }

  static const BoxDecoration cardDecoration = BoxDecoration(
    color: AppColors.cardBackground,
    borderRadius: BorderRadius.only(
      topLeft: Radius.circular(32),
      topRight: Radius.circular(32),
    ),
    boxShadow: [
      BoxShadow(
        color: Color(0x14000000),
        blurRadius: 20,
        offset: Offset(0, -6),
      ),
    ],
  );
}
