import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../database/database_helper.dart';
import '../models/alphabet_mode.dart';
import '../models/daily_reward_state.dart';
import '../models/level_model.dart';
import '../models/level_progress.dart';

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
      final isLevelComplete = updatedFound.length >= level.validWords.length;
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
    final isLevelComplete = updatedFound.length >= level.validWords.length;
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
