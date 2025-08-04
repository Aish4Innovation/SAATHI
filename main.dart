// lib/main.dart

// ignore_for_file: avoid_print

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:saathi_app/constants.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:saathi_app/screens/home_screen.dart'; 
import 'package:workmanager/workmanager.dart';
import 'package:just_audio/just_audio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:saathi_app/screens/splash_screen.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

final FlutterTts flutterTts = FlutterTts();
final AudioPlayer _audioPlayer = AudioPlayer();

// Global function to play a voice note (called from notification handler)
Future<void> _playVoiceNote(String? voiceNoteUrl) async {
  if (voiceNoteUrl == null || voiceNoteUrl.isEmpty) {
    print('No voice note to play.');
    return;
  }

  try {
    if (kIsWeb) {
      await _audioPlayer.setUrl(voiceNoteUrl);
    } else {
      // For mobile, check if it's a local file path or a URL
      if (voiceNoteUrl.startsWith('http')) {
        await _audioPlayer.setUrl(voiceNoteUrl);
      } else {
        await _audioPlayer.setFilePath(voiceNoteUrl);
      }
    }
    await _audioPlayer.play();
  } catch (e) {
    print('Error playing audio: $e');
  }
}

@pragma('vm:entry-point')
void onDidReceiveNotificationResponse(NotificationResponse notificationResponse) async {
  final String? payload = notificationResponse.payload;
  if (payload != null) {
    final Map<String, dynamic> data = jsonDecode(payload);
    final String type = data['type'];
    final int medicineId = data['medicineId'];
    
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final bool voiceRemindersEnabled = prefs.getBool('voice_reminders_enabled') ?? false;

    if (type == 'reminder') {
      print('Reminder notification received for medicine ID: $medicineId');
      
      if (voiceRemindersEnabled) {
        final medicineData = await _getMedicineDetails(medicineId);
        if (medicineData != null && medicineData['voice_note'] != null) {
          await _playVoiceNote(medicineData['voice_note']);
        }
      }
      
      // Fetch the userId from SharedPreferences
      final int? userId = prefs.getInt('userId');
      if (userId != null) {
        // Navigate to the home screen when a notification is tapped, passing the userId.
        navigatorKey.currentState?.pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => HomeScreen(userId: userId)),
          (route) => false,
        );
      } else {
        print('User ID not found in SharedPreferences.');
        navigatorKey.currentState?.pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const SplashScreen()),
          (route) => false,
        );
      }
    }
    else if (type == 'missed_dose_check') {
      print('Missed dose check silent notification received for medicine ID: $medicineId');
      // This is a trigger for the background task, the workmanager will handle the logic
    }
  }
}

// Global function to check if a medicine dose has been taken
Future<bool> _checkIfDoseIsMissed(int medicineId) async {
  try {
    final response = await http.get(Uri.parse('${AppConfig.apiUrl}/api/medicines/$medicineId/status'));
    if (response.statusCode == 200) {
      final Map<String, dynamic> data = jsonDecode(response.body);
      return data['status'] == 'missed';
    }
  } catch (e) {
    print('Error checking dose status: $e');
  }
  return false;
}

// Global function to notify the caregiver
Future<void> _notifyCaregiver(int medicineId, String medicineName) async {
  final prefs = await SharedPreferences.getInstance();
  final bool caregiverAlertsEnabled = prefs.getBool('caregiver_alerts_enabled') ?? false;

  if (!caregiverAlertsEnabled) {
    return;
  }

  try {
    final response = await http.post(
      Uri.parse('${AppConfig.apiUrl}/api/notify-caregiver'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'medicineId': medicineId,
        'medicineName': medicineName,
      }),
    );
    if (response.statusCode == 200) {
      print('Caregiver notified for missed dose of $medicineName');
    } else {
      print('Failed to notify caregiver. Status: ${response.statusCode}');
    }
  } catch (e) {
    print('Error notifying caregiver: $e');
  }
}

Future<Map<String, dynamic>?> _getMedicineDetails(int medicineId) async {
  try {
    final response = await http.get(Uri.parse('${AppConfig.apiUrl}/api/medicines/$medicineId'));
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
  } catch (e) {
    print('Error fetching medicine details: $e');
  }
  return null;
}

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    print('Executing background task: $taskName');
    if (taskName == 'missed_dose_check_task') {
      final int medicineId = inputData!['medicineId'];
      final String medicineName = inputData['medicineName'];

      final bool isMissed = await _checkIfDoseIsMissed(medicineId);
      if (isMissed) {
        await _notifyCaregiver(medicineId, medicineName);
      }
    }
    return Future.value(true);
  });
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  tz.initializeTimeZones();

  await flutterTts.setLanguage('en-US');
  
  if (!kIsWeb) {
    Workmanager().initialize(
      callbackDispatcher,
      isInDebugMode: true,
    );
  }

  await flutterLocalNotificationsPlugin.initialize(
    const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    ),
    onDidReceiveNotificationResponse: onDidReceiveNotificationResponse,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'Saathi App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const SplashScreen(),
    );
  }
}

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();