import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Daraja muvaffaqiyatli tugaganda ko'rsatiladigan "gul ochilishi" animatsiyasi.
///
/// Bu o'yinning vizual imzosi: progress = o'sish metaforasi. Yopiq filiz
/// holatidan boshlanib, gul barglari ochilib, atrofida zarrachalar
/// (konfetti emas, kichik bargchalar) tarqaladi - bog'/tabiat temasiga mos.
class FlowerCelebrationOverlay extends StatefulWidget {
  final int starsEarned;
  final VoidCallback onContinue;
  final VoidCallback? onNextLevel;

  const FlowerCelebrationOverlay({
    super.key,
    required this.starsEarned,
    required this.onContinue,
    this.onNextLevel,
  });

  @override
  State<FlowerCelebrationOverlay> createState() =>
      _FlowerCelebrationOverlayState();
}

class _FlowerCelebrationOverlayState extends State<FlowerCelebrationOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppMotion.celebration,
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withOpacity(0.6),
      child: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final bloom = Curves.elasticOut.transform(
              _controller.value.clamp(0.0, 1.0),
            );
            return Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                ..._buildPetalBurst(bloom),
                _buildCard(bloom),
              ],
            );
          },
        ),
      ),
    );
  }

  List<Widget> _buildPetalBurst(double bloom) {
    const petalCount = 8;
    return List.generate(petalCount, (i) {
      final angle = (2 * math.pi / petalCount) * i;
      final distance = 110 * bloom;
      final dx = math.cos(angle) * distance;
      final dy = math.sin(angle) * distance;
      return Transform.translate(
        offset: Offset(dx, dy),
        child: Opacity(
          opacity: (1 - bloom).clamp(0.0, 1.0) < 0.05
              ? 0
              : (bloom).clamp(0.0, 1.0),
          child: Icon(
            Icons.star_rounded,
            size: 16 + (10 * bloom),
            color: AppColors.gold,
          ),
        ),
      );
    });
  }

  Widget _buildCard(double bloom) {
    return Transform.scale(
      scale: 0.6 + (0.4 * bloom),
      child: Container(
        width: 280,
        padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.lg,
          horizontal: AppSpacing.lg,
        ),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          boxShadow: softShadow(opacity: 0.25, blur: 30),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.success.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_rounded, color: AppColors.success, size: 36),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text("Daraja yakunlandi!", style: AppTypography.display(size: 20)),
            const SizedBox(height: AppSpacing.md),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(3, (i) {
                final filled = i < widget.starsEarned;
                return Icon(
                  Icons.star_rounded,
                  size: 36,
                  color: filled ? AppColors.gold : AppColors.surfaceMuted,
                );
              }),
            ),
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
                  ),
                  elevation: 0,
                ),
                onPressed: widget.onNextLevel ?? widget.onContinue,
                child: Text(
                  widget.onNextLevel != null
                      ? "Keyingi daraja"
                      : "Davom etish",
                  style: AppTypography.button(),
                ),
              ),
            ),
            if (widget.onNextLevel != null) ...[
              const SizedBox(height: AppSpacing.xs),
              TextButton(
                onPressed: widget.onContinue,
                child: Text(
                  "Darajalar ro'yxatiga qaytish",
                  style: AppTypography.body(size: 13),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
