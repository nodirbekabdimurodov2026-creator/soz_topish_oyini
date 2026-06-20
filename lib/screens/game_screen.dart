import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/alphabet_mode.dart';
import '../models/level_model.dart';
import '../providers/game_provider.dart';
import '../utils/circle_layout_helper.dart';
import '../widgets/word_circle_painter.dart';
import '../widgets/word_grid_panel.dart';

/// O'yinning asosiy ekrani: yuqorida krossvord paneli, pastda harflar
/// aylanasi (GestureDetector + CustomPainter), header'da tangalar va
/// daraja raqami, pastda "Yordam" tugmasi.
class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen>
    with SingleTickerProviderStateMixin {
  Offset? _dragPosition;
  int? _hintLetterIndex;
  late AnimationController _shakeController;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  void _showSnack(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, textAlign: TextAlign.center),
        backgroundColor:
            isError ? Colors.redAccent.shade400 : const Color(0xFF6C5CE7),
        duration: const Duration(milliseconds: 1200),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<GameProvider>(
      builder: (context, game, _) {
        if (game.isLoading || game.currentLevel == null) {
          return const Scaffold(
            backgroundColor: Color(0xFF1B1C2E),
            body: Center(
              child: CircularProgressIndicator(color: Color(0xFF6C5CE7)),
            ),
          );
        }

        // Provider'dan kelgan xabarni bir martalik ko'rsatish
        if (game.lastMessage != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (game.lastMessage != null) {
              _showSnack(game.lastMessage!, isError: !game.isLastWordCorrect);
              game.clearMessage();
            }
          });
        }

        final level = game.currentLevel!;
        final progress = game.currentProgress;
        final foundWords = progress?.foundWords ?? [];

        return Scaffold(
          backgroundColor: const Color(0xFF1B1C2E),
          body: SafeArea(
            child: Column(
              children: [
                _buildHeader(context, game, level),
                const SizedBox(height: 8),
                Expanded(
                  flex: 4,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
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
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
  }

  // -----------------------------------------------------------------
  // HEADER: orqaga, daraja raqami, tangalar, alifbo almashtirish
  // -----------------------------------------------------------------
  Widget _buildHeader(BuildContext context, GameProvider game, LevelModel level) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white70),
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  "Daraja ${level.levelNumber}",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  game.alphabetMode.label,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          _buildAlphabetSwitch(game),
          const SizedBox(width: 8),
          _buildCoinBadge(game),
        ],
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
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            const Icon(Icons.translate, color: Colors.white70, size: 16),
            const SizedBox(width: 4),
            Text(
              game.alphabetMode == AlphabetMode.lotin ? "АБВ" : "ABC",
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCoinBadge(GameProvider game) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFFD700).withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFFFD700).withOpacity(0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.monetization_on, color: Color(0xFFFFD700), size: 18),
          const SizedBox(width: 4),
          Text(
            "${game.coins}",
            style: const TextStyle(
              color: Color(0xFFFFD700),
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  // -----------------------------------------------------------------
  // HARFLAR AYLANASI: GestureDetector + CustomPainter
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
  // YORDAM (PODSKAZKA) TUGMASI
  // -----------------------------------------------------------------
  Widget _buildHintButton(BuildContext context, GameProvider game) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: game.canAffordHint
                ? const Color(0xFFFFA502)
                : Colors.white.withOpacity(0.1),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          icon: const Icon(Icons.lightbulb_outline),
          label: Text(
            "Yordam (${GameProvider.hintCost} tanga)",
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          onPressed: () {
            // Vizual "yoritish" effekti - tasodifiy harfni bir lahza belgilaymiz
            final highlighted = game.hintHighlightLetterIndex();
            setState(() => _hintLetterIndex = highlighted);

            final revealedWord = game.useHint();

            Future.delayed(const Duration(milliseconds: 600), () {
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
