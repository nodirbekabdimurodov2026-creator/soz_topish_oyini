#!/data/data/com.termux/files/usr/bin/bash
set -e
echo "=== Eski lib papkasi tozalanmoqda ==="
rm -rf lib
mkdir -p lib/database lib/models lib/providers lib/screens lib/services lib/theme lib/utils lib/widgets
echo "=== Papkalar yaratildi ==="
echo '=== lib/main.dart ==='
cat > lib/main.dart << 'DARTEOF'
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'providers/game_provider.dart';
import 'screens/level_select_screen.dart';
import 'services/ad_service.dart';
import 'services/analytics_service.dart';
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
  AnalyticsService.instance.trackSessionStart();

  runApp(const SozTopishApp());
}

class SozTopishApp extends StatefulWidget {
  const SozTopishApp({super.key});

  @override
  State<SozTopishApp> createState() => _SozTopishAppState();
}

class _SozTopishAppState extends State<SozTopishApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Foydalanuvchi ilovani fon rejimiga o'tkazganda yoki yopganda
    // o'ynagan vaqtini yakunlab, lokal statistikaga yozamiz.
    if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      AnalyticsService.instance.trackSessionEnd();
    } else if (state == AppLifecycleState.resumed) {
      AnalyticsService.instance.trackSessionStart();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => GameProvider(),
      child: MaterialApp(
        title: "So'zni Top",
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
import '../services/analytics_service.dart';

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
        AnalyticsService.instance.trackLevelCompleted(level.levelNumber, level.alphabetKey);
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
      AnalyticsService.instance.trackLevelCompleted(level.levelNumber, level.alphabetKey);
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
                    Text("So'zni Top", style: AppTypography.display(size: 24)),
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
echo '=== lib/services/analytics_service.dart ==='
cat > lib/services/analytics_service.dart << 'DARTEOF'
import 'package:shared_preferences/shared_preferences.dart';

/// Foydalanuvchi faolligini kuzatuvchi xizmat.
///
/// HOZIRGI HOLAT: faqat qurilmaning o'zida (shared_preferences) statistika
/// to'planadi - server yo'q. Bu o'yin ichida "Statistika" ekranida
/// foydalanuvchining o'ziga ko'rsatish uchun foydali, lekin Sizga (dasturchiga)
/// boshqa foydalanuvchilar haqida ma'lumot bermaydi.
///
/// KELAJAKDA SERVERGA ULASH UCHUN: pastdagi [_sendToServer] metodini
/// to'ldiring (masalan http.post orqali o'z backendingizga, yoki Firebase
/// Analytics/Supabase kabi tayyor xizmatga). Bu klassning boshqa joylardan
/// chaqirilishi o'zgarmaydi - faqat shu bitta metod ichini to'ldirish kifoya.
class AnalyticsService {
  AnalyticsService._internal();
  static final AnalyticsService instance = AnalyticsService._internal();

  static const _kTotalSessionsKey = 'analytics_total_sessions';
  static const _kTotalPlayTimeSecondsKey = 'analytics_total_playtime_seconds';
  static const _kLevelsCompletedKey = 'analytics_levels_completed';
  static const _kFirstOpenDateKey = 'analytics_first_open_date';
  static const _kLastOpenDateKey = 'analytics_last_open_date';

  DateTime? _sessionStartTime;

  /// Ilova ochilganda chaqiriladi - sessiya hisoblagichini boshlaydi.
  Future<void> trackSessionStart() async {
    _sessionStartTime = DateTime.now();
    final prefs = await SharedPreferences.getInstance();

    final totalSessions = (prefs.getInt(_kTotalSessionsKey) ?? 0) + 1;
    await prefs.setInt(_kTotalSessionsKey, totalSessions);

    final firstOpen = prefs.getString(_kFirstOpenDateKey);
    if (firstOpen == null) {
      await prefs.setString(_kFirstOpenDateKey, DateTime.now().toIso8601String());
    }
    await prefs.setString(_kLastOpenDateKey, DateTime.now().toIso8601String());

    _sendToServer('session_start', {});
  }

  /// Ilova background'ga ketganda yoki yopilganda chaqiriladi.
  Future<void> trackSessionEnd() async {
    if (_sessionStartTime == null) return;
    final duration = DateTime.now().difference(_sessionStartTime!);
    final prefs = await SharedPreferences.getInstance();

    final totalSeconds = (prefs.getInt(_kTotalPlayTimeSecondsKey) ?? 0) + duration.inSeconds;
    await prefs.setInt(_kTotalPlayTimeSecondsKey, totalSeconds);

    _sendToServer('session_end', {'duration_seconds': duration.inSeconds});
    _sessionStartTime = null;
  }

  /// Daraja tugatilganda chaqiriladi.
  Future<void> trackLevelCompleted(int levelNumber, String alphabetKey) async {
    final prefs = await SharedPreferences.getInstance();
    final count = (prefs.getInt(_kLevelsCompletedKey) ?? 0) + 1;
    await prefs.setInt(_kLevelsCompletedKey, count);

    _sendToServer('level_completed', {
      'level': levelNumber,
      'alphabet': alphabetKey,
    });
  }

  /// Statistika ekranida foydalanuvchiga o'zining faolligini ko'rsatish uchun.
  Future<Map<String, dynamic>> getLocalStats() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'totalSessions': prefs.getInt(_kTotalSessionsKey) ?? 0,
      'totalPlayTimeSeconds': prefs.getInt(_kTotalPlayTimeSecondsKey) ?? 0,
      'levelsCompleted': prefs.getInt(_kLevelsCompletedKey) ?? 0,
      'firstOpenDate': prefs.getString(_kFirstOpenDateKey),
      'lastOpenDate': prefs.getString(_kLastOpenDateKey),
    };
  }

  /// TODO: Bu yerga serverga yuborish mantiqini qo'shing, masalan:
  ///
  /// final response = await http.post(
  ///   Uri.parse('https://your-server.com/api/events'),
  ///   body: jsonEncode({'event': eventName, 'data': data, 'timestamp': DateTime.now().toIso8601String()}),
  /// );
  ///
  /// Hozircha hech narsa qilmaydi - faqat kelajak uchun joy.
  void _sendToServer(String eventName, Map<String, dynamic> data) {
    // Hozircha bo'sh - internet/server tayyor bo'lganda to'ldiriladi.
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
  google_mobile_ads: ^6.0.0
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
echo '=== AndroidManifest.xml ==='
mkdir -p android/app/src/main
cat > android/app/src/main/AndroidManifest.xml << 'XMLEOF'
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <application
        android:label="So'zni Top"
        android:name="${applicationName}"
        android:icon="@mipmap/ic_launcher">
        <meta-data
            android:name="com.google.android.gms.ads.APPLICATION_ID"
            android:value="ca-app-pub-3940256099942544~3347511713"/>
        <activity
            android:name=".MainActivity"
            android:exported="true"
            android:launchMode="singleTop"
            android:taskAffinity=""
            android:theme="@style/LaunchTheme"
            android:configChanges="orientation|keyboardHidden|keyboard|screenSize|smallestScreenSize|locale|layoutDirection|fontScale|screenLayout|density|uiMode"
            android:hardwareAccelerated="true"
            android:windowSoftInputMode="adjustResize">
            <meta-data
              android:name="io.flutter.embedding.android.NormalTheme"
              android:resource="@style/NormalTheme"
              />
            <intent-filter>
                <action android:name="android.intent.action.MAIN"/>
                <category android:name="android.intent.category.LAUNCHER"/>
            </intent-filter>
        </activity>
        <meta-data
            android:name="flutterEmbedding"
            android:value="2" />
    </application>
    <queries>
        <intent>
            <action android:name="android.intent.action.PROCESS_TEXT"/>
            <data android:mimeType="text/plain"/>
        </intent>
    </queries>
</manifest>
XMLEOF
echo '=== HAMMASI TAYYOR - endi: flutter pub get ==='
echo '=== Ikonkalar yaratilmoqda ==='
mkdir -p android/app/src/main/res/mipmap-mdpi android/app/src/main/res/mipmap-hdpi android/app/src/main/res/mipmap-xhdpi android/app/src/main/res/mipmap-xxhdpi android/app/src/main/res/mipmap-xxxhdpi
echo '=== Ikonkalar yaratilmoqda ==='
mkdir -p android/app/src/main/res/mipmap-mdpi android/app/src/main/res/mipmap-hdpi android/app/src/main/res/mipmap-xhdpi android/app/src/main/res/mipmap-xxhdpi android/app/src/main/res/mipmap-xxxhdpi
base64 -d > android/app/src/main/res/mipmap-mdpi/ic_launcher.png << 'B64EOF'
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
B64EOF
base64 -d > android/app/src/main/res/mipmap-hdpi/ic_launcher.png << 'B64EOF'
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
B64EOF
base64 -d > android/app/src/main/res/mipmap-xhdpi/ic_launcher.png << 'B64EOF'
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
B64EOF
base64 -d > android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png << 'B64EOF'
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
B64EOF
base64 -d > android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png << 'B64EOF'
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
B64EOF
echo '=== IKONKALAR TAYYOR ==='
