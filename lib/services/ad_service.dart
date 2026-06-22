import 'package:flutter/foundation.dart';

/// Reklama xizmati - HOZIRGI HOLAT: VAQTINCHA O'CHIRILGAN (stub).
///
/// SABAB: google_mobile_ads paketi joriy Android Gradle Plugin versiyasi
/// bilan mos kelmasligi sababli build xatosi berayotgan edi
/// ("Could not get unknown property 'all' for configuration container").
/// Bu paketning ichki Gradle skripti bilan bog'liq, bizning kodimizdagi
/// xato emas.
///
/// Bu klass hozircha hech narsa qilmaydi (reklama ko'rsatmaydi), lekin
/// boshqa kod (game_provider.dart, main.dart) bu klassni xuddi avvalgidek
/// chaqirishda davom etadi - shu sababli ular o'zgarishsiz qoladi.
///
/// QAYTA YOQISH UCHUN: pubspec.yaml'ga google_mobile_ads qaytaring va
/// quyidagi metodlarning ichini googleads paketining haqiqiy chaqiruvlari
/// bilan to'ldiring (oldingi versiyada bo'lgani kabi).
class AdService {
  AdService._internal();
  static final AdService instance = AdService._internal();

  static const int interstitialFrequency = 3;
  int _levelsCompletedSinceLastInterstitial = 0;

  Future<void> initialize() async {
    // Hozircha hech narsa qilinmaydi.
  }

  bool get isRewardedAdReady => false;

  void showRewardedAd({
    required VoidCallback onRewardEarned,
    required VoidCallback onAdNotReady,
  }) {
    // Reklama hali ulanmagan - har doim "tayyor emas" deb javob beramiz.
    onAdNotReady();
  }

  void notifyLevelCompleted() {
    _levelsCompletedSinceLastInterstitial++;
    // Hozircha reklama ko'rsatilmaydi.
  }

  void dispose() {}
}
