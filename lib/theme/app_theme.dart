import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Klassik, professional dizayn tizimi - 20+ yosh auditoriya uchun.
/// Oq fon, to'q matn, minimal rangli urg'u. Ko'z charchamaydigan,
/// jiddiy va ishonchli ko'rinish.
class AppColors {
  static const Color background = Color(0xFFFFFFFF);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceMuted = Color(0xFFF2F3F5);

  // Yagona, jiddiy urg'u rangi - to'q ko'k-kulrang
  static const Color primary = Color(0xFF2B2D42);
  static const Color primaryDark = Color(0xFF1A1B2E);
  static const Color secondary = Color(0xFF4361EE);
  static const Color secondaryDark = Color(0xFF3A50C9);
  static const Color gold = Color(0xFFB8860B);
  static const Color goldDark = Color(0xFF9A6F09);

  static const Color leafLight = Color(0xFF6C7A89);
  static const Color leafDark = Color(0xFF4A5568);

  static const Color textPrimary = Color(0xFF1A1B2E);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textOnDark = Color(0xFFFFFFFF);

  static const Color success = Color(0xFF2D9D78);
  static const Color error = Color(0xFFD64545);
  static const Color locked = Color(0xFFE2E4E8);
  static const Color border = Color(0xFFE5E7EB);

  static const LinearGradient letterCircleGradient = LinearGradient(
    colors: [leafLight, leafDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient selectedLetterGradient = LinearGradient(
    colors: [secondary, secondaryDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient goldGradient = LinearGradient(
    colors: [gold, goldDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

class AppTypography {
  static TextStyle display({double size = 26, Color? color}) =>
      GoogleFonts.inter(
        fontSize: size,
        fontWeight: FontWeight.w700,
        color: color ?? AppColors.textPrimary,
        height: 1.15,
        letterSpacing: -0.5,
      );

  static TextStyle button({double size = 16, Color? color}) =>
      GoogleFonts.inter(
        fontSize: size,
        fontWeight: FontWeight.w600,
        color: color ?? AppColors.textOnDark,
      );

  static TextStyle body({double size = 14, Color? color, FontWeight? weight}) =>
      GoogleFonts.inter(
        fontSize: size,
        fontWeight: weight ?? FontWeight.w400,
        color: color ?? AppColors.textSecondary,
      );

  static TextStyle letter({double size = 22, Color? color}) =>
      GoogleFonts.inter(
        fontSize: size,
        fontWeight: FontWeight.w700,
        color: color ?? AppColors.textOnDark,
      );
}

class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;

  static const double radiusSm = 8;
  static const double radiusMd = 14;
  static const double radiusLg = 20;
  static const double radiusPill = 100;
}

class AppMotion {
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration normal = Duration(milliseconds: 300);
  static const Duration slow = Duration(milliseconds: 600);
  static const Duration celebration = Duration(milliseconds: 900);

  static const Curve bounce = Curves.elasticOut;
  static const Curve smooth = Curves.easeOutCubic;
  static const Curve snap = Curves.easeOutBack;
}

/// Yumshoq soya - oq fonda nozik chegara hissi beradi.
List<BoxShadow> softShadow({double opacity = 0.06, double blur = 12}) => [
      BoxShadow(
        color: AppColors.textPrimary.withOpacity(opacity),
        blurRadius: blur,
        offset: const Offset(0, 4),
      ),
    ];
