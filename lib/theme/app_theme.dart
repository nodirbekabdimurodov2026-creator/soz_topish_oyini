import 'package:flutter/material.dart';

/// "So'z Bog'i" dizayn tizimi.
///
/// Maqsad: 10 yoshdan 100 yoshgacha bo'lgan foydalanuvchi uchun bir xil
/// yoqimli bo'lish - yumshoq, yuqori kontrast, dumaloq shakllar, ko'z
/// charchatmaydigan issiq fon. Progress metaforasi: gul o'sishi.
class AppColors {
  // Fon va sirt ranglari - issiq krem, ko'zga yumshoq
  static const Color background = Color(0xFFFFF8EC);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceMuted = Color(0xFFF3ECDD);

  // Asosiy palette
  static const Color primary = Color(0xFFFF6B6B); // korall-qizil
  static const Color primaryDark = Color(0xFFE85555);
  static const Color secondary = Color(0xFF4ECDC4); // turkuaz
  static const Color secondaryDark = Color(0xFF38B2A8);
  static const Color gold = Color(0xFFFFD93D); // tanga/mukofot
  static const Color goldDark = Color(0xFFE8BE1F);

  // Gul-bog' gradient (harf doirachalari, progress)
  static const Color leafLight = Color(0xFFA8E6CF);
  static const Color leafDark = Color(0xFF6FCF97);

  // Matn
  static const Color textPrimary = Color(0xFF2D3142);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textOnDark = Color(0xFFFFFFFF);

  // Holat ranglari
  static const Color success = Color(0xFF6FCF97);
  static const Color error = Color(0xFFFF6B6B);
  static const Color locked = Color(0xFFD8D2C2);

  static const LinearGradient letterCircleGradient = LinearGradient(
    colors: [leafLight, leafDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient selectedLetterGradient = LinearGradient(
    colors: [primary, primaryDark],
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
  /// Sarlavhalar uchun - yirik, dumaloq, do'stona.
  /// Tizimning standart shrifti (Roboto/SF) ishlatiladi - hech qanday
  /// qo'shimcha font fayli yoki internet bog'liqligi yo'q, bu build
  /// barqarorligi uchun ataylab qilingan tanlov.
  static TextStyle display({double size = 28, Color? color}) => TextStyle(
        fontSize: size,
        fontWeight: FontWeight.w800,
        color: color ?? AppColors.textPrimary,
        height: 1.15,
        letterSpacing: -0.3,
      );

  /// Tugma va asosiy interaktiv matn uchun.
  static TextStyle button({double size = 18, Color? color}) => TextStyle(
        fontSize: size,
        fontWeight: FontWeight.w700,
        color: color ?? AppColors.textOnDark,
        letterSpacing: 0.2,
      );

  /// Oddiy matn, izoh, body uchun.
  static TextStyle body({double size = 15, Color? color, FontWeight? weight}) =>
      TextStyle(
        fontSize: size,
        fontWeight: weight ?? FontWeight.w500,
        color: color ?? AppColors.textSecondary,
      );

  /// Harf doirachalaridagi katta harflar uchun.
  static TextStyle letter({double size = 24, Color? color}) => TextStyle(
        fontSize: size,
        fontWeight: FontWeight.w800,
        color: color ?? AppColors.textOnDark,
        letterSpacing: 0.5,
      );
}

class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;

  static const double radiusSm = 12;
  static const double radiusMd = 20;
  static const double radiusLg = 28;
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

/// Ilova bo'ylab ishlatiladigan soya (shadow) - yumshoq, "qog'oz ustida"
/// his beradigan, lekin og'ir emas.
List<BoxShadow> softShadow({double opacity = 0.08, double blur = 16}) => [
      BoxShadow(
        color: AppColors.textPrimary.withOpacity(opacity),
        blurRadius: blur,
        offset: const Offset(0, 6),
      ),
    ];
