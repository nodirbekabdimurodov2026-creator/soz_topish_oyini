/// Lotin va Kirill o'zbek alifbosi rejimlarini boshqaruvchi enum.
enum AlphabetMode { lotin, kiril }

extension AlphabetModeExtension on AlphabetMode {
  String get label {
    switch (this) {
      case AlphabetMode.lotin:
        return "Lotin";
      case AlphabetMode.kiril:
        return "Кирилл";
    }
  }

  String get storageKey => name; // 'lotin' | 'kiril'

  static AlphabetMode fromKey(String key) {
    return AlphabetMode.values.firstWhere(
      (e) => e.storageKey == key,
      orElse: () => AlphabetMode.lotin,
    );
  }
}

/// Har bir alifbo uchun harf to'plamlari (chastotaga qarab og'irliklangan).
/// Bonus harflar generatsiyasida ham foydalaniladi.
class AlphabetData {
  // O'zbek lotin alifbosi (asosiy harflar, ko'p ishlatiladigan unli/undoshlar ustunlik bilan)
  static const List<String> lotinLetters = [
    'A', 'B', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K',
    'L', 'M', 'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U',
    'V', 'X', 'Y', 'Z', 'O\'', 'G\'', 'SH', 'CH', 'NG',
  ];

  // O'zbek kirill alifbosi
  static const List<String> kirilLetters = [
    'А', 'Б', 'В', 'Г', 'Д', 'Е', 'Ё', 'Ж', 'З', 'И',
    'Й', 'К', 'Л', 'М', 'Н', 'О', 'П', 'Р', 'С', 'Т',
    'У', 'Ф', 'Х', 'Ц', 'Ч', 'Ш', 'Ъ', 'Э', 'Ю', 'Я',
    'Ў', 'Қ', 'Ғ', 'Ҳ',
  ];

  static List<String> lettersFor(AlphabetMode mode) {
    return mode == AlphabetMode.lotin ? lotinLetters : kirilLetters;
  }
}
