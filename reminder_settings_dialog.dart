// lib/screens/reminder_settings_dialog.dart

// ignore_for_file: library_private_types_in_public_api, avoid_print

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ReminderSettingsDialog extends StatefulWidget {
  const ReminderSettingsDialog({super.key});

  @override
  _ReminderSettingsDialogState createState() => _ReminderSettingsDialogState();
}

class _ReminderSettingsDialogState extends State<ReminderSettingsDialog> {
  // State variables for the settings
  bool _basicNotificationsEnabled = true;
  bool _voiceRemindersEnabled = false;
  String _remindMeBefore = '15 minutes before';
  String _snoozeDuration = '5 minutes';
  bool _persistentAlertsEnabled = true;
  bool _caregiverAlertsEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _basicNotificationsEnabled = prefs.getBool('basic_notifications_enabled') ?? true;
      _voiceRemindersEnabled = prefs.getBool('voice_reminders_enabled') ?? false;
      _remindMeBefore = prefs.getString('remind_me_before') ?? '15 minutes before';
      _snoozeDuration = prefs.getString('snooze_duration') ?? '5 minutes';
      _persistentAlertsEnabled = prefs.getBool('persistent_alerts_enabled') ?? true;
      _caregiverAlertsEnabled = prefs.getBool('caregiver_alerts_enabled') ?? true;
    });
  }

  Future<void> _saveSetting(String key, dynamic value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value is bool) {
      await prefs.setBool(key, value);
    } else if (value is String) {
      await prefs.setString(key, value);
    }
    print('Saved setting: $key = $value');
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Reminder Settings'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // --- Basic Notifications ---
            const Text(
              'Basic Notifications',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SwitchListTile(
              title: const Text('Push Notifications'),
              subtitle: const Text("Get notified when it's medicine time"),
              value: _basicNotificationsEnabled,
              onChanged: (bool value) {
                setState(() {
                  _basicNotificationsEnabled = value;
                });
                _saveSetting('basic_notifications_enabled', value);
              },
            ),
            SwitchListTile(
              title: const Text('Voice Reminders'),
              subtitle: const Text("Hear spoken reminders in your language"),
              value: _voiceRemindersEnabled,
              onChanged: (bool value) {
                setState(() {
                  _voiceRemindersEnabled = value;
                });
                _saveSetting('voice_reminders_enabled', value);
              },
            ),

            // --- Timing Settings ---
            const Divider(),
            const Text(
              'Timing Settings',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            ListTile(
              title: const Text('Remind me before'),
              trailing: DropdownButton<String>(
                value: _remindMeBefore,
                onChanged: (String? newValue) {
                  setState(() {
                    _remindMeBefore = newValue!;
                  });
                  _saveSetting('remind_me_before', newValue);
                },
                items: <String>[
                  '0 minutes before',
                  '5 minutes before',
                  '10 minutes before',
                  '15 minutes before',
                ].map<DropdownMenuItem<String>>((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
              ),
            ),
            ListTile(
              title: const Text('Snooze duration'),
              trailing: DropdownButton<String>(
                value: _snoozeDuration,
                onChanged: (String? newValue) {
                  setState(() {
                    _snoozeDuration = newValue!;
                  });
                  _saveSetting('snooze_duration', newValue);
                },
                items: <String>[
                  '5 minutes',
                  '10 minutes',
                  '15 minutes',
                  '30 minutes',
                ].map<DropdownMenuItem<String>>((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
              ),
            ),

            // --- Advanced Settings ---
            const Divider(),
            const Text(
              'Advanced Settings',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SwitchListTile(
              title: const Text('Persistent Alerts'),
              subtitle: const Text("Keep alerting until medicine is marked as taken"),
              value: _persistentAlertsEnabled,
              onChanged: (bool value) {
                setState(() {
                  _persistentAlertsEnabled = value;
                });
                _saveSetting('persistent_alerts_enabled', value);
              },
            ),
            SwitchListTile(
              title: const Text('Caregiver Alerts'),
              subtitle: const Text("Notify caregiver if multiple doses are missed"),
              value: _caregiverAlertsEnabled,
              onChanged: (bool value) {
                setState(() {
                  _caregiverAlertsEnabled = value;
                });
                _saveSetting('caregiver_alerts_enabled', value);
              },
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text('Save Settings'),
        ),
      ],
    );
  }
}