import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/daily_reward_state.dart';
import '../providers/game_provider.dart';
import '../theme/app_theme.dart';

/// Ilova ochilganda (agar bugun hali olinmagan bo'lsa) ko'rsatiladigan
/// kunlik mukofot popup'i. 7 kunlik tsiklni vizual ko'rsatadi, shu orqali
/// odamga "ketma-ketlikni uzmaslik" tuyg'usini beradi - bu eng kuchli
/// retention mexanikalaridan biri.
class DailyRewardDialog extends StatefulWidget {
  const DailyRewardDialog({super.key});

  static Future<void> showIfAvailable(BuildContext context) async {
    final game = context.read<GameProvider>();
    if (!game.hasUnclaimedDailyReward) return;

    await showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.55),
      transitionDuration: AppMotion.normal,
      pageBuilder: (_, __, ___) => const DailyRewardDialog(),
      transitionBuilder: (context, animation, _, child) {
        final curved = CurvedAnimation(parent: animation, curve: AppMotion.snap);
        return Transform.scale(
          scale: 0.7 + (0.3 * curved.value),
          child: Opacity(opacity: curved.value, child: child),
        );
      },
    );
  }

  @override
  State<DailyRewardDialog> createState() => _DailyRewardDialogState();
}

class _DailyRewardDialogState extends State<DailyRewardDialog> {
  int? _claimedAmount;

  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameProvider>();
    final reward = game.dailyReward;
    final dayInCycle = reward.currentStreak % 7; // 0-6, bugun olinadigan kun

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          boxShadow: softShadow(opacity: 0.2, blur: 24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("Kunlik mukofot", style: AppTypography.display(size: 22)),
            const SizedBox(height: AppSpacing.xs),
            Text(
              _claimedAmount == null
                  ? "Bugungi mukofotingizni oling!"
                  : "Ertaga yana qaytib keling 🌱",
              style: AppTypography.body(),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.lg),
            _buildWeekRow(dayInCycle),
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _claimedAmount == null
                      ? AppColors.primary
                      : AppColors.leafDark,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
                  ),
                  elevation: 0,
                ),
                onPressed: () {
                  if (_claimedAmount == null) {
                    final amount = game.claimDailyReward();
                    setState(() => _claimedAmount = amount);
                  } else {
                    Navigator.of(context).pop();
                  }
                },
                child: Text(
                  _claimedAmount == null
                      ? "Olish (+${reward.nextRewardAmount} tanga)"
                      : "Ajoyib!",
                  style: AppTypography.button(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeekRow(int todayIndex) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(7, (i) {
        final amount = DailyRewardState.rewardCycle[i];
        final isPast = i < todayIndex;
        final isToday = i == todayIndex;

        return Column(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: isPast || (isToday && _claimedAmount != null)
                    ? AppColors.letterCircleGradient
                    : isToday
                        ? AppColors.goldGradient
                        : null,
                color: !isPast && !isToday ? AppColors.surfaceMuted : null,
                border: isToday
                    ? Border.all(color: AppColors.primary, width: 2)
                    : null,
              ),
              alignment: Alignment.center,
              child: isPast || (isToday && _claimedAmount != null)
                  ? const Icon(Icons.check, color: Colors.white, size: 18)
                  : Text(
                      "$amount",
                      style: AppTypography.body(
                        size: 11,
                        weight: FontWeight.w800,
                        color: isToday
                            ? AppColors.textPrimary
                            : AppColors.textSecondary,
                      ),
                    ),
            ),
            const SizedBox(height: 4),
            Text("${i + 1}", style: AppTypography.body(size: 11)),
          ],
        );
      }),
    );
  }
}
