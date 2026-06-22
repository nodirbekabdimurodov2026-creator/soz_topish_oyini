import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Foydalanuvchi faolligini kuzatuvchi xizmat - Firebase Analytics orqali.
///
/// Firebase Analytics konsoli (console.firebase.google.com) orqali siz
/// quyidagilarni ko'rishingiz mumkin: kunlik/oylik faol foydalanuvchilar
/// soni, o'rtacha sessiya davomiyligi, qaysi darajada odamlar to'xtab
/// qolishi, va boshqa ko'p narsa - barchasi tayyor dashboard'da.
///
/// Bundan tashqari, lokal (qurilmaning o'zida) statistika ham saqlanadi -
/// bu foydalanuvchining o'ziga "Statistika" ekranida ko'rsatish uchun
/// foydali bo'lishi mumkin.
class AnalyticsService {
  AnalyticsService._internal();
  static final AnalyticsService instance = AnalyticsService._internal();

  FirebaseAnalytics? _analytics;

  static const _kTotalSessionsKey = 'analytics_total_sessions';
  static const _kTotalPlayTimeSecondsKey = 'analytics_total_playtime_seconds';
  static const _kLevelsCompletedKey = 'analytics_levels_completed';
  static const _kFirstOpenDateKey = 'analytics_first_open_date';
  static const _kLastOpenDateKey = 'analytics_last_open_date';

  DateTime? _sessionStartTime;

  void attachFirebaseAnalytics(FirebaseAnalytics analytics) {
    _analytics = analytics;
  }

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

    await _analytics?.logEvent(name: 'session_start');
  }

  /// Ilova background'ga ketganda yoki yopilganda chaqiriladi.
  Future<void> trackSessionEnd() async {
    if (_sessionStartTime == null) return;
    final duration = DateTime.now().difference(_sessionStartTime!);
    final prefs = await SharedPreferences.getInstance();

    final totalSeconds = (prefs.getInt(_kTotalPlayTimeSecondsKey) ?? 0) + duration.inSeconds;
    await prefs.setInt(_kTotalPlayTimeSecondsKey, totalSeconds);

    await _analytics?.logEvent(
      name: 'session_end',
      parameters: {'duration_seconds': duration.inSeconds},
    );
    _sessionStartTime = null;
  }

  /// Daraja tugatilganda chaqiriladi.
  Future<void> trackLevelCompleted(int levelNumber, String alphabetKey) async {
    final prefs = await SharedPreferences.getInstance();
    final count = (prefs.getInt(_kLevelsCompletedKey) ?? 0) + 1;
    await prefs.setInt(_kLevelsCompletedKey, count);

    await _analytics?.logEvent(
      name: 'level_completed',
      parameters: {
        'level': levelNumber,
        'alphabet': alphabetKey,
      },
    );
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
}
