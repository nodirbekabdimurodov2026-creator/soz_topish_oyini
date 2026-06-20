import 'package:flutter/material.dart';
import '../utils/circle_layout_helper.dart';

/// Aylanadagi harflarni, ular orasidagi ulanish chiziqlarini va
/// barmoq harakatini chizuvchi CustomPainter.
///
/// `repaint` uchun Listenable berilmaydi - GameScreen GestureDetector
/// state o'zgarganda setState/Provider orqali qayta chizilishini
/// ta'minlaydi (ConsumerWidget/Provider.of orqali rebuild).
class WordCirclePainter extends CustomPainter {
  final List<String> letters;
  final List<int> selectedIndices;
  final Offset? currentDragPosition; // barmoq hozir turgan joy (erkin chizish uchun)
  final int? hintLetterIndex; // "Yordam" bosilganda yoritiladigan harf
  final Color baseColor;
  final Color selectedColor;
  final Color lineColor;
  final Color hintColor;

  WordCirclePainter({
    required this.letters,
    required this.selectedIndices,
    this.currentDragPosition,
    this.hintLetterIndex,
    this.baseColor = const Color(0xFF2D2F45),
    this.selectedColor = const Color(0xFF6C5CE7),
    this.lineColor = const Color(0xFFFFA502),
    this.hintColor = const Color(0xFFFFD700),
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
      ..color = lineColor.withOpacity(0.85)
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

    // Chiziq ustiga ingichka oq chiziq - "neon" effekti uchun
    final highlightPaint = Paint()
      ..color = Colors.white.withOpacity(0.5)
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
      ..color = lineColor.withOpacity(0.5)
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

      final circlePaint = Paint()
        ..style = PaintingStyle.fill
        ..shader = RadialGradient(
          colors: isSelected
              ? [selectedColor, selectedColor.withOpacity(0.8)]
              : isHint
                  ? [hintColor, hintColor.withOpacity(0.7)]
                  : [baseColor.withOpacity(0.95), baseColor],
          center: Alignment.topLeft,
          radius: 1.2,
        ).createShader(
          Rect.fromCircle(center: pos, radius: layout.letterRadius),
        );

      // Soya
      canvas.drawCircle(
        pos.translate(0, 3),
        layout.letterRadius,
        Paint()..color = Colors.black.withOpacity(0.25),
      );

      canvas.drawCircle(pos, layout.letterRadius, circlePaint);

      // Chegara chizig'i
      final borderPaint = Paint()
        ..color = isSelected
            ? Colors.white.withOpacity(0.9)
            : Colors.white.withOpacity(0.08)
        ..style = PaintingStyle.stroke
        ..strokeWidth = isSelected ? 2.5 : 1.5;
      canvas.drawCircle(pos, layout.letterRadius, borderPaint);

      // Harf matni
      final textPainter = TextPainter(
        text: TextSpan(
          text: letters[i],
          style: TextStyle(
            color: Colors.white,
            fontSize: letters[i].length > 1 ? 18 : 22,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
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
