import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Harflarni aylana shaklida joylashtirish uchun geometrik hisob-kitoblar.
///
/// CustomPainter va GestureDetector ikkisi ham bitta koordinata manbasidan
/// foydalanishi kerak, shu sababli bu klass markaziy "single source of truth"
/// vazifasini bajaradi.
class CircleLayoutHelper {
  final Size size;
  final int letterCount;
  final double letterRadius; // har bir harf doirachasining radiusi

  CircleLayoutHelper({
    required this.size,
    required this.letterCount,
    this.letterRadius = 28,
  });

  Offset get center => Offset(size.width / 2, size.height / 2);

  /// Harflar joylashadigan asosiy aylananing radiusi.
  double get ringRadius {
    final shortestSide = math.min(size.width, size.height);
    return (shortestSide / 2) - letterRadius - 8;
  }

  /// i-indeksdagi harfning markaz koordinatasi.
  Offset positionFor(int index) {
    final angleStep = (2 * math.pi) / letterCount;
    // -pi/2 dan boshlanishi - birinchi harf tepada joylashishi uchun
    final angle = -math.pi / 2 + (angleStep * index);
    final dx = center.dx + ringRadius * math.cos(angle);
    final dy = center.dy + ringRadius * math.sin(angle);
    return Offset(dx, dy);
  }

  /// Berilgan global nuqta qaysi harf doirachasi ichida turganini topadi.
  /// Topilmasa null qaytaradi.
  int? hitTest(Offset point) {
    for (int i = 0; i < letterCount; i++) {
      final pos = positionFor(i);
      final distance = (point - pos).distance;
      if (distance <= letterRadius + 6) {
        return i;
      }
    }
    return null;
  }
}
