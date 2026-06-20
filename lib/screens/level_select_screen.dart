import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/level_model.dart';
import '../providers/game_provider.dart';
import 'game_screen.dart';

/// Barcha darajalarni grid ko'rinishida ko'rsatadigan ekran.
/// Qulflangan darajalar bloklangan, ochilganlari bosilganda GameScreen'ga o'tadi.
class LevelSelectScreen extends StatelessWidget {
  const LevelSelectScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<GameProvider>(
      builder: (context, game, _) {
        return Scaffold(
          backgroundColor: const Color(0xFF1B1C2E),
          appBar: AppBar(
            backgroundColor: const Color(0xFF1B1C2E),
            elevation: 0,
            title: const Text(
              "Darajalar",
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          body: game.isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: Color(0xFF6C5CE7)),
                )
              : Padding(
                  padding: const EdgeInsets.all(16),
                  child: GridView.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    itemCount: game.levels.length,
                    itemBuilder: (context, index) {
                      final level = game.levels[index];
                      final unlocked = game.isLevelUnlocked(level);
                      final stars = game.progressFor(level.id).starsEarned;

                      return _LevelTile(
                        level: level,
                        unlocked: unlocked,
                        stars: stars,
                        onTap: unlocked
                            ? () async {
                                await game.selectLevel(level);
                                if (context.mounted) {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => const GameScreen(),
                                    ),
                                  );
                                }
                              }
                            : null,
                      );
                    },
                  ),
                ),
        );
      },
    );
  }
}

class _LevelTile extends StatelessWidget {
  final LevelModel level;
  final bool unlocked;
  final int stars;
  final VoidCallback? onTap;

  const _LevelTile({
    required this.level,
    required this.unlocked,
    required this.stars,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: unlocked
              ? const Color(0xFF6C5CE7).withOpacity(0.85)
              : Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: unlocked
                ? Colors.white.withOpacity(0.3)
                : Colors.white.withOpacity(0.08),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (unlocked)
              Text(
                "${level.levelNumber}",
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              )
            else
              const Icon(Icons.lock, color: Colors.white38, size: 22),
            if (unlocked) ...[
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(3, (i) {
                  return Icon(
                    Icons.star,
                    size: 10,
                    color: i < stars
                        ? const Color(0xFFFFD700)
                        : Colors.white.withOpacity(0.2),
                  );
                }),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
