#!/data/data/com.termux/files/usr/bin/bash
set -e
echo "=== Eski lib papkasi tozalanmoqda ==="
rm -rf lib
mkdir -p lib/database lib/models lib/providers lib/screens lib/services lib/theme lib/utils lib/widgets
echo "=== Papkalar yaratildi ==="
echo '=== main.dart ==='
cat > lib/main.dart << 'DARTEOF'
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'providers/game_provider.dart';
import 'screens/level_select_screen.dart';
import 'services/ad_service.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Reklama xizmatini fonda ishga tushiramiz - bu UI'ni bloklamasligi
  // uchun await qilinmaydi, lekin chaqirish darrov amalga oshiriladi.
  AdService.instance.initialize();

  runApp(const SozTopishApp());
}

class SozTopishApp extends StatelessWidget {
  const SozTopishApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => GameProvider(),
      child: MaterialApp(
        title: "So'z Bog'i",
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          scaffoldBackgroundColor: AppColors.background,
          colorScheme: ColorScheme.fromSeed(
            seedColor: AppColors.primary,
            brightness: Brightness.light,
            surface: AppColors.surface,
          ),
          textTheme: Theme.of(context).textTheme.apply(
                bodyColor: AppColors.textPrimary,
                displayColor: AppColors.textPrimary,
              ),
        ),
        home: const LevelSelectScreen(),
      ),
    );
  }
}
DARTEOF
echo '=== lib/database/database_helper.dart ==='
cat > lib/database/database_helper.dart << 'DARTEOF'
import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/level_model.dart';

/// O'yinning butun offline ma'lumotlar bazasini boshqaruvchi singleton klass.
///
/// Birinchi marta ishga tushganda assets/data/words_*.json fayllaridan
/// darajalarni o'qib, SQLite jadvaliga "seed" qiladi. Keyingi safar
/// ilova ochilganda esa to'g'ridan-to'g'ri bazadan o'qiydi - internet kerak emas.
class DatabaseHelper {
  DatabaseHelper._internal();
  static final DatabaseHelper instance = DatabaseHelper._internal();

  static const String _dbName = 'soz_topish.db';
  static const int _dbVersion = 2;

  static const String tableLevels = 'levels';

  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, _dbName);

    return openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  /// Eski o'rnatishlarda (v1) jadval strukturasi o'zgargani uchun,
  /// eng oson va xavfsiz yo'l - jadvalni butunlay qayta yaratish va
  /// assetlardan qaytadan seed qilish. Foydalanuvchi progressi
  /// (shared_preferences'da saqlanadi) bunga ta'sir qilmaydi.
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    await db.execute('DROP TABLE IF EXISTS $tableLevels');
    await _onCreate(db, newVersion);
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $tableLevels (
        id INTEGER PRIMARY KEY,
        level_number INTEGER NOT NULL,
        alphabet TEXT NOT NULL,
        circle_letters TEXT NOT NULL,
        valid_words TEXT NOT NULL,
        main_word TEXT NOT NULL,
        star_threshold INTEGER NOT NULL DEFAULT 0,
        completion_threshold INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // Birinchi o'rnatishda JSON assetlardan darajalarni yuklab, bazaga yozamiz.
    await _seedFromAssets(db);
  }

  Future<void> _seedFromAssets(Database db) async {
    await _seedAlphabet(db, 'assets/data/words_lotin.json', 'lotin');
    await _seedAlphabet(db, 'assets/data/words_kiril.json', 'kiril');
  }

  Future<void> _seedAlphabet(
    Database db,
    String assetPath,
    String alphabetKey,
  ) async {
    try {
      final raw = await rootBundle.loadString(assetPath);
      final List<dynamic> jsonList = jsonDecode(raw) as List<dynamic>;

      final batch = db.batch();
      for (final item in jsonList) {
        final level = LevelModel.fromJson(
          item as Map<String, dynamic>,
          alphabetKey,
        );
        batch.insert(
          tableLevels,
          level.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
    } catch (e) {
      // Agar asset topilmasa, ilova qulamasligi uchun jim o'tamiz.
      // Productionda bu yerga logging qo'shing.
    }
  }

  /// Berilgan alifbo bo'yicha barcha darajalarni level_number tartibida qaytaradi.
  Future<List<LevelModel>> getLevelsByAlphabet(String alphabetKey) async {
    final db = await database;
    final rows = await db.query(
      tableLevels,
      where: 'alphabet = ?',
      whereArgs: [alphabetKey],
      orderBy: 'level_number ASC',
    );
    return rows.map((r) => LevelModel.fromMap(r)).toList();
  }

  Future<LevelModel?> getLevelById(int id) async {
    final db = await database;
    final rows = await db.query(
      tableLevels,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return LevelModel.fromMap(rows.first);
  }

  Future<int> countLevels(String alphabetKey) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as cnt FROM $tableLevels WHERE alphabet = ?',
      [alphabetKey],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }
}
DARTEOF
echo '=== lib/models/alphabet_mode.dart ==='
cat > lib/models/alphabet_mode.dart << 'DARTEOF'
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
DARTEOF
echo '=== lib/models/daily_reward_state.dart ==='
cat > lib/models/daily_reward_state.dart << 'DARTEOF'
/// Kunlik kirish mukofotlari va streak (ketma-ket kunlar) holatini saqlaydi.
class DailyRewardState {
  final DateTime? lastClaimDate;
  final int currentStreak; // ketma-ket necha kun kirgan
  final int longestStreak;
  final bool claimedToday;

  DailyRewardState({
    required this.lastClaimDate,
    required this.currentStreak,
    required this.longestStreak,
    required this.claimedToday,
  });

  factory DailyRewardState.initial() => DailyRewardState(
        lastClaimDate: null,
        currentStreak: 0,
        longestStreak: 0,
        claimedToday: false,
      );

  /// 7 kunlik tsikl bo'yicha mukofot miqdori (oxirgi kun eng katta bonus).
  /// Bu klassik "kunlik kirish" mexanikasi - har 7 kunda qaytadan boshlanadi,
  /// progress yo'qolmaydi degan tuyg'u beradi, lekin doimiy yangilanish bor.
  static const List<int> rewardCycle = [10, 15, 20, 25, 30, 40, 100];

  int get nextRewardAmount {
    final dayInCycle = currentStreak % 7;
    return rewardCycle[dayInCycle];
  }

  DailyRewardState copyWith({
    DateTime? lastClaimDate,
    int? currentStreak,
    int? longestStreak,
    bool? claimedToday,
  }) {
    return DailyRewardState(
      lastClaimDate: lastClaimDate ?? this.lastClaimDate,
      currentStreak: currentStreak ?? this.currentStreak,
      longestStreak: longestStreak ?? this.longestStreak,
      claimedToday: claimedToday ?? this.claimedToday,
    );
  }

  Map<String, dynamic> toJson() => {
        'lastClaimDate': lastClaimDate?.toIso8601String(),
        'currentStreak': currentStreak,
        'longestStreak': longestStreak,
      };

  factory DailyRewardState.fromJson(Map<String, dynamic> json) {
    return DailyRewardState(
      lastClaimDate: json['lastClaimDate'] != null
          ? DateTime.parse(json['lastClaimDate'] as String)
          : null,
      currentStreak: json['currentStreak'] as int? ?? 0,
      longestStreak: json['longestStreak'] as int? ?? 0,
      claimedToday: false, // har doim yangi sessiyada qayta tekshiriladi
    );
  }
}
DARTEOF
echo '=== lib/models/level_model.dart ==='
cat > lib/models/level_model.dart << 'DARTEOF'
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
  /// sonini progressiv tarzda hisoblaydi. Boshida juda yengil (2 ta so'z),
  /// 1-15 darajalarda asta-sekin ko'tariladi, 16-darajadan keyin esa
  /// barcha so'zlar talab qilinadi (to'liq qiyinlik).
  static int _progressiveThreshold(int levelNumber, int totalWords) {
    if (totalWords <= 2) return totalWords;
    if (levelNumber <= 3) return 2;
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
DARTEOF
echo '=== lib/models/level_progress.dart ==='
cat > lib/models/level_progress.dart << 'DARTEOF'
/// Bitta level bo'yicha o'yinchining progressi (qaysi so'zlar topilgan, yulduzlar).
class LevelProgress {
  final int levelId;
  final List<String> foundWords;
  final int starsEarned;
  final bool isCompleted;

  LevelProgress({
    required this.levelId,
    required this.foundWords,
    required this.starsEarned,
    required this.isCompleted,
  });

  factory LevelProgress.empty(int levelId) {
    return LevelProgress(
      levelId: levelId,
      foundWords: [],
      starsEarned: 0,
      isCompleted: false,
    );
  }

  LevelProgress copyWith({
    List<String>? foundWords,
    int? starsEarned,
    bool? isCompleted,
  }) {
    return LevelProgress(
      levelId: levelId,
      foundWords: foundWords ?? this.foundWords,
      starsEarned: starsEarned ?? this.starsEarned,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }

  Map<String, dynamic> toJson() => {
        'levelId': levelId,
        'foundWords': foundWords,
        'starsEarned': starsEarned,
        'isCompleted': isCompleted,
      };

  factory LevelProgress.fromJson(Map<String, dynamic> json) {
    return LevelProgress(
      levelId: json['levelId'] as int,
      foundWords: List<String>.from(json['foundWords'] as List),
      starsEarned: json['starsEarned'] as int,
      isCompleted: json['isCompleted'] as bool,
    );
  }
}
DARTEOF
echo '=== lib/providers/game_provider.dart ==='
cat > lib/providers/game_provider.dart << 'DARTEOF'
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../database/database_helper.dart';
import '../models/alphabet_mode.dart';
import '../models/daily_reward_state.dart';
import '../models/level_model.dart';
import '../models/level_progress.dart';
import '../services/ad_service.dart';

/// O'yinning markaziy holat boshqaruvchisi (Provider/ChangeNotifier asosida).
///
/// Mas'uliyatlari:
///  - Joriy daraja va alifbo rejimini saqlash
///  - Harf tanlash (swipe/drag) jarayonini kuzatish
///  - So'z to'g'riligini tekshirish va krossvord katagini ochish
///  - Tangalar, joriy daraja va progressni shared_preferences orqali saqlash
///  - "Yordam" (podskazka) funksiyasini boshqarish
class GameProvider extends ChangeNotifier {
  GameProvider() {
    _loadPersistedData();
  }

  // ---------------------------------------------------------------------
  // SHARED PREFERENCES KALITLARI
  // ---------------------------------------------------------------------
  static const _kCoinsKey = 'coins';
  static const _kAlphabetKey = 'alphabet_mode';
  static const _kCurrentLevelIdKey = 'current_level_id';
  static const _kProgressPrefix = 'progress_level_';
  static const _kUnlockedLevelsKey = 'unlocked_level_numbers';
  static const _kDailyRewardKey = 'daily_reward_state';

  // ---------------------------------------------------------------------
  // HOLAT (STATE)
  // ---------------------------------------------------------------------
  AlphabetMode _alphabetMode = AlphabetMode.lotin;
  AlphabetMode get alphabetMode => _alphabetMode;

  int _coins = 0;
  int get coins => _coins;

  List<LevelModel> _levels = [];
  List<LevelModel> get levels => _levels;

  LevelModel? _currentLevel;
  LevelModel? get currentLevel => _currentLevel;

  final Map<int, LevelProgress> _progressMap = {};
  /// Berilgan levelId bo'yicha progressni qaytaradi (joriy level bo'lmasa ham).
  LevelProgress progressFor(int levelId) {
    return _progressMap[levelId] ?? LevelProgress.empty(levelId);
  }

  LevelProgress? get currentProgress =>
      _currentLevel == null ? null : _progressMap[_currentLevel!.id];

  /// Hozir qaysi level raqamlari ochilgan (qulflanmagan).
  final Set<int> _unlockedLevelNumbers = {1};
  Set<int> get unlockedLevelNumbers => _unlockedLevelNumbers;

  // --- Gesture / chizish holati ---
  final List<int> _selectedIndices = []; // aylanadagi tanlangan harf indekslari
  List<int> get selectedIndices => List.unmodifiable(_selectedIndices);

  String get currentSelectionWord {
    if (_currentLevel == null) return '';
    return _selectedIndices
        .map((i) => _currentLevel!.circleLetters[i])
        .join();
  }

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  String? _lastMessage; // UI snackbar/feedback uchun ("To'g'ri!", "Bo'lmadi" va h.k.)
  String? get lastMessage => _lastMessage;

  bool _isLastWordCorrect = false;
  bool get isLastWordCorrect => _isLastWordCorrect;

  DailyRewardState _dailyReward = DailyRewardState.initial();
  DailyRewardState get dailyReward => _dailyReward;

  /// Bugun hali olinmagan kunlik mukofot bormi - GameProvider yuklangandan
  /// keyin UI shu flagga qarab popup ko'rsatadi.
  bool get hasUnclaimedDailyReward => !_dailyReward.claimedToday;

  // ---------------------------------------------------------------------
  // BOSHLANG'ICH YUKLASH
  // ---------------------------------------------------------------------
  Future<void> _loadPersistedData() async {
    _isLoading = true;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    _coins = prefs.getInt(_kCoinsKey) ?? 50; // yangi o'yinchiga boshlang'ich bonus
    final savedAlphabet = prefs.getString(_kAlphabetKey);
    if (savedAlphabet != null) {
      _alphabetMode = AlphabetModeExtension.fromKey(savedAlphabet);
    }

    final unlocked = prefs.getStringList(_kUnlockedLevelsKey);
    if (unlocked != null && unlocked.isNotEmpty) {
      _unlockedLevelNumbers
        ..clear()
        ..addAll(unlocked.map(int.parse));
    }

    _dailyReward = _loadDailyRewardState(prefs);

    await loadLevelsForCurrentAlphabet();

    final savedLevelId = prefs.getInt(_kCurrentLevelIdKey);
    if (savedLevelId != null) {
      final found = _levels.where((l) => l.id == savedLevelId);
      if (found.isNotEmpty) {
        await selectLevel(found.first, persist: false);
      } else if (_levels.isNotEmpty) {
        await selectLevel(_levels.first, persist: false);
      }
    } else if (_levels.isNotEmpty) {
      await selectLevel(_levels.first, persist: false);
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> loadLevelsForCurrentAlphabet() async {
    _levels = await DatabaseHelper.instance
        .getLevelsByAlphabet(_alphabetMode.storageKey);
    for (final level in _levels) {
      if (!_progressMap.containsKey(level.id)) {
        _progressMap[level.id] = await _loadProgressForLevel(level.id);
      }
    }
  }

  Future<LevelProgress> _loadProgressForLevel(int levelId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList('$_kProgressPrefix$levelId');
    if (raw == null) return LevelProgress.empty(levelId);
    // raw[0] = isCompleted(0/1), raw[1] = stars, raw[2..] = found words
    if (raw.length < 2) return LevelProgress.empty(levelId);
    final isCompleted = raw[0] == '1';
    final stars = int.tryParse(raw[1]) ?? 0;
    final found = raw.skip(2).toList();
    return LevelProgress(
      levelId: levelId,
      foundWords: found,
      starsEarned: stars,
      isCompleted: isCompleted,
    );
  }

  Future<void> _persistProgressForLevel(LevelProgress progress) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = [
      progress.isCompleted ? '1' : '0',
      progress.starsEarned.toString(),
      ...progress.foundWords,
    ];
    await prefs.setStringList(
      '$_kProgressPrefix${progress.levelId}',
      raw,
    );
  }

  // ---------------------------------------------------------------------
  // ALIFBO ALMASHTIRISH
  // ---------------------------------------------------------------------
  Future<void> switchAlphabet(AlphabetMode mode) async {
    if (_alphabetMode == mode) return;
    _alphabetMode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kAlphabetKey, mode.storageKey);

    await loadLevelsForCurrentAlphabet();
    if (_levels.isNotEmpty) {
      await selectLevel(_levels.first);
    }
    notifyListeners();
  }

  // ---------------------------------------------------------------------
  // DARAJA TANLASH
  // ---------------------------------------------------------------------
  Future<void> selectLevel(LevelModel level, {bool persist = true}) async {
    _currentLevel = level;
    _selectedIndices.clear();
    _lastMessage = null;

    if (!_progressMap.containsKey(level.id)) {
      _progressMap[level.id] = await _loadProgressForLevel(level.id);
    }

    if (persist) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_kCurrentLevelIdKey, level.id);
    }
    notifyListeners();
  }

  bool isLevelUnlocked(LevelModel level) =>
      _unlockedLevelNumbers.contains(level.levelNumber);

  Future<void> _unlockNextLevel() async {
    if (_currentLevel == null) return;
    final nextNumber = _currentLevel!.levelNumber + 1;
    if (_unlockedLevelNumbers.add(nextNumber)) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        _kUnlockedLevelsKey,
        _unlockedLevelNumbers.map((e) => e.toString()).toList(),
      );
    }
  }

  // ---------------------------------------------------------------------
  // GESTURE: HARF TANLASH JARAYONI
  // ---------------------------------------------------------------------

  /// Foydalanuvchi barmog'ini bosganda (PanStart) chaqiriladi.
  void startSelection(int letterIndex) {
    _selectedIndices.clear();
    _selectedIndices.add(letterIndex);
    _lastMessage = null;
    notifyListeners();
  }

  /// Barmoq harakatlanayotganda (PanUpdate -> hitTest natijasi) chaqiriladi.
  void extendSelection(int letterIndex) {
    if (_selectedIndices.isEmpty) {
      _selectedIndices.add(letterIndex);
      notifyListeners();
      return;
    }

    final last = _selectedIndices.last;
    if (last == letterIndex) return; // o'zgarish yo'q

    // Orqaga qaytish (oldingi harfga qayta tegish) - oxirgi harfni bekor qilish
    if (_selectedIndices.length > 1 &&
        _selectedIndices[_selectedIndices.length - 2] == letterIndex) {
      _selectedIndices.removeLast();
      notifyListeners();
      return;
    }

    // Bir xil harfni qayta tanlashga yo'l qo'ymaymiz
    if (_selectedIndices.contains(letterIndex)) return;

    _selectedIndices.add(letterIndex);
    notifyListeners();
  }

  /// Barmoq ko'tarilganda (PanEnd) chaqiriladi - so'zni tekshiradi.
  void endSelection() {
    if (_selectedIndices.length < 2) {
      _selectedIndices.clear();
      notifyListeners();
      return;
    }

    final word = currentSelectionWord;
    _checkWord(word);

    _selectedIndices.clear();
    notifyListeners();
  }

  void cancelSelection() {
    _selectedIndices.clear();
    notifyListeners();
  }

  // ---------------------------------------------------------------------
  // SO'Z TEKSHIRISH VA KROSSVORDNI OCHISH
  // ---------------------------------------------------------------------
  void _checkWord(String word) {
    final level = _currentLevel;
    if (level == null || word.isEmpty) return;

    final progress = _progressMap[level.id] ?? LevelProgress.empty(level.id);
    final normalizedWord = word.toUpperCase();

    final isValidWord = level.validWords
        .map((w) => w.toUpperCase())
        .contains(normalizedWord);
    final alreadyFound = progress.foundWords.contains(normalizedWord);

    if (isValidWord && !alreadyFound) {
      final updatedFound = [...progress.foundWords, normalizedWord];
      final isLevelComplete = updatedFound.length >= level.completionThreshold;
      final stars = _calculateStars(updatedFound.length, level.validWords.length);

      final updatedProgress = progress.copyWith(
        foundWords: updatedFound,
        isCompleted: isLevelComplete,
        starsEarned: stars,
      );
      _progressMap[level.id] = updatedProgress;
      _persistProgressForLevel(updatedProgress);

      _isLastWordCorrect = true;
      _lastMessage = "To'g'ri! \"$normalizedWord\" topildi";

      // So'z uzunligiga qarab tanga mukofoti
      _addCoins(normalizedWord.length * 2);

      if (isLevelComplete) {
        _unlockNextLevel();
        _addCoins(20); // level tugatish bonusi
        _lastMessage = "Ajoyib! Daraja yakunlandi 🎉";
        AdService.instance.notifyLevelCompleted();
      }
    } else if (alreadyFound) {
      _isLastWordCorrect = false;
      _lastMessage = "Bu so'z allaqachon topilgan";
    } else {
      _isLastWordCorrect = false;
      _lastMessage = "Bunday so'z yo'q";
    }
  }

  int _calculateStars(int foundCount, int totalCount) {
    if (totalCount == 0) return 0;
    final ratio = foundCount / totalCount;
    if (ratio >= 1.0) return 3;
    if (ratio >= 0.66) return 2;
    if (ratio >= 0.33) return 1;
    return 0;
  }

  // ---------------------------------------------------------------------
  // TANGALAR (COINS)
  // ---------------------------------------------------------------------
  Future<void> _addCoins(int amount) async {
    _coins += amount;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kCoinsKey, _coins);
    notifyListeners();
  }

  /// "Yordam/Podskazka" tugmasi: belgilangan narxda tasodifiy harf ochib beradi.
  /// Qaytariladi: muvaffaqiyatli bo'lsa ochilgan so'z, aks holda null.
  static const int hintCost = 15;

  bool get canAffordHint => _coins >= hintCost;

  /// Hali to'liq ochilmagan so'zlardan birini tanlab, undan bir harfni
  /// "ochiq" deb belgilash o'rniga - eng oson yondashuv sifatida toping
  /// imkoni bo'lmagan eng qisqa so'zni to'liq ochamiz (tanga evaziga).
  ///
  /// Bu real loyihalarda har bir katakka mos "letter reveal" indeksini
  /// alohida saqlash orqali ham amalga oshirilishi mumkin (kengaytma uchun
  /// pastdagi izohga qarang).
  /// Reklama ko'rib qo'shimcha tanga olish imkoniyatini taqdim etadi.
  /// [onEarned] reklama muvaffaqiyatli tomosha qilingach chaqiriladi,
  /// [onNotAvailable] reklama hozircha tayyor bo'lmasa chaqiriladi.
  void watchAdForCoins({
    required VoidCallback onEarned,
    required VoidCallback onNotAvailable,
  }) {
    AdService.instance.showRewardedAd(
      onRewardEarned: () {
        _addCoins(20);
        _lastMessage = "Tabriklaymiz! 20 tanga qo'shildi";
        notifyListeners();
        onEarned();
      },
      onAdNotReady: onNotAvailable,
    );
  }

  bool get isRewardedAdReady => AdService.instance.isRewardedAdReady;

  String? useHint() {
    final level = _currentLevel;
    if (level == null) return null;
    if (!canAffordHint) {
      _lastMessage = "Tangalar yetarli emas";
      notifyListeners();
      return null;
    }

    final progress = _progressMap[level.id] ?? LevelProgress.empty(level.id);
    final remaining = level.validWords
        .map((w) => w.toUpperCase())
        .where((w) => !progress.foundWords.contains(w))
        .toList();

    if (remaining.isEmpty) {
      _lastMessage = "Barcha so'zlar allaqachon topilgan";
      notifyListeners();
      return null;
    }

    // Eng qisqa qolgan so'zni tanlaymiz - "bir harf ochish" effektini
    // engillashtirish uchun (qisqa so'zlar tezroq taxminlanadi).
    remaining.sort((a, b) => a.length.compareTo(b.length));
    final revealedWord = remaining.first;

    final updatedFound = [...progress.foundWords, revealedWord];
    final isLevelComplete = updatedFound.length >= level.completionThreshold;
    final stars = _calculateStars(updatedFound.length, level.validWords.length);

    final updatedProgress = progress.copyWith(
      foundWords: updatedFound,
      isCompleted: isLevelComplete,
      starsEarned: stars,
    );
    _progressMap[level.id] = updatedProgress;
    _persistProgressForLevel(updatedProgress);

    _coins -= hintCost;
    _persistCoins();

    _lastMessage = "Yordam ishlatildi: \"$revealedWord\" ochildi";
    _isLastWordCorrect = true;

    if (isLevelComplete) {
      _unlockNextLevel();
      AdService.instance.notifyLevelCompleted();
    }

    notifyListeners();
    return revealedWord;
  }

  /// Bir harfni tasodifiy tanlab "yoritib qo'yish" (faqat vizual maslahat,
  /// so'zni avtomatik ochmaydi) - GameScreen'da CustomPainter orqali
  /// highlight qilish uchun ishlatiladi.
  int? hintHighlightLetterIndex() {
    final level = _currentLevel;
    if (level == null || level.circleLetters.isEmpty) return null;
    final random = Random();
    return random.nextInt(level.circleLetters.length);
  }

  Future<void> _persistCoins() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kCoinsKey, _coins);
    notifyListeners();
  }

  /// Reklama tomosha qilingandan keyin yoki boshqa tashqi manbadan
  /// tanga qo'shish uchun ochiq metod (masalan RewardedAd callback'ida).
  Future<void> addCoinsExternal(int amount) => _addCoins(amount);

  // ---------------------------------------------------------------------
  // KUNLIK MUKOFOT / STREAK
  // ---------------------------------------------------------------------

  /// SharedPreferences'dan streak holatini o'qiydi va bugun allaqachon
  /// olingan-olinmaganini sana solishtirish orqali aniqlaydi.
  DailyRewardState _loadDailyRewardState(SharedPreferences prefs) {
    final raw = prefs.getString(_kDailyRewardKey);
    if (raw == null) return DailyRewardState.initial();

    final json = jsonDecode(raw) as Map<String, dynamic>;
    final state = DailyRewardState.fromJson(json);

    if (state.lastClaimDate == null) return state;

    final now = DateTime.now();
    final last = state.lastClaimDate!;
    final isSameDay = now.year == last.year &&
        now.month == last.month &&
        now.day == last.day;

    return state.copyWith(claimedToday: isSameDay);
  }

  Future<void> _persistDailyRewardState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kDailyRewardKey, jsonEncode(_dailyReward.toJson()));
  }

  /// Kunlik mukofotni oladi. Agar oxirgi kirish kechagi kun bo'lsa streak
  /// davom etadi, aks holda (1 kundan ortiq tanaffus) streak qaytadan
  /// boshlanadi - bu odamni har kuni qaytib kelishga undaydigan klassik
  /// mexanika.
  int claimDailyReward() {
    if (_dailyReward.claimedToday) return 0;

    final now = DateTime.now();
    final last = _dailyReward.lastClaimDate;
    int newStreak;

    if (last == null) {
      newStreak = 1;
    } else {
      final yesterday = now.subtract(const Duration(days: 1));
      final wasYesterday = last.year == yesterday.year &&
          last.month == yesterday.month &&
          last.day == yesterday.day;
      newStreak = wasYesterday ? _dailyReward.currentStreak + 1 : 1;
    }

    final reward = DailyRewardState.rewardCycle[(newStreak - 1) % 7];

    _dailyReward = _dailyReward.copyWith(
      lastClaimDate: now,
      currentStreak: newStreak,
      longestStreak: max(newStreak, _dailyReward.longestStreak),
      claimedToday: true,
    );
    _persistDailyRewardState();
    _addCoins(reward);

    return reward;
  }

  void clearMessage() {
    _lastMessage = null;
    notifyListeners();
  }
}
DARTEOF
echo '=== lib/screens/game_screen.dart ==='
cat > lib/screens/game_screen.dart << 'DARTEOF'
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
  // YORDAM TUGMASI + REKLAMA ORQALI TANGA OLISH
  // -----------------------------------------------------------------
  Widget _buildHintButton(BuildContext context, GameProvider game) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Column(
        children: [
          SizedBox(
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
          if (!game.canAffordHint) ...[
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.gold,
                  side: const BorderSide(color: AppColors.gold),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
                  ),
                ),
                icon: const Icon(Icons.play_circle_outline_rounded),
                label: Text(
                  "Reklama ko'rib +20 tanga",
                  style: AppTypography.button(size: 14, color: AppColors.gold),
                ),
                onPressed: () {
                  game.watchAdForCoins(
                    onEarned: () => _showSnack("20 tanga qo'shildi!"),
                    onNotAvailable: () => _showSnack(
                      "Reklama hozircha tayyor emas, birozdan keyin urinib ko'ring",
                      isError: true,
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}
DARTEOF
echo '=== lib/screens/level_select_screen.dart ==='
cat > lib/screens/level_select_screen.dart << 'DARTEOF'
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
                    Text("So'z Topish", style: AppTypography.display(size: 24)),
                    const SizedBox(height: 2),
                    Text(
                      "Lug'atingizni sinab ko'ring",
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
DARTEOF
echo '=== lib/services/ad_service.dart ==='
cat > lib/services/ad_service.dart << 'DARTEOF'
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Butun ilova bo'ylab reklamalarni boshqaruvchi markaziy xizmat.
///
/// HOZIRGI HOLAT: Bu yerda Google'ning rasmiy TEST Ad Unit ID'lari
/// ishlatilgan - haqiqiy AdMob hisobi tasdiqlanmaguncha shu ID'lar
/// bilan ishlash xavfsiz (haqiqiy pul ishlamaydi, lekin reklama
/// to'liq funksional ko'rinishda ishlaydi).
///
/// PRODUCTIONGA CHIQISHDAN OLDIN:
/// 1. https://admob.google.com da hisob oching
/// 2. Ilova qo'shing, 2 ta "Ad unit" yarating (Rewarded, Interstitial)
/// 3. Pastdagi _testRewardedAdUnitId / _testInterstitialAdUnitId
///    qiymatlarini o'zingizning haqiqiy ID'laringiz bilan almashtiring
/// 4. android/app/src/main/AndroidManifest.xml ichiga AdMob App ID'ni
///    qo'shing (quyida AndroidManifest.xml namunasi bilan birga keladi)
class AdService {
  AdService._internal();
  static final AdService instance = AdService._internal();

  // --- TEST AD UNIT ID'LAR (Google rasmiy test ID'lari) ---
  // Manba: https://developers.google.com/admob/android/test-ads
  static const String _testRewardedAdUnitId =
      'ca-app-pub-3940256099942544/5224354917';
  static const String _testInterstitialAdUnitId =
      'ca-app-pub-3940256099942544/1033173712';

  // TODO: Productionga chiqishdan oldin shu ikki qatorni o'zgartiring:
  static const String _rewardedAdUnitId = _testRewardedAdUnitId;
  static const String _interstitialAdUnitId = _testInterstitialAdUnitId;

  RewardedAd? _rewardedAd;
  InterstitialAd? _interstitialAd;

  bool _isInitialized = false;
  int _levelsCompletedSinceLastInterstitial = 0;

  /// Har nechta daraja tugagandan keyin interstitial ko'rsatilsin.
  static const int interstitialFrequency = 3;

  Future<void> initialize() async {
    if (_isInitialized) return;
    // Web yoki desktopda reklama ishlamaydi - faqat Android/iOS.
    if (!_isMobilePlatform) return;

    await MobileAds.instance.initialize();
    _isInitialized = true;

    _loadRewardedAd();
    _loadInterstitialAd();
  }

  bool get _isMobilePlatform {
    if (kIsWeb) return false;
    return Platform.isAndroid || Platform.isIOS;
  }

  // ---------------------------------------------------------------------
  // REWARDED AD - "Reklama ko'rib tanga olish"
  // ---------------------------------------------------------------------
  void _loadRewardedAd() {
    if (!_isMobilePlatform) return;
    RewardedAd.load(
      adUnitId: _rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              _rewardedAd = null;
              _loadRewardedAd(); // keyingisini oldindan yuklab qo'yamiz
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              ad.dispose();
              _rewardedAd = null;
              _loadRewardedAd();
            },
          );
        },
        onAdFailedToLoad: (error) {
          _rewardedAd = null;
        },
      ),
    );
  }

  bool get isRewardedAdReady => _rewardedAd != null;

  /// Reklama ko'rsatadi va muvaffaqiyatli tomosha qilingandan keyin
  /// [onRewardEarned] chaqiriladi. Agar reklama tayyor bo'lmasa,
  /// [onAdNotReady] chaqiriladi (masalan internet yo'qligi sababli).
  void showRewardedAd({
    required VoidCallback onRewardEarned,
    required VoidCallback onAdNotReady,
  }) {
    if (_rewardedAd == null) {
      onAdNotReady();
      return;
    }
    _rewardedAd!.show(
      onUserEarnedReward: (ad, reward) {
        onRewardEarned();
      },
    );
  }

  // ---------------------------------------------------------------------
  // INTERSTITIAL AD - har necha darajadan keyin to'liq ekran
  // ---------------------------------------------------------------------
  void _loadInterstitialAd() {
    if (!_isMobilePlatform) return;
    InterstitialAd.load(
      adUnitId: _interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              _interstitialAd = null;
              _loadInterstitialAd();
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              ad.dispose();
              _interstitialAd = null;
              _loadInterstitialAd();
            },
          );
        },
        onAdFailedToLoad: (error) {
          _interstitialAd = null;
        },
      ),
    );
  }

  /// Har daraja tugagandan keyin chaqiriladi. Ichkarida hisoblagich
  /// yuritadi va faqat [interstitialFrequency]da bir marta reklama
  /// ko'rsatadi - bu foydalanuvchini bezovta qilmaslik uchun muhim.
  void notifyLevelCompleted() {
    _levelsCompletedSinceLastInterstitial++;
    if (_levelsCompletedSinceLastInterstitial >= interstitialFrequency) {
      _maybeShowInterstitial();
    }
  }

  void _maybeShowInterstitial() {
    if (_interstitialAd == null) return;
    _levelsCompletedSinceLastInterstitial = 0;
    _interstitialAd!.show();
  }

  void dispose() {
    _rewardedAd?.dispose();
    _interstitialAd?.dispose();
  }
}
DARTEOF
echo '=== lib/theme/app_theme.dart ==='
cat > lib/theme/app_theme.dart << 'DARTEOF'
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Klassik, professional dizayn tizimi - 20+ yosh auditoriya uchun.
/// Oq fon, to'q matn, minimal rangli urg'u. Ko'z charchamaydigan,
/// jiddiy va ishonchli ko'rinish.
class AppColors {
  static const Color background = Color(0xFFFFFFFF);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceMuted = Color(0xFFF2F3F5);

  // Yagona, jiddiy urg'u rangi - to'q ko'k-kulrang
  static const Color primary = Color(0xFF2B2D42);
  static const Color primaryDark = Color(0xFF1A1B2E);
  static const Color secondary = Color(0xFF4361EE);
  static const Color secondaryDark = Color(0xFF3A50C9);
  static const Color gold = Color(0xFFB8860B);
  static const Color goldDark = Color(0xFF9A6F09);

  static const Color leafLight = Color(0xFF6C7A89);
  static const Color leafDark = Color(0xFF4A5568);

  static const Color textPrimary = Color(0xFF1A1B2E);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textOnDark = Color(0xFFFFFFFF);

  static const Color success = Color(0xFF2D9D78);
  static const Color error = Color(0xFFD64545);
  static const Color locked = Color(0xFFE2E4E8);
  static const Color border = Color(0xFFE5E7EB);

  static const LinearGradient letterCircleGradient = LinearGradient(
    colors: [leafLight, leafDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient selectedLetterGradient = LinearGradient(
    colors: [secondary, secondaryDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient goldGradient = LinearGradient(
    colors: [gold, goldDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

class AppTypography {
  static TextStyle display({double size = 26, Color? color}) =>
      GoogleFonts.inter(
        fontSize: size,
        fontWeight: FontWeight.w700,
        color: color ?? AppColors.textPrimary,
        height: 1.15,
        letterSpacing: -0.5,
      );

  static TextStyle button({double size = 16, Color? color}) =>
      GoogleFonts.inter(
        fontSize: size,
        fontWeight: FontWeight.w600,
        color: color ?? AppColors.textOnDark,
      );

  static TextStyle body({double size = 14, Color? color, FontWeight? weight}) =>
      GoogleFonts.inter(
        fontSize: size,
        fontWeight: weight ?? FontWeight.w400,
        color: color ?? AppColors.textSecondary,
      );

  static TextStyle letter({double size = 22, Color? color}) =>
      GoogleFonts.inter(
        fontSize: size,
        fontWeight: FontWeight.w700,
        color: color ?? AppColors.textOnDark,
      );
}

class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;

  static const double radiusSm = 8;
  static const double radiusMd = 14;
  static const double radiusLg = 20;
  static const double radiusPill = 100;
}

class AppMotion {
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration normal = Duration(milliseconds: 300);
  static const Duration slow = Duration(milliseconds: 600);
  static const Duration celebration = Duration(milliseconds: 900);

  static const Curve bounce = Curves.elasticOut;
  static const Curve smooth = Curves.easeOutCubic;
  static const Curve snap = Curves.easeOutBack;
}

/// Yumshoq soya - oq fonda nozik chegara hissi beradi.
List<BoxShadow> softShadow({double opacity = 0.06, double blur = 12}) => [
      BoxShadow(
        color: AppColors.textPrimary.withOpacity(opacity),
        blurRadius: blur,
        offset: const Offset(0, 4),
      ),
    ];
DARTEOF
echo '=== lib/utils/circle_layout_helper.dart ==='
cat > lib/utils/circle_layout_helper.dart << 'DARTEOF'
import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Harflarni aylana shaklida joylashtirish uchun geometrik hisob-kitoblar.
///
/// CustomPainter va GestureDetector ikkisi ham bitta koordinata manbasidan
/// foydalanishi kerak, shu sababli bu klass markaziy "single source of truth"
/// vazifasini bajaradi.
class CircleLayoutHelper {
  final Size size;
  final int letterCount;
  final double letterRadius; // har bir harf doirachasining radiusi

  CircleLayoutHelper({
    required this.size,
    required this.letterCount,
    this.letterRadius = 28,
  });

  Offset get center => Offset(size.width / 2, size.height / 2);

  /// Harflar joylashadigan asosiy aylananing radiusi.
  double get ringRadius {
    final shortestSide = math.min(size.width, size.height);
    return (shortestSide / 2) - letterRadius - 8;
  }

  /// i-indeksdagi harfning markaz koordinatasi.
  Offset positionFor(int index) {
    final angleStep = (2 * math.pi) / letterCount;
    // -pi/2 dan boshlanishi - birinchi harf tepada joylashishi uchun
    final angle = -math.pi / 2 + (angleStep * index);
    final dx = center.dx + ringRadius * math.cos(angle);
    final dy = center.dy + ringRadius * math.sin(angle);
    return Offset(dx, dy);
  }

  /// Berilgan global nuqta qaysi harf doirachasi ichida turganini topadi.
  /// Topilmasa null qaytaradi.
  int? hitTest(Offset point) {
    for (int i = 0; i < letterCount; i++) {
      final pos = positionFor(i);
      final distance = (point - pos).distance;
      if (distance <= letterRadius + 6) {
        return i;
      }
    }
    return null;
  }
}
DARTEOF
echo '=== lib/widgets/daily_reward_dialog.dart ==='
cat > lib/widgets/daily_reward_dialog.dart << 'DARTEOF'
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
DARTEOF
echo '=== lib/widgets/flower_celebration_overlay.dart ==='
cat > lib/widgets/flower_celebration_overlay.dart << 'DARTEOF'
import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Daraja muvaffaqiyatli tugaganda ko'rsatiladigan "gul ochilishi" animatsiyasi.
///
/// Bu o'yinning vizual imzosi: progress = o'sish metaforasi. Yopiq filiz
/// holatidan boshlanib, gul barglari ochilib, atrofida zarrachalar
/// (konfetti emas, kichik bargchalar) tarqaladi - bog'/tabiat temasiga mos.
class FlowerCelebrationOverlay extends StatefulWidget {
  final int starsEarned;
  final VoidCallback onContinue;
  final VoidCallback? onNextLevel;

  const FlowerCelebrationOverlay({
    super.key,
    required this.starsEarned,
    required this.onContinue,
    this.onNextLevel,
  });

  @override
  State<FlowerCelebrationOverlay> createState() =>
      _FlowerCelebrationOverlayState();
}

class _FlowerCelebrationOverlayState extends State<FlowerCelebrationOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppMotion.celebration,
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withOpacity(0.6),
      child: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final bloom = Curves.elasticOut.transform(
              _controller.value.clamp(0.0, 1.0),
            );
            return Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                ..._buildPetalBurst(bloom),
                _buildCard(bloom),
              ],
            );
          },
        ),
      ),
    );
  }

  List<Widget> _buildPetalBurst(double bloom) {
    const petalCount = 8;
    return List.generate(petalCount, (i) {
      final angle = (2 * math.pi / petalCount) * i;
      final distance = 110 * bloom;
      final dx = math.cos(angle) * distance;
      final dy = math.sin(angle) * distance;
      return Transform.translate(
        offset: Offset(dx, dy),
        child: Opacity(
          opacity: (1 - bloom).clamp(0.0, 1.0) < 0.05
              ? 0
              : (bloom).clamp(0.0, 1.0),
          child: Icon(
            Icons.star_rounded,
            size: 16 + (10 * bloom),
            color: AppColors.gold,
          ),
        ),
      );
    });
  }

  Widget _buildCard(double bloom) {
    return Transform.scale(
      scale: 0.6 + (0.4 * bloom),
      child: Container(
        width: 280,
        padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.lg,
          horizontal: AppSpacing.lg,
        ),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          boxShadow: softShadow(opacity: 0.25, blur: 30),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.success.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_rounded, color: AppColors.success, size: 36),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text("Daraja yakunlandi!", style: AppTypography.display(size: 20)),
            const SizedBox(height: AppSpacing.md),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(3, (i) {
                final filled = i < widget.starsEarned;
                return Icon(
                  Icons.star_rounded,
                  size: 36,
                  color: filled ? AppColors.gold : AppColors.surfaceMuted,
                );
              }),
            ),
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
                  ),
                  elevation: 0,
                ),
                onPressed: widget.onNextLevel ?? widget.onContinue,
                child: Text(
                  widget.onNextLevel != null
                      ? "Keyingi daraja"
                      : "Davom etish",
                  style: AppTypography.button(),
                ),
              ),
            ),
            if (widget.onNextLevel != null) ...[
              const SizedBox(height: AppSpacing.xs),
              TextButton(
                onPressed: widget.onContinue,
                child: Text(
                  "Darajalar ro'yxatiga qaytish",
                  style: AppTypography.body(size: 13),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
DARTEOF
echo '=== lib/widgets/word_circle_painter.dart ==='
cat > lib/widgets/word_circle_painter.dart << 'DARTEOF'
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../utils/circle_layout_helper.dart';

/// Aylanadagi harflarni, ular orasidagi ulanish chiziqlarini va
/// barmoq harakatini chizuvchi CustomPainter.
///
/// Rang sxemasi AppColors dizayn tizimidan olinadi - "So'z Bog'i" temasi:
/// harf doirachalari yashil-bog' gradienti, tanlangan harflar korall-qizil,
/// ulanish chizig'i esa iliq oltin rangda.
class WordCirclePainter extends CustomPainter {
  final List<String> letters;
  final List<int> selectedIndices;
  final Offset? currentDragPosition;
  final int? hintLetterIndex;

  WordCirclePainter({
    required this.letters,
    required this.selectedIndices,
    this.currentDragPosition,
    this.hintLetterIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (letters.isEmpty) return;

    final layout = CircleLayoutHelper(size: size, letterCount: letters.length);

    _drawConnectionLines(canvas, layout);
    _drawDragTail(canvas, layout);
    _drawLetterCircles(canvas, layout);
  }

  /// Tanlangan harflar orasidagi chiziqlarni chizadi (smooth, soyali chiziq).
  void _drawConnectionLines(Canvas canvas, CircleLayoutHelper layout) {
    if (selectedIndices.length < 2) return;

    final linePaint = Paint()
      ..color = AppColors.gold.withOpacity(0.9)
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5);

    final path = Path();
    final firstPos = layout.positionFor(selectedIndices.first);
    path.moveTo(firstPos.dx, firstPos.dy);

    for (int i = 1; i < selectedIndices.length; i++) {
      final pos = layout.positionFor(selectedIndices[i]);
      path.lineTo(pos.dx, pos.dy);
    }
    canvas.drawPath(path, linePaint);

    final highlightPaint = Paint()
      ..color = Colors.white.withOpacity(0.6)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawPath(path, highlightPaint);
  }

  /// Barmoq hozirgi pozitsiyasidan oxirgi tanlangan harfgacha "dum" chizig'i.
  void _drawDragTail(Canvas canvas, CircleLayoutHelper layout) {
    if (selectedIndices.isEmpty || currentDragPosition == null) return;

    final lastPos = layout.positionFor(selectedIndices.last);
    final tailPaint = Paint()
      ..color = AppColors.gold.withOpacity(0.5)
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    canvas.drawLine(lastPos, currentDragPosition!, tailPaint);
  }

  /// Har bir harfni doirachada chizadi (tanlangan/hint holatlarini hisobga olib).
  void _drawLetterCircles(Canvas canvas, CircleLayoutHelper layout) {
    for (int i = 0; i < letters.length; i++) {
      final pos = layout.positionFor(i);
      final isSelected = selectedIndices.contains(i);
      final isHint = hintLetterIndex == i;

      final List<Color> gradientColors = isSelected
          ? [AppColors.primary, AppColors.primaryDark]
          : isHint
              ? [AppColors.gold, AppColors.goldDark]
              : [AppColors.leafLight, AppColors.leafDark];

      final circlePaint = Paint()
        ..style = PaintingStyle.fill
        ..shader = LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(
          Rect.fromCircle(center: pos, radius: layout.letterRadius),
        );

      // Yumshoq soya - "qog'oz ustida" his
      canvas.drawCircle(
        pos.translate(0, isSelected ? 2 : 4),
        layout.letterRadius,
        Paint()..color = AppColors.textPrimary.withOpacity(isSelected ? 0.12 : 0.18),
      );

      canvas.drawCircle(pos, layout.letterRadius, circlePaint);

      final borderPaint = Paint()
        ..color = isSelected ? Colors.white.withOpacity(0.95) : Colors.white.withOpacity(0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = isSelected ? 3 : 2;
      canvas.drawCircle(pos, layout.letterRadius, borderPaint);

      final textPainter = TextPainter(
        text: TextSpan(
          text: letters[i],
          style: AppTypography.letter(size: letters[i].length > 1 ? 18 : 22),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      final textOffset = Offset(
        pos.dx - textPainter.width / 2,
        pos.dy - textPainter.height / 2,
      );
      textPainter.paint(canvas, textOffset);
    }
  }

  @override
  bool shouldRepaint(covariant WordCirclePainter oldDelegate) {
    return oldDelegate.letters != letters ||
        oldDelegate.selectedIndices != selectedIndices ||
        oldDelegate.currentDragPosition != currentDragPosition ||
        oldDelegate.hintLetterIndex != hintLetterIndex;
  }
}

DARTEOF
echo '=== lib/widgets/word_grid_panel.dart ==='
cat > lib/widgets/word_grid_panel.dart << 'DARTEOF'
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Topilishi kerak bo'lgan so'zlar uchun krossvord-uslubidagi katakchalar
/// panelini chizadi. So'z topilganda mos katakchalar harflarga to'ladi,
/// topilmagan bo'lsa bo'sh (faqat chiziq) ko'rinishda qoladi.
class WordGridPanel extends StatelessWidget {
  final List<String> allWords;
  final List<String> foundWords;

  const WordGridPanel({
    super.key,
    required this.allWords,
    required this.foundWords,
  });

  @override
  Widget build(BuildContext context) {
    final sorted = [...allWords]
      ..sort((a, b) => a.length.compareTo(b.length));

    return Wrap(
      alignment: WrapAlignment.center,
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
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

DARTEOF
echo '=== TAYYOR ==='
echo '=== pubspec.yaml ==='
cat > pubspec.yaml << 'YAMLEOF'
name: soz_topish_new
description: "So'z topish o'yini - Lotin va Kirill o'zbek alifbosi bilan offline so'z topish o'yini"
publish_to: 'none'
version: 1.0.0+1

environment:
  sdk: ^3.12.2

dependencies:
  flutter:
    sdk: flutter

  provider: ^6.1.2
  sqflite: ^2.4.3
  path: ^1.9.0
  shared_preferences: ^2.2.3
  google_fonts: ^6.2.1
  google_mobile_ads: ^5.2.0
  cupertino_icons: ^1.0.8

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^6.0.0

flutter:
  uses-material-design: true

  assets:
    - assets/data/words_lotin.json
    - assets/data/words_kiril.json
YAMLEOF
echo 'Hammasi yozildi. Endi: flutter pub get'
