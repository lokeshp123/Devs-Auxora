import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'home_scrren.dart';
import 'login_scrren.dart';
import 'theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SharedPreferences prefs = await SharedPreferences.getInstance();
  bool isLoggedIn = prefs.getBool('isLoggedIn') ?? false;

  runApp(SkyDevsApp(isLoggedIn: isLoggedIn));
}

class SkyDevsApp extends StatelessWidget {
  final bool isLoggedIn;

  const SkyDevsApp({Key? key, required this.isLoggedIn}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SkyDevs Console',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: AppColors.background,
        fontFamily: 'monospace', // Gives that developer/code feel
        colorScheme: const ColorScheme.dark(
          primary: AppColors.accentCyan,
          background: AppColors.background,
          surface: AppColors.surface,
        ),
      ),
      home: isLoggedIn ? const SkyDevsHomeScreen() : const SkyDevsLoginScreen(),
    );
  }
}