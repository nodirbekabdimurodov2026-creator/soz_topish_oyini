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

  LevelModel({
    required this.id,
    required this.levelNumber,
    required this.alphabetKey,
    required this.circleLetters,
    required this.validWords,
    required this.mainWord,
    this.starThreshold = 0,
  });

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
    };
  }

  /// assets/data/*.json fayllaridan boshlang'ich import qilish uchun.
  factory LevelModel.fromJson(Map<String, dynamic> json, String alphabetKey) {
    final words = List<String>.from(json['words'] as List);
    // Eng uzun so'zni asosiy so'z deb belgilaymiz
    words.sort((a, b) => b.length.compareTo(a.length));
    return LevelModel(
      id: json['id'] as int,
      levelNumber: json['level'] as int,
      alphabetKey: alphabetKey,
      circleLetters: List<String>.from(json['letters'] as List),
      validWords: words,
      mainWord: words.isNotEmpty ? words.first : '',
      starThreshold: (words.length * 0.6).ceil(),
    );
  }
}
