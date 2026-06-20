import 'package:flutter/material.dart';

/// Topilishi kerak bo'lgan so'zlar uchun krossvord-uslubidagi katakchalar
/// panelini chizadi. So'z topilganda mos katakchalar harflarga to'ladi,
/// topilmagan bo'lsa bo'sh (faqat chiziq) ko'rinishda qoladi.
class WordGridPanel extends StatelessWidget {
  final List<String> allWords; // level.validWords (katta harfda)
  final List<String> foundWords;

  const WordGridPanel({
    super.key,
    required this.allWords,
    required this.foundWords,
  });

  @override
  Widget build(BuildContext context) {
    // Uzunligi bo'yicha guruhlaymiz - ko'pchilik so'z-topish o'yinlarida
    // qisqa so'zlar yuqorida, uzunlar pastda joylashadi.
    final sorted = [...allWords]
      ..sort((a, b) => a.length.compareTo(b.length));

    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 12,
      runSpacing: 10,
      children: sorted.map((word) {
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
          duration: const Duration(milliseconds: 250),
          margin: const EdgeInsets.symmetric(horizontal: 2),
          width: 28,
          height: 32,
          decoration: BoxDecoration(
            color: isFound
                ? const Color(0xFF6C5CE7)
                : Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isFound
                  ? Colors.white.withOpacity(0.6)
                  : Colors.white.withOpacity(0.25),
              width: 1.2,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            letter,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        );
      }),
    );
  }
}
