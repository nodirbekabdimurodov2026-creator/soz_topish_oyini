import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/alphabet_mode.dart';
import '../models/level_model.dart';
import '../providers/game_provider.dart';
import '../theme/app_theme.dart';
import '../utils/circle_layout_helper.dart';
import '../widgets/flower_celebration_overlay.dart';
import '../widgets/word_circle_painter.dart';
import '../widgets/word_grid_panel.dart';

/// O'yinning asosiy ekrani - "So'z Bog'i" dizayn tizimi bilan.
///
/// Tuzilma: yuqorida header (orqaga, daraja, alifbo, tangalar),
/// o'rtada krossvord paneli, pastda harflar aylanasi va yordam tugmasi.
/// Daraja tugaganda gul-ochilish celebration overlay chiqadi.
class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen>
    with SingleTickerProviderStateMixin {
  Offset? _dragPosition;
  int? _hintLetterIndex;
  bool _showCelebration = false;
  int _celebrationStars = 0;

  @override
  Widget build(BuildContext context) {
    return Consumer<GameProvider>(
      builder: (context, game, _) {
        if (game.isLoading || game.currentLevel == null) {
          return Scaffold(
            backgroundColor: AppColors.background,
            body: const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
          );
        }

        if (game.lastMessage != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (game.lastMessage == null) return;
            final wasLevelComplete = game.lastMessage!.contains("yakunlandi");
            _showSnack(game.lastMessage!, isError: !game.isLastWordCorrect);
            game.clearMessage();

            if (wasLevelComplete && !_showCelebration) {
              setState(() {
                _showCelebration = true;
                _celebrationStars = game.currentProgress?.starsEarned ?? 3;
              });
            }
          });
        }

        final level = game.currentLevel!;
        final progress = game.currentProgress;
        final foundWords = progress?.foundWords ?? [];

        return Scaffold(
          backgroundColor: AppColors.background,
          body: SafeArea(
            child: Stack(
              children: [
                Column(
                  children: [
                    _buildHeader(context, game, level),
                    const SizedBox(height: AppSpacing.sm),
                    Expanded(
                      flex: 4,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                        child: SingleChildScrollView(
                          child: WordGridPanel(
                            allWords: level.validWords,
                            foundWords: foundWords,
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 5,
                      child: _buildLetterCircle(context, game, level),
                    ),
                    _buildHintButton(context, game),
                    const SizedBox(height: AppSpacing.md),
                  ],
                ),
                if (_showCelebration)
                  FlowerCelebrationOverlay(
                    starsEarned: _celebrationStars,
                    onContinue: () {
                      setState(() => _showCelebration = false);
                      Navigator.of(context).maybePop();
                    },
                    onNextLevel: () {
                      setState(() => _showCelebration = false);
                      final nextLevel = game.levels.firstWhere(
                        (l) => l.levelNumber == level.levelNumber + 1,
                        orElse: () => level,
                      );
                      if (nextLevel.id != level.id) {
                        game.selectLevel(nextLevel);
                      }
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showSnack(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          textAlign: TextAlign.center,
          style: AppTypography.body(size: 14, color: Colors.white, weight: FontWeight.w700),
        ),
        backgroundColor: isError ? AppColors.error : AppColors.leafDark,
        duration: const Duration(milliseconds: 1100),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        ),
        margin: const EdgeInsets.all(AppSpacing.md),
      ),
    );
  }

  // -----------------------------------------------------------------
  // HEADER
  // -----------------------------------------------------------------
  Widget _buildHeader(BuildContext context, GameProvider game, LevelModel level) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.sm, AppSpacing.sm, AppSpacing.md, 0,
      ),
      child: Row(
        children: [
          _circleIconButton(
            icon: Icons.arrow_back_ios_new_rounded,
            onTap: () => Navigator.of(context).maybePop(),
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  "Daraja ${level.levelNumber}",
                  style: AppTypography.display(size: 18),
                ),
                const SizedBox(height: 2),
                Text(
                  game.alphabetMode.label,
                  style: AppTypography.body(size: 12),
                ),
              ],
            ),
          ),
          _buildAlphabetSwitch(game),
          const SizedBox(width: AppSpacing.sm),
          _buildCoinBadge(game),
        ],
      ),
    );
  }

  Widget _circleIconButton({required IconData icon, required VoidCallback onTap}) {
    return Material(
      color: AppColors.surface,
      shape: const CircleBorder(),
      elevation: 0,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(icon, color: AppColors.textPrimary, size: 18),
        ),
      ),
    );
  }

  Widget _buildAlphabetSwitch(GameProvider game) {
    return GestureDetector(
      onTap: () {
        final next = game.alphabetMode == AlphabetMode.lotin
            ? AlphabetMode.kiril
            : AlphabetMode.lotin;
        game.switchAlphabet(next);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
          boxShadow: softShadow(opacity: 0.06, blur: 8),
        ),
        child: Row(
          children: [
            Icon(Icons.translate_rounded, color: AppColors.secondaryDark, size: 16),
            const SizedBox(width: 4),
            Text(
              game.alphabetMode == AlphabetMode.lotin ? "АБВ" : "ABC",
              style: AppTypography.body(size: 12, weight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCoinBadge(GameProvider game) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        gradient: AppColors.goldGradient,
        borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
        boxShadow: softShadow(opacity: 0.15, blur: 8),
      ),
      child: Row(
        children: [
          const Icon(Icons.monetization_on_rounded, color: Colors.white, size: 18),
          const SizedBox(width: 4),
          Text(
            "${game.coins}",
            style: AppTypography.button(size: 14, color: Colors.white),
          ),
        ],
      ),
    );
  }

  // -----------------------------------------------------------------
  // HARFLAR AYLANASI
  // -----------------------------------------------------------------
  Widget _buildLetterCircle(BuildContext context, GameProvider game, LevelModel level) {
    return Center(
      child: AspectRatio(
        aspectRatio: 1,
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final size = Size(constraints.maxWidth, constraints.maxHeight);
              final layout = CircleLayoutHelper(
                size: size,
                letterCount: level.circleLetters.length,
              );

              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanStart: (details) {
                  final hit = layout.hitTest(details.localPosition);
                  if (hit != null) {
                    game.startSelection(hit);
                    setState(() => _dragPosition = details.localPosition);
                  }
                },
                onPanUpdate: (details) {
                  setState(() => _dragPosition = details.localPosition);
                  final hit = layout.hitTest(details.localPosition);
                  if (hit != null) {
                    game.extendSelection(hit);
                  }
                },
                onPanEnd: (_) {
                  game.endSelection();
                  setState(() => _dragPosition = null);
                },
                onPanCancel: () {
                  game.cancelSelection();
                  setState(() => _dragPosition = null);
                },
                child: CustomPaint(
                  size: size,
                  painter: WordCirclePainter(
                    letters: level.circleLetters,
                    selectedIndices: game.selectedIndices,
                    currentDragPosition: _dragPosition,
                    hintLetterIndex: _hintLetterIndex,
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  // -----------------------------------------------------------------
  // YORDAM TUGMASI
  // -----------------------------------------------------------------
  Widget _buildHintButton(BuildContext context, GameProvider game) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: game.canAffordHint
                ? AppColors.secondary
                : AppColors.surfaceMuted,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 15),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
            ),
            elevation: 0,
          ),
          icon: Icon(
            Icons.lightbulb_rounded,
            color: game.canAffordHint ? Colors.white : AppColors.textSecondary,
          ),
          label: Text(
            "Yordam (${GameProvider.hintCost} tanga)",
            style: AppTypography.button(
              size: 15,
              color: game.canAffordHint ? Colors.white : AppColors.textSecondary,
            ),
          ),
          onPressed: () {
            final highlighted = game.hintHighlightLetterIndex();
            setState(() => _hintLetterIndex = highlighted);

            final revealedWord = game.useHint();

            Future.delayed(AppMotion.slow, () {
              if (mounted) setState(() => _hintLetterIndex = null);
            });

            if (revealedWord == null && !game.canAffordHint) {
              _showSnack("Tangalar yetarli emas!", isError: true);
            }
          },
        ),
      ),
    );
  }
}
