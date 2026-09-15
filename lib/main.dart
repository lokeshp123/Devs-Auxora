import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async'; // Added for the splash screen timer

import 'home_scrren.dart';
import 'login_scrren.dart';
import 'theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Preserved internal logic
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
      title: 'AuxoraDevs Console', // Updated to match your new logo
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
      // Set the home to the new SplashScreen, passing the login state
      home: SplashScreen(isLoggedIn: isLoggedIn),
    );
  }
}

// ------------------------------------------------------------------------
// Splash Screen Widget
// ------------------------------------------------------------------------
class SplashScreen extends StatefulWidget {
  final bool isLoggedIn;

  const SplashScreen({Key? key, required this.isLoggedIn}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();

    // Navigate to the correct screen after a 3-second delay
    Timer(const Duration(seconds: 3), () {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => widget.isLoggedIn
              ? const SkyDevsHomeScreen()
              : const SkyDevsLoginScreen(),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // Clean white background for the logo
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Ensure you add the downloaded logo to your assets folder
            // and declare it in pubspec.yaml
            Image.asset(
              'assets/Appicons.png', // Update with your actual asset filename
              width: 400,
            ),
            const SizedBox(height: 30),
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.blueGrey),
            ),
          ],
        ),
      ),
    );
  }
}