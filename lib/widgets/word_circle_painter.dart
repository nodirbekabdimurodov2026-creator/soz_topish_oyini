import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../utils/circle_layout_helper.dart';

/// Aylanadagi harflarni, ular orasidagi ulanish chiziqlarini va
/// barmoq harakatini chizuvchi CustomPainter.
///
/// Rang sxemasi AppColors dizayn tizimidan olinadi - "So'z Bog'i" temasi:
/// harf doirachalari yashil-bog' gradienti, tanlangan harflar korall-qizil,
/// ulanish chizig'i esa iliq oltin rangda.
class WordCirclePainter extends CustomPainter {
  final List<String> letters;
  final List<int> selectedIndices;
  final Offset? currentDragPosition;
  final int? hintLetterIndex;

  WordCirclePainter({
    required this.letters,
    required this.selectedIndices,
    this.currentDragPosition,
    this.hintLetterIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (letters.isEmpty) return;

    final layout = CircleLayoutHelper(size: size, letterCount: letters.length);

    _drawConnectionLines(canvas, layout);
    _drawDragTail(canvas, layout);
    _drawLetterCircles(canvas, layout);
  }

  /// Tanlangan harflar orasidagi chiziqlarni chizadi (smooth, soyali chiziq).
  void _drawConnectionLines(Canvas canvas, CircleLayoutHelper layout) {
    if (selectedIndices.length < 2) return;

    final linePaint = Paint()
      ..color = AppColors.gold.withOpacity(0.9)
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5);

    final path = Path();
    final firstPos = layout.positionFor(selectedIndices.first);
    path.moveTo(firstPos.dx, firstPos.dy);

    for (int i = 1; i < selectedIndices.length; i++) {
      final pos = layout.positionFor(selectedIndices[i]);
      path.lineTo(pos.dx, pos.dy);
    }
    canvas.drawPath(path, linePaint);

    final highlightPaint = Paint()
      ..color = Colors.white.withOpacity(0.6)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawPath(path, highlightPaint);
  }

  /// Barmoq hozirgi pozitsiyasidan oxirgi tanlangan harfgacha "dum" chizig'i.
  void _drawDragTail(Canvas canvas, CircleLayoutHelper layout) {
    if (selectedIndices.isEmpty || currentDragPosition == null) return;

    final lastPos = layout.positionFor(selectedIndices.last);
    final tailPaint = Paint()
      ..color = AppColors.gold.withOpacity(0.5)
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    canvas.drawLine(lastPos, currentDragPosition!, tailPaint);
  }

  /// Har bir harfni doirachada chizadi (tanlangan/hint holatlarini hisobga olib).
  void _drawLetterCircles(Canvas canvas, CircleLayoutHelper layout) {
    for (int i = 0; i < letters.length; i++) {
      final pos = layout.positionFor(i);
      final isSelected = selectedIndices.contains(i);
      final isHint = hintLetterIndex == i;

      final List<Color> gradientColors = isSelected
          ? [AppColors.primary, AppColors.primaryDark]
          : isHint
              ? [AppColors.gold, AppColors.goldDark]
              : [AppColors.leafLight, AppColors.leafDark];

      final circlePaint = Paint()
        ..style = PaintingStyle.fill
        ..shader = LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(
          Rect.fromCircle(center: pos, radius: layout.letterRadius),
        );

      // Yumshoq soya - "qog'oz ustida" his
      canvas.drawCircle(
        pos.translate(0, isSelected ? 2 : 4),
        layout.letterRadius,
        Paint()..color = AppColors.textPrimary.withOpacity(isSelected ? 0.12 : 0.18),
      );

      canvas.drawCircle(pos, layout.letterRadius, circlePaint);

      final borderPaint = Paint()
        ..color = isSelected ? Colors.white.withOpacity(0.95) : Colors.white.withOpacity(0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = isSelected ? 3 : 2;
      canvas.drawCircle(pos, layout.letterRadius, borderPaint);

      final textPainter = TextPainter(
        text: TextSpan(
          text: letters[i],
          style: AppTypography.letter(size: letters[i].length > 1 ? 18 : 22),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      final textOffset = Offset(
        pos.dx - textPainter.width / 2,
        pos.dy - textPainter.height / 2,
      );
      textPainter.paint(canvas, textOffset);
    }
  }

  @override
  bool shouldRepaint(covariant WordCirclePainter oldDelegate) {
    return oldDelegate.letters != letters ||
        oldDelegate.selectedIndices != selectedIndices ||
        oldDelegate.currentDragPosition != currentDragPosition ||
        oldDelegate.hintLetterIndex != hintLetterIndex;
  }
}

