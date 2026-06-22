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
