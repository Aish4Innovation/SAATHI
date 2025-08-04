import 'package:flutter/material.dart';
import 'package:saathi_app/constants.dart';
import 'package:saathi_app/screens/home_screen.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class CaregiverScreen extends StatefulWidget {
  final int userId;

  const CaregiverScreen({super.key, required this.userId});

  @override
  State<CaregiverScreen> createState() => _CaregiverScreenState();
}

class _CaregiverScreenState extends State<CaregiverScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _relationshipController = TextEditingController();
  bool _isLoading = false;

  Future<void> _getStarted() async {
    final name = _nameController.text;
    final phoneNumber = _phoneController.text;
    final relationship = _relationshipController.text;

    // If no caregiver data is entered, we can skip and go to the home screen
    if (name.isEmpty && phoneNumber.isEmpty) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => HomeScreen(userId: widget.userId),
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await http.post(
        Uri.parse('${AppConfig.apiUrl}/api/caregivers'), // Changed here
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'userId': widget.userId,
          'name': name,
          'phoneNumber': phoneNumber,
          'relationship': relationship,
          'isPrimary': true, // The first caregiver added is the primary one
        }),
      );

      if (response.statusCode == 201) {
        // Caregiver saved successfully, navigate to home screen
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => HomeScreen(userId: widget.userId),
          ),
        );
      } else {
        // Handle errors from the backend
        print('Failed to save caregiver: ${response.body}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save caregiver. Please try again.')),
        );
      }
    } catch (e) {
      print('Error saving caregiver: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('An error occurred. Please check your network.')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _relationshipController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircleAvatar(backgroundColor: Colors.grey, radius: 16, child: Text('1', style: TextStyle(color: Colors.white))),
                  SizedBox(width: 8),
                  SizedBox(width: 40, child: Divider(color: Colors.grey, thickness: 2)),
                  SizedBox(width: 8),
                  CircleAvatar(backgroundColor: Colors.blue, radius: 16, child: Text('2', style: TextStyle(color: Colors.white))),
                ],
              ),
              const SizedBox(height: 32.0),
              
              const Icon(Icons.shield_outlined, size: 64, color: Colors.blue),
              const SizedBox(height: 16.0),
              
              const Text(
                'Add a Caregiver (Optional)',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8.0),
              
              const Text(
                "We'll notify them if you miss medicines repeatedly",
                style: TextStyle(fontSize: 16, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40.0),

              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "Caregiver's Name",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(height: 8.0),
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  hintText: 'Enter name',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.0),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: const Color(0xFFF1F1F1),
                ),
              ),
              const SizedBox(height: 24.0),
              
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "Caregiver's Phone Number",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(height: 8.0),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  hintText: '+91 98765 43210',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.0),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: const Color(0xFFF1F1F1),
                ),
              ),
              const SizedBox(height: 24.0),
              
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "Relationship",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(height: 8.0),
              TextFormField(
                controller: _relationshipController,
                decoration: InputDecoration(
                  hintText: 'e.g., Mother, Son, Friend',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.0),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: const Color(0xFFF1F1F1),
                ),
              ),

              const SizedBox(height: 16.0),

              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.favorite, color: Colors.green[700]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'This feature helps ensure your safety and medicine adherence',
                        style: TextStyle(color: Colors.green[700]),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40.0),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(), // Go back to the setup screen
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: const BorderSide(color: Colors.blue, width: 2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Back'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : ElevatedButton(
                            onPressed: _getStarted,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text('Get Started →', style: TextStyle(color: Colors.white)),
                          ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}