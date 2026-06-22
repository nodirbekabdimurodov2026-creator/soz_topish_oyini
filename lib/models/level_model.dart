import 'dart:convert';

/// Bitta darajadagi (level) ma'lumotlar modeli.
///
/// [circleLetters]  - aylanada joylashadigan harflar to'plami (masalan 6-7 ta).
/// [validWords]     - shu harflardan yasalishi mumkin bo'lgan barcha haqiqiy so'zlar
///                     (krossvord panelida ochiladigan so'zlar).
/// [mainWord]       - asosiy (eng uzun) so'z, odatda darajani "tugatish" mezoni.
class LevelModel {
  final int id;
  final int levelNumber;
  final String alphabetKey; // 'lotin' | 'kiril'
  final List<String> circleLetters;
  final List<String> validWords;
  final String mainWord;
  final int starThreshold; // nechta so'z topilsa 3 yulduz beriladi (masalan)

  /// Daraja "tugagan" deb hisoblanishi uchun kerak bo'lgan minimal
  /// so'zlar soni. Bu validWords.length'dan kichik bo'lishi mumkin -
  /// shunda foydalanuvchi hamma so'zni topmasdan ham keyingi darajaga
  /// o'tishi mumkin (qolgan so'zlar ixtiyoriy bonus bo'lib qoladi).
  /// Birinchi darajalarda past (tezroq g'alaba hissi), keyinroq
  /// validWords.length'ga yaqinlashadi.
  final int completionThreshold;

  LevelModel({
    required this.id,
    required this.levelNumber,
    required this.alphabetKey,
    required this.circleLetters,
    required this.validWords,
    required this.mainWord,
    this.starThreshold = 0,
    int? completionThreshold,
  }) : completionThreshold =
            completionThreshold ?? validWords.length;

  /// SQLite jadvalidan o'qish uchun.
  factory LevelModel.fromMap(Map<String, dynamic> map) {
    return LevelModel(
      id: map['id'] as int,
      levelNumber: map['level_number'] as int,
      alphabetKey: map['alphabet'] as String,
      circleLetters: List<String>.from(jsonDecode(map['circle_letters'] as String)),
      validWords: List<String>.from(jsonDecode(map['valid_words'] as String)),
      mainWord: map['main_word'] as String,
      starThreshold: map['star_threshold'] as int? ?? 0,
      completionThreshold: map['completion_threshold'] as int?,
    );
  }

  /// SQLite jadvaliga yozish uchun.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'level_number': levelNumber,
      'alphabet': alphabetKey,
      'circle_letters': jsonEncode(circleLetters),
      'valid_words': jsonEncode(validWords),
      'main_word': mainWord,
      'star_threshold': starThreshold,
      'completion_threshold': completionThreshold,
    };
  }

  /// Daraja raqamiga qarab, daraja tugatish uchun zarur bo'lgan so'zlar
  /// sonini progressiv tarzda hisoblaydi. 1-daraja atigi 1 ta so'z bilan
  /// tugaydi (darrov g'alaba hissi), 2-daraja 2 ta so'z, undan keyin
  /// asta-sekin ko'tarilib, 16-darajadan boshlab barcha so'zlar talab
  /// qilinadi (to'liq qiyinlik).
  static int _progressiveThreshold(int levelNumber, int totalWords) {
    if (totalWords <= 1) return totalWords;
    if (levelNumber == 1) return 1;
    if (levelNumber == 2) return 2;
    if (levelNumber <= 5) return totalWords < 3 ? totalWords : 3;
    if (levelNumber <= 8) return (totalWords * 0.4).ceil().clamp(2, totalWords);
    if (levelNumber <= 15) return (totalWords * 0.6).ceil().clamp(2, totalWords);
    return totalWords;
  }

  /// assets/data/*.json fayllaridan boshlang'ich import qilish uchun.
  factory LevelModel.fromJson(Map<String, dynamic> json, String alphabetKey) {
    final words = List<String>.from(json['words'] as List);
    // Eng uzun so'zni asosiy so'z deb belgilaymiz
    words.sort((a, b) => b.length.compareTo(a.length));
    final levelNumber = json['level'] as int;
    return LevelModel(
      id: json['id'] as int,
      levelNumber: levelNumber,
      alphabetKey: alphabetKey,
      circleLetters: List<String>.from(json['letters'] as List),
      validWords: words,
      mainWord: words.isNotEmpty ? words.first : '',
      starThreshold: (words.length * 0.6).ceil(),
      completionThreshold: _progressiveThreshold(levelNumber, words.length),
    );
  }
}
