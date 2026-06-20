import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'providers/game_provider.dart';
import 'screens/level_select_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // O'yin faqat vertikal rejimda ishlashi uchun (UX talabi)
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(const SozTopishApp());
}

class SozTopishApp extends StatelessWidget {
  const SozTopishApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => GameProvider(),
      child: MaterialApp(
        title: "So'z topish o'yini",
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          scaffoldBackgroundColor: const Color(0xFF1B1C2E),
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF6C5CE7),
            brightness: Brightness.dark,
          ),
          fontFamily: 'Roboto',
        ),
        home: const LevelSelectScreen(),
      ),
    );
  }
}
