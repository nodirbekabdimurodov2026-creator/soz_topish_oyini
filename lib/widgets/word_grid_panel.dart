import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Topilishi kerak bo'lgan so'zlar uchun krossvord-uslubidagi katakchalar
/// panelini chizadi. So'z topilganda mos katakchalar harflarga to'ladi,
/// topilmagan bo'lsa bo'sh (faqat chiziq) ko'rinishda qoladi.
///
/// MUHIM: faqat [requiredCount] tagacha eng qisqa so'zlar ko'rsatiladi -
/// qolgan "bonus" so'zlar (agar level.validWords ko'proq bo'lsa) bu
/// panelda ko'rsatilmaydi, chunki ular daraja tugashi uchun shart emas.
/// Bu birinchi darajalarda 1-2 ta katak qatori bilan boshlanishini va
/// foydalanuvchini ko'p sonli bo'sh kataklar bilan cho'chitmasligini
/// ta'minlaydi.
class WordGridPanel extends StatelessWidget {
  final List<String> allWords;
  final List<String> foundWords;
  final int requiredCount;

  const WordGridPanel({
    super.key,
    required this.allWords,
    required this.foundWords,
    required this.requiredCount,
  });

  @override
  Widget build(BuildContext context) {
    final sorted = [...allWords]
      ..sort((a, b) => a.length.compareTo(b.length));

    // Faqat talab qilingan sondagi (eng qisqa) so'zlarni ko'rsatamiz.
    // Agar foydalanuvchi shu sonni topgandan keyin ham qo'shimcha
    // (bonus) so'z topgan bo'lsa, ularni ham ko'rsatamiz - shunda
    // allaqachon topilgan bonus so'zlar yo'qolib qolmaydi.
    final visibleWords = <String>{};
    for (final w in sorted.take(requiredCount)) {
      visibleWords.add(w);
    }
    for (final foundUpper in foundWords) {
      final match = allWords.where((x) => x.toUpperCase() == foundUpper);
      if (match.isNotEmpty) visibleWords.add(match.first);
    }
    final displayList = visibleWords.toList()
      ..sort((a, b) => a.length.compareTo(b.length));

    return Wrap(
      alignment: WrapAlignment.center,
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: displayList.map((word) {
        final isFound = foundWords.contains(word.toUpperCase());
        return _WordSlot(word: word, isFound: isFound);
      }).toList(),
    );
  }
}

class _WordSlot extends StatelessWidget {
  final String word;
  final bool isFound;

  const _WordSlot({required this.word, required this.isFound});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(word.length, (i) {
        final letter = isFound ? word[i] : '';
        return AnimatedContainer(
          duration: AppMotion.normal,
          curve: AppMotion.snap,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          width: 30,
          height: 34,
          decoration: BoxDecoration(
            gradient: isFound ? AppColors.letterCircleGradient : null,
            color: isFound ? null : AppColors.surfaceMuted,
            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            border: Border.all(
              color: isFound
                  ? Colors.white.withOpacity(0.5)
                  : AppColors.textSecondary.withOpacity(0.15),
              width: 1.2,
            ),
            boxShadow: isFound ? softShadow(opacity: 0.12, blur: 6) : null,
          ),
          alignment: Alignment.center,
          child: Text(
            letter,
            style: AppTypography.letter(size: 16, color: Colors.white),
          ),
        );
      }),
    );
  }
}

