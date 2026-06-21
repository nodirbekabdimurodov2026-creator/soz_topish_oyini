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
