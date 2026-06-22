import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
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

  // Firebase'ni ishga tushiramiz - agar google-services.json fayli
  // android/app/ ichida bo'lmasa, bu xato beradi, shuning uchun
  // try-catch bilan o'raymiz (ilova Firebase'siz ham ishlayversin).
  try {
    await Firebase.initializeApp();
    AnalyticsService.instance.attachFirebaseAnalytics(FirebaseAnalytics.instance);
  } catch (e) {
    // Firebase hali sozlanmagan bo'lsa, ilova baribir ishlayveradi -
    // faqat statistika serverga yuborilmaydi, lokal saqlanishda davom etadi.
  }

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
