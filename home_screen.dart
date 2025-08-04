// ignore_for_file: avoid_print, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:saathi_app/constants.dart';
import 'package:saathi_app/screens/add_medicine_dialog.dart';
import 'package:saathi_app/screens/reminder_settings_dialog.dart';
import 'package:saathi_app/screens/caregivers_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:saathi_app/main.dart'; 
import 'package:flutter/foundation.dart';

class Medicine {
  final int id;
  final String name;
  final String dosage;
  final String time;
  final String? photoUrl;
  final String? voiceNoteUrl; // New field for the voice note
  bool isTaken;

  Medicine({
    required this.id,
    required this.name,
    required this.dosage,
    required this.time,
    this.photoUrl,
    this.voiceNoteUrl,
    this.isTaken = false,
  });

  factory Medicine.fromJson(Map<String, dynamic> json) {
    String formattedTime = json['time']?.split(':').sublist(0, 2).join(':') ?? '00:00';

    return Medicine(
      id: json['id'],
      name: json['name'],
      dosage: json['dosage'] ?? '',
      time: formattedTime,
      photoUrl: json['photo_url'],
      voiceNoteUrl: json['voice_note_url'], // Map the new field
      isTaken: json['is_taken'] == 1,
    );
  }
}

class HomeScreen extends StatefulWidget {
  final int userId;
  const HomeScreen({super.key, required this.userId});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _userName = 'User';
  bool _isLoading = true;
  List<Medicine> _medicines = [];
  int _takenCount = 0;
  int _upcomingCount = 0;
  int _missedCount = 0;
  int _totalActiveCount = 0;
  bool _voiceRemindersEnabled = false; // State variable for the toggle

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    await _getVoiceRemindersStatus();
    await _fetchUserName();
    await _fetchMedicines();
    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _getVoiceRemindersStatus() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _voiceRemindersEnabled = prefs.getBool('voice_reminders_enabled') ?? false;
    });
  }

  void _toggleVoiceReminders() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _voiceRemindersEnabled = !_voiceRemindersEnabled;
    });
    prefs.setBool('voice_reminders_enabled', _voiceRemindersEnabled);
  }

  Future<void> _fetchUserName() async {
    try {
      final userResponse = await http.get(Uri.parse('${AppConfig.apiUrl}/api/profile/${widget.userId}'));
      if (userResponse.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(userResponse.body);
        setState(() {
          _userName = data['name'] ?? 'User';
        });
      } else {
        if (kDebugMode) print('Failed to load user data. Status code: ${userResponse.statusCode}');
      }
    } catch (e) {
      if (kDebugMode) print('An error occurred during startup: ${e.toString()}');
    }
  }

  Future<void> _fetchMedicines() async {
    try {
      final medicineResponse = await http.get(Uri.parse('${AppConfig.apiUrl}/api/medicines/${widget.userId}'));
      if (medicineResponse.statusCode == 200) {
        final List<dynamic> data = json.decode(medicineResponse.body);
        setState(() {
          _medicines = data.map((json) => Medicine.fromJson(json)).toList();
          _updateSummaryCounts();
        });
      } else {
        if (kDebugMode) print('Failed to load medicines. Status code: ${medicineResponse.statusCode}');
      }
    } catch (e) {
      if (kDebugMode) print('An error occurred during startup: ${e.toString()}');
    }
  }

  void _updateSummaryCounts() {
    _takenCount = 0;
    _upcomingCount = 0;
    _missedCount = 0;
    _totalActiveCount = _medicines.length;

    final now = DateTime.now();

    for (var medicine in _medicines) {
      final timeParts = medicine.time.split(':');
      final medicineTime = DateTime(now.year, now.month, now.day, int.parse(timeParts[0]), int.parse(timeParts[1]));

      if (medicine.isTaken) {
        _takenCount++;
      } else if (medicineTime.isBefore(now)) {
        _missedCount++;
      } else {
        _upcomingCount++;
      }
    }
  }

  Future<void> _markAsTaken(int medicineId, bool isTaken) async {
    try {
      final response = await http.put(
        Uri.parse('${AppConfig.apiUrl}/api/medicines/$medicineId'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'is_taken': isTaken ? 1 : 0}),
      );

      if (response.statusCode == 200) {
        _fetchMedicines();
      } else {
        if (kDebugMode) print('Failed to update medicine status. Status code: ${response.statusCode}');
      }
    } catch (e) {
      if (kDebugMode) print('An error occurred while marking as taken: ${e.toString()}');
    }
  }

  void _showAddMedicineDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AddMedicineDialog(
          userId: widget.userId,
          onMedicineAdded: _fetchMedicines,
        );
      },
    );
  }

  void _showReminderSettingsDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return const ReminderSettingsDialog();
      },
    );
  }
  
  void _showCaregiversDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return CaregiversDialog(userId: widget.userId);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        toolbarHeight: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeaderBox(),
                  const SizedBox(height: 24),
                  
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildActionButton(Icons.add, 'Add Medicine', const Color(0xFF1E88E5), _showAddMedicineDialog),
                        _buildActionButton(Icons.alarm, 'Reminders', const Color(0xFFB3E5FC), _showReminderSettingsDialog),
                        _buildActionButton(Icons.group, 'Caregivers', const Color(0xFF4CAF50), _showCaregiversDialog),
                        _buildActionButton(
                          _voiceRemindersEnabled ? Icons.volume_up : Icons.volume_off,
                          'Enable Voice',
                          _voiceRemindersEnabled ? const Color(0xFFFF9800) : Colors.grey,
                          _toggleVoiceReminders,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  GridView.count(
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      _buildSummaryCard(Icons.check_circle_outline, 'Taken Today', '$_takenCount of $_totalActiveCount medicines', const Color(0xFF4CAF50)),
                      _buildSummaryCard(Icons.access_time, 'Upcoming', '$_upcomingCount medicines today', const Color(0xFF2196F3)),
                      _buildSummaryCard(Icons.warning_amber, 'Missed', '$_missedCount need attention', const Color(0xFF9800)),
                      _buildSummaryCard(Icons.calendar_today_outlined, 'Total Active', '$_totalActiveCount medicines', const Color(0xFF4CAF50)),
                    ],
                  ),
                  const SizedBox(height: 24),

                  const Text(
                    "Today's Medicines",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  if (_medicines.isEmpty)
                    const Text('No medicines added yet.')
                  else
                    ..._medicines.map((medicine) => _buildMedicineCard(medicine)).toList(),
                ],
              ),
            ),
    );
  }
  
  Widget _buildHeaderBox() {
    return Container(
      padding: const EdgeInsets.all(24.0),
      decoration: BoxDecoration(
        color: const Color(0xFFE3F2FD),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Saathi',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0D47A1),
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.phone_android, color: Color(0xFF0D47A1)),
              const Spacer(),
              const Icon(Icons.favorite, color: Color(0xFFE57373)),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Welcome back, $_userName!',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF212121),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Your trusted companion for medicine reminders and wellness tracking',
            style: TextStyle(fontSize: 14, color: Color(0xFF757575)),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Icon(Icons.check_circle_outline, color: Color(0xFF4CAF50)),
              const SizedBox(width: 8),
              const Text(
                'Never miss your medicine again',
                style: TextStyle(fontSize: 14, color: Color(0xFF4CAF50)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(IconData icon, String text, Color color, VoidCallback onPressed) {
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, color: Colors.white),
        label: Text(text, style: const TextStyle(color: Colors.white)),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        ),
      ),
    );
  }

  Widget _buildSummaryCard(IconData icon, String title, String subtitle, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, color: color, size: 36),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(fontSize: 12, color: Colors.black.withOpacity(0.6)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMedicineCard(Medicine medicine) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                medicine.photoUrl != null
                    ? Image.network(
                        '${AppConfig.apiUrl}${medicine.photoUrl}',
                        width: 60,
                        height: 60,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return const Icon(Icons.error, size: 60, color: Colors.red);
                        },
                      )
                    : const Icon(
                        Icons.camera_alt_outlined,
                        size: 60,
                        color: Colors.grey,
                      ),
                const SizedBox(height: 8),
                Text(
                  medicine.time,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        medicine.name,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                      if (medicine.voiceNoteUrl != null)
                        const Icon(Icons.volume_up, color: Colors.deepOrange, size: 20),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(medicine.dosage),
                  const SizedBox(height: 8),
                  if (medicine.isTaken)
                    const Text('✓ Medicine Taken', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold))
                  else
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => _markAsTaken(medicine.id, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4CAF50),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text('Mark as Taken', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}