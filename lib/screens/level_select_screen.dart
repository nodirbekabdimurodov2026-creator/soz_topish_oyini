import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/alphabet_mode.dart';
import '../models/level_model.dart';
import '../providers/game_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/daily_reward_dialog.dart';
import 'game_screen.dart';

/// Darajalar tanlash ekrani - "So'z Bog'i" dizayn tizimi.
///
/// Birinchi taassurot ekrani: issiq fon, katta tanga-badge, kunlik
/// mukofot tugmasi va gul-bog' temasidagi daraja katakchalari. Bu sahifa
/// ochilganda (agar mavjud bo'lsa) kunlik mukofot popup'i avtomatik chiqadi.
class LevelSelectScreen extends StatefulWidget {
  const LevelSelectScreen({super.key});

  @override
  State<LevelSelectScreen> createState() => _LevelSelectScreenState();
}

class _LevelSelectScreenState extends State<LevelSelectScreen> {
  bool _checkedDailyReward = false;

  @override
  Widget build(BuildContext context) {
    return Consumer<GameProvider>(
      builder: (context, game, _) {
        if (!game.isLoading && !_checkedDailyReward) {
          _checkedDailyReward = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            DailyRewardDialog.showIfAvailable(context);
          });
        }

        return Scaffold(
          backgroundColor: AppColors.background,
          body: SafeArea(
            child: game.isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  )
                : Column(
                    children: [
                      _buildHeader(context, game),
                      Expanded(child: _buildLevelGrid(context, game)),
                    ],
                  ),
          ),
        );
      },
    );
  }

  // -----------------------------------------------------------------
  // HEADER: sarlavha, alifbo, tanga, streak
  // -----------------------------------------------------------------
  Widget _buildHeader(BuildContext context, GameProvider game) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("So'z Bog'i 🌿", style: AppTypography.display(size: 26)),
                    const SizedBox(height: 2),
                    Text(
                      "Har bir so'z - yangi gul",
                      style: AppTypography.body(size: 13),
                    ),
                  ],
                ),
              ),
              _buildCoinBadge(game),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(child: _buildAlphabetToggle(game)),
              const SizedBox(width: AppSpacing.sm),
              _buildStreakBadge(game),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCoinBadge(GameProvider game) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        gradient: AppColors.goldGradient,
        borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
        boxShadow: softShadow(opacity: 0.18, blur: 10),
      ),
      child: Row(
        children: [
          const Icon(Icons.monetization_on_rounded, color: Colors.white, size: 20),
          const SizedBox(width: 6),
          Text("${game.coins}", style: AppTypography.button(size: 16, color: Colors.white)),
        ],
      ),
    );
  }

  Widget _buildAlphabetToggle(GameProvider game) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
      ),
      child: Row(
        children: [
          Expanded(child: _alphabetTab(game, "lotin", "Lotin")),
          Expanded(child: _alphabetTab(game, "kiril", "Кирилл")),
        ],
      ),
    );
  }

  Widget _alphabetTab(GameProvider game, String key, String label) {
    final isActive = game.alphabetMode.storageKey == key;
    return GestureDetector(
      onTap: () {
        final mode = AlphabetModeExtension.fromKey(key);
        game.switchAlphabet(mode);
      },
      child: AnimatedContainer(
        duration: AppMotion.fast,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? AppColors.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
          boxShadow: isActive ? softShadow(opacity: 0.08, blur: 6) : null,
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: AppTypography.body(
            size: 13,
            weight: FontWeight.w700,
            color: isActive ? AppColors.primary : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildStreakBadge(GameProvider game) {
    final streak = game.dailyReward.currentStreak;
    return GestureDetector(
      onTap: () => DailyRewardDialog.showIfAvailable(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
          boxShadow: softShadow(opacity: 0.06, blur: 6),
        ),
        child: Row(
          children: [
            const Text("🔥", style: TextStyle(fontSize: 16)),
            const SizedBox(width: 4),
            Text("$streak", style: AppTypography.button(size: 14, color: AppColors.textPrimary)),
          ],
        ),
      ),
    );
  }

  // -----------------------------------------------------------------
  // DARAJALAR GRID
  // -----------------------------------------------------------------
  Widget _buildLevelGrid(BuildContext context, GameProvider game) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.md,
      ),
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          crossAxisSpacing: AppSpacing.sm,
          mainAxisSpacing: AppSpacing.sm,
        ),
        itemCount: game.levels.length,
        itemBuilder: (context, index) {
          final level = game.levels[index];
          final unlocked = game.isLevelUnlocked(level);
          final stars = game.progressFor(level.id).starsEarned;
          final isCurrent = game.currentLevel?.id == level.id;

          return _LevelTile(
            level: level,
            unlocked: unlocked,
            stars: stars,
            isNext: isCurrent,
            onTap: unlocked
                ? () async {
                    await game.selectLevel(level);
                    if (context.mounted) {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const GameScreen()),
                      );
                    }
                  }
                : null,
          );
        },
      ),
    );
  }
}

class _LevelTile extends StatelessWidget {
  final LevelModel level;
  final bool unlocked;
  final int stars;
  final bool isNext;
  final VoidCallback? onTap;

  const _LevelTile({
    required this.level,
    required this.unlocked,
    required this.stars,
    required this.isNext,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isCompleted = stars > 0;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppMotion.fast,
        decoration: BoxDecoration(
          gradient: unlocked
              ? (isCompleted ? AppColors.letterCircleGradient : AppColors.selectedLetterGradient)
              : null,
          color: unlocked ? null : AppColors.locked.withOpacity(0.4),
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          border: isNext
              ? Border.all(color: AppColors.gold, width: 3)
              : Border.all(color: Colors.white.withOpacity(unlocked ? 0.4 : 0.0), width: 1.5),
          boxShadow: unlocked ? softShadow(opacity: 0.12, blur: 10) : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (unlocked)
              Text(
                "${level.levelNumber}",
                style: AppTypography.display(size: 20, color: Colors.white),
              )
            else
              Icon(Icons.lock_rounded, color: AppColors.textSecondary.withOpacity(0.6), size: 20),
            if (unlocked) ...[
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(3, (i) {
                  return Icon(
                    Icons.star_rounded,
                    size: 11,
                    color: i < stars ? AppColors.gold : Colors.white.withOpacity(0.35),
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
