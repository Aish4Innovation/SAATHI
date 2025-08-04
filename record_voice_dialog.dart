// ignore_for_file: use_build_context_synchronously, avoid_print

import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';

class RecordVoiceDialog extends StatefulWidget {
  const RecordVoiceDialog({super.key});

  @override
  State<RecordVoiceDialog> createState() => _RecordVoiceDialogState();
}

class _RecordVoiceDialogState extends State<RecordVoiceDialog> {
  final AudioRecorder _audioRecorder = AudioRecorder();
  bool _isRecording = false;
  String? _recordedFilePath;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    final status = await Permission.microphone.request();
    if (status.isGranted) {
      // Permission granted, do nothing
    } else {
      // Permission denied
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Microphone permission is required to record voice notes.')),
        );
      }
    }
  }

  Future<void> _startRecording() async {
    if (await _audioRecorder.hasPermission()) {
      final directory = await getApplicationDocumentsDirectory();
      final filePath = '${directory.path}/voice_note_${DateTime.now().millisecondsSinceEpoch}.m4a';

      // Create a RecordConfig object to configure the recording
      const RecordConfig config = RecordConfig(
        encoder: AudioEncoder.aacLc,
        sampleRate: 44100,
      );

      await _audioRecorder.start(
        config,
        path: filePath,
      );

      if (mounted) {
        setState(() {
          _isRecording = true;
          _recordedFilePath = filePath;
        });
      }
    }
  }

  Future<void> _stopRecording() async {
    final path = await _audioRecorder.stop();
    if (mounted) {
      setState(() {
        _isRecording = false;
        _recordedFilePath = path;
      });
    }
  }

  @override
  void dispose() {
    _audioRecorder.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Record Voice Note'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _isRecording ? Icons.mic : Icons.mic_none,
            color: _isRecording ? Colors.red : Colors.grey,
            size: 48,
          ),
          const SizedBox(height: 16),
          Text(
            _isRecording ? 'Recording...' : 'Tap to start recording.',
            style: const TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _isRecording ? _stopRecording : _startRecording,
            style: ElevatedButton.styleFrom(
              backgroundColor: _isRecording ? Colors.red : Colors.green,
            ),
            child: Text(_isRecording ? 'Stop Recording' : 'Start Recording'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            // Delete the temporary file if recording was started
            if (_recordedFilePath != null && File(_recordedFilePath!).existsSync()) {
              File(_recordedFilePath!).delete();
            }
            Navigator.of(context).pop(); // Return null
          },
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: _isRecording || _recordedFilePath == null
              ? null // Disable if still recording or nothing was recorded
              : () {
                  // Explicitly tell the compiler that _recordedFilePath is not null
                  // at this point.
                  Navigator.of(context).pop(_recordedFilePath!);
                },
          child: const Text('Save'),
        ),
      ],
    );
  }
}