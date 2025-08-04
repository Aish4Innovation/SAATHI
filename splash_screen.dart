// ignore_for_file: use_build_context_synchronously, library_private_types_in_public_api

import 'package:flutter/material.dart';
import 'package:saathi_app/screens/home_screen.dart';
import 'package:saathi_app/screens/onboarding/setup_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {

  @override
  void initState() {
    super.initState();
    _checkUserStatus();
  }

  Future<void> _checkUserStatus() async {
    // Check for user ID immediately
    final prefs = await SharedPreferences.getInstance();
    final int? userId = prefs.getInt('userId');

    // Wait for a few seconds to show the splash screen before navigating
    await Future.delayed(const Duration(seconds: 3));

    if (userId != null) {
      // User has already completed onboarding, go to the home screen
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => HomeScreen(userId: userId),
        ),
      );
    } else {
      // New user, go to the onboarding setup screen
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => const SetupScreen(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryColor = Color(0xFFE91E63);
    const Color backgroundColor = Colors.black;

    return const Scaffold(
      backgroundColor: backgroundColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(
              Icons.healing,
              size: 100.0,
              color: primaryColor,
            ),
            SizedBox(height: 20.0),
            Text(
              'Saathi',
              style: TextStyle(
                fontSize: 48.0,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 2.0,
              ),
            ),
            SizedBox(height: 10.0),
            Text(
              'Your Smart Medicine & Wellness Reminder',
              style: TextStyle(
                fontSize: 16.0,
                fontStyle: FontStyle.italic,
                color: Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
  }
}