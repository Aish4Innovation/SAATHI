// lib/screens/add_medicine_dialog.dart

// ignore_for_file: avoid_print, use_build_context_synchronously

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:saathi_app/constants.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:saathi_app/main.dart';
import 'dart:convert';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:saathi_app/screens/record_voice_dialog.dart';

class AddMedicineDialog extends StatefulWidget {
  final int userId;
  final Function onMedicineAdded;

  const AddMedicineDialog({super.key, required this.userId, required this.onMedicineAdded});

  @override
  State<AddMedicineDialog> createState() => _AddMedicineDialogState();
}

class _AddMedicineDialogState extends State<AddMedicineDialog> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _dosageController = TextEditingController();
  final TextEditingController _instructionsController = TextEditingController();

  TimeOfDay? _selectedTime;
  DateTime? _startDate;
  DateTime? _endDate;
  XFile? _selectedImage;
  String? _recordedVoiceNote; 

  final FlutterTts flutterTts = FlutterTts();

  @override
  void initState() {
    super.initState();
    _initTts();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _dosageController.dispose();
    _instructionsController.dispose();
    super.dispose();
  }

  void _initTts() {
    flutterTts.setLanguage('en-US');
  }

  Future<void> _speak(String text) async {
    await flutterTts.speak(text);
  }

  Future<void> _pickImage() async {
    final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery);
    setState(() {
      _selectedImage = pickedFile;
    });
  }

  void _recordVoiceNote() async {
    final returnedValue = await showDialog<String?>(
      context: context,
      builder: (BuildContext context) {
        return const RecordVoiceDialog();
      },
    );

    if (returnedValue != null) {
      setState(() {
        _recordedVoiceNote = returnedValue;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Voice note recorded successfully!')),
      );
    }
  }

  Future<void> _addMedicine() async {
    if (_formKey.currentState!.validate() && _selectedTime != null && _startDate != null) {
      final String timeString = '${_selectedTime!.hour.toString().padLeft(2, '0')}:${_selectedTime!.minute.toString().padLeft(2, '0')}:00';
      final String startDateString = _startDate!.toIso8601String().split('T')[0];
      final String? endDateString = _endDate?.toIso8601String().split('T')[0];

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('${AppConfig.apiUrl}/api/medicines'),
      );
      
      request.fields['userId'] = widget.userId.toString();
      request.fields['name'] = _nameController.text;
      request.fields['dosage'] = _dosageController.text;
      request.fields['time'] = timeString;
      request.fields['start_date'] = startDateString;
      if (endDateString != null) {
        request.fields['end_date'] = endDateString;
      }
      request.fields['instructions'] = _instructionsController.text;

      if (_selectedImage != null) {
        if (kIsWeb) {
          final bytes = await _selectedImage!.readAsBytes();
          request.files.add(http.MultipartFile.fromBytes(
            'photo',
            bytes,
            filename: _selectedImage!.name,
          ));
        } else {
          request.files.add(await http.MultipartFile.fromPath(
            'photo',
            _selectedImage!.path,
            filename: _selectedImage!.name,
          ));
        }
      }
      
      final voiceNotePathOrUrl = _recordedVoiceNote;
      print('Voice note value before upload: $voiceNotePathOrUrl');

      if (voiceNotePathOrUrl != null) {
        if (kIsWeb) {
          try {
            final http.Response audioResponse = await http.get(Uri.parse(voiceNotePathOrUrl));
            if (audioResponse.statusCode == 200) {
              request.files.add(http.MultipartFile.fromBytes(
                'voice_note',
                audioResponse.bodyBytes,
                filename: 'voice_note.m4a',
              ));
            } else {
              print('Failed to fetch audio from URL: ${audioResponse.statusCode}');
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Failed to upload voice note. URL not found.')),
              );
            }
          } on http.ClientException catch (e) {
            print('HTTP Client Exception fetching audio: $e');
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Failed to connect to the audio URL.')),
            );
          } catch (e) {
            print('An unexpected error occurred while fetching web audio: $e');
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('An unexpected error occurred with the voice note.')),
            );
          }
        } else {
          final file = File(voiceNotePathOrUrl);
          if (await file.exists()) {
            request.files.add(await http.MultipartFile.fromPath(
              'voice_note',
              voiceNotePathOrUrl,
              filename: 'voice_note.m4a',
            ));
          } else {
            print('Voice note file not found at path: $voiceNotePathOrUrl');
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Voice note file not found. Skipping upload.')),
            );
          }
        }
      }

      try {
        final response = await request.send();
        final responseBody = await response.stream.bytesToString();

        if (response.statusCode == 201) {
          final Map<String, dynamic> responseData = jsonDecode(responseBody);
          final int medicineId = responseData['medicineId'];

          await _scheduleNotificationWithSettings(medicineId);

          widget.onMedicineAdded();
          Navigator.of(context).pop();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to add medicine. Status: ${response.statusCode}, Body: $responseBody')),
          );
        }
      } catch (e) {
        print('An error occurred while adding medicine: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('An error occurred. Check your network and server.')),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill out all required fields (marked with *)')),
      );
    }
  }
  
  Future<void> _notifyCaregiver(int medicineId) async {
    final prefs = await SharedPreferences.getInstance();
    final bool caregiverAlertsEnabled = prefs.getBool('caregiver_alerts_enabled') ?? false;

    if (!caregiverAlertsEnabled) {
      print('Caregiver alerts are disabled.');
      return;
    }

    try {
      final response = await http.post(
        Uri.parse('${AppConfig.apiUrl}/api/notify-caregiver'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userId': widget.userId,
          'medicineId': medicineId,
          'medicineName': _nameController.text,
        }),
      );

      if (response.statusCode == 200) {
        print('Caregiver notification sent successfully.');
      } else {
        print('Failed to send caregiver notification. Status code: ${response.statusCode}');
      }
    } catch (e) {
      print('An error occurred while notifying caregiver: $e');
    }
  }

  Future<void> _scheduleNotificationWithSettings(int medicineId) async {
    final prefs = await SharedPreferences.getInstance();
    final bool notificationsEnabled = prefs.getBool('basic_notifications_enabled') ?? true;
    final bool caregiverAlertsEnabled = prefs.getBool('caregiver_alerts_enabled') ?? false;
    final bool voiceRemindersEnabled = prefs.getBool('voice_reminders_enabled') ?? false;
    final bool persistentAlertsEnabled = prefs.getBool('persistent_alerts_enabled') ?? true;
    final String remindMeBefore = prefs.getString('remind_me_before') ?? '0 minutes before';

    if (!notificationsEnabled) {
      print('Push notifications are disabled. Not scheduling.');
      return;
    }

    final int minutesBefore = int.tryParse(remindMeBefore.split(' ')[0]) ?? 0;

    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledTime = tz.TZDateTime(
      tz.local,
      _startDate!.year,
      _startDate!.month,
      _startDate!.day,
      _selectedTime!.hour,
      _selectedTime!.minute,
    );

    scheduledTime = scheduledTime.subtract(Duration(minutes: minutesBefore));

    var nextScheduleTime = scheduledTime;
    if (nextScheduleTime.isBefore(now)) {
      nextScheduleTime = nextScheduleTime.add(const Duration(days: 1));
    }

    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'saathi_channel_id',
      'Medicine Reminders',
      channelDescription: 'Notifications for your daily medicine schedule',
      importance: Importance.high,
      priority: Priority.high,
      ongoing: persistentAlertsEnabled,
    );
    final NotificationDetails platformChannelDetails = NotificationDetails(android: androidDetails);

    await flutterLocalNotificationsPlugin.zonedSchedule(
      medicineId,
      'Medicine Reminder',
      'It\'s time to take your ${_nameController.text}!',
      nextScheduleTime,
      platformChannelDetails,
      payload: jsonEncode({'medicineId': medicineId, 'type': 'reminder'}),
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
    print('Main reminder scheduled for medicine ID: $medicineId');

    if (voiceRemindersEnabled) {
      print('Voice reminder enabled. Will be handled in main.dart.');
    }

    if (caregiverAlertsEnabled) {
      final tz.TZDateTime missedDoseTime = nextScheduleTime.add(const Duration(minutes: 30));
      await flutterLocalNotificationsPlugin.zonedSchedule(
        medicineId + 1000, 
        'Missed Dose Check',
        'Silent notification for caregiver alert',
        missedDoseTime,
        const NotificationDetails(android: AndroidNotificationDetails(
          'saathi_silent_channel',
          'Silent Alerts',
          channelDescription: 'Silent notifications for background tasks',
          importance: Importance.low,
          priority: Priority.low,
          playSound: false,
          enableVibration: false,
        )),
        payload: jsonEncode({'medicineId': medicineId, 'type': 'missed_dose_check'}),
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );
      print('Missed dose check scheduled for medicine ID: $medicineId');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add New Medicine'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Medicine Name *'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a medicine name';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _dosageController,
                decoration: const InputDecoration(labelText: 'Dosage *'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter the dosage';
                  }
                  return null;
                },
              ),
              ListTile(
                title: Text(_selectedTime == null ? 'Select time slot *' : 'Selected time: ${_selectedTime!.format(context)}'),
                trailing: const Icon(Icons.access_time),
                onTap: () async {
                  final TimeOfDay? picked = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay.now(),
                  );
                  if (picked != null && picked != _selectedTime) {
                    setState(() {
                      _selectedTime = picked;
                    });
                  }
                },
              ),
              ListTile(
                title: Text(_startDate == null ? 'Start Date *' : 'Start Date: ${_startDate!.toLocal().toString().split(' ')[0]}'),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final DateTime? picked = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2101),
                  );
                  if (picked != null && picked != _startDate) {
                    setState(() {
                      _startDate = picked;
                    });
                  }
                },
              ),
              ListTile(
                title: Text(_endDate == null ? 'End Date (Optional)' : 'End Date: ${_endDate!.toLocal().toString().split(' ')[0]}'),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final DateTime? picked = await showDatePicker(
                    context: context,
                    initialDate: _startDate ?? DateTime.now(),
                    firstDate: _startDate ?? DateTime(2000),
                    lastDate: DateTime(2101),
                  );
                  if (picked != null && picked != _endDate) {
                    setState(() {
                      _endDate = picked;
                    });
                  }
                },
              ),
              const SizedBox(height: 16),
              if (_selectedImage != null)
                kIsWeb
                    ? Image.network(_selectedImage!.path, height: 100)
                    : Image.file(File(_selectedImage!.path), height: 100),
              ElevatedButton.icon(
                onPressed: _pickImage,
                icon: const Icon(Icons.upload),
                label: const Text('Upload Medicine Photo'),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _recordVoiceNote,
                icon: Icon(_recordedVoiceNote != null ? Icons.mic_external_on : Icons.mic),
                label: Text(_recordedVoiceNote != null ? 'Voice Note Recorded' : 'Record Voice Note'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _recordedVoiceNote != null ? Colors.green : Colors.grey[300],
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _instructionsController,
                decoration: const InputDecoration(labelText: 'Special Instructions (Optional)'),
              ),
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          child: const Text('Cancel'),
          onPressed: () => Navigator.of(context).pop(),
        ),
        ElevatedButton(
          onPressed: _addMedicine,
          child: const Text('Save Medicine'),
        ),
      ],
    );
  }
}