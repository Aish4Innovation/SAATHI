// ignore_for_file: avoid_print

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:saathi_app/constants.dart';

class Caregiver {
  final int id;
  final String name;
  final String phoneNumber;
  final String relationship;

  Caregiver({required this.id, required this.name, required this.phoneNumber, required this.relationship});

  factory Caregiver.fromJson(Map<String, dynamic> json) {
    return Caregiver(
      id: json['id'] as int,
      name: json['name'] as String? ?? '',
      phoneNumber: json['phone_number'] as String? ?? '',
      relationship: json['relationship'] as String? ?? '',
    );
  }
}

class CaregiversDialog extends StatefulWidget {
  final int userId;
  const CaregiversDialog({super.key, required this.userId});

  @override
  State<CaregiversDialog> createState() => _CaregiversDialogState();
}

class _CaregiversDialogState extends State<CaregiversDialog> {
  List<Caregiver> _caregivers = [];
  bool _isLoading = true;
  bool _showForm = false;
  Caregiver? _editingCaregiver;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _relationshipController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchCaregivers();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _relationshipController.dispose();
    super.dispose();
  }

  Future<void> _fetchCaregivers() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final response = await http.get(Uri.parse('${AppConfig.apiUrl}/api/caregivers/${widget.userId}'));
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          _caregivers = data.map((json) => Caregiver.fromJson(json)).toList();
        });
      } else {
        print('Failed to load caregivers. Status code: ${response.statusCode}');
      }
    } catch (e) {
      print('An error occurred while fetching caregivers: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showAddForm() {
    setState(() {
      _showForm = true;
      _editingCaregiver = null;
      _nameController.clear();
      _phoneController.clear();
      _relationshipController.clear();
    });
  }

  void _showEditForm(Caregiver caregiver) {
    setState(() {
      _showForm = true;
      _editingCaregiver = caregiver;
      _nameController.text = caregiver.name;
      _phoneController.text = caregiver.phoneNumber;
      _relationshipController.text = caregiver.relationship;
    });
  }

  // Corrected _saveCaregiver function in caregivers_dialog.dart
Future<void> _saveCaregiver() async {
  final newCaregiverData = {
    'name': _nameController.text,
    'phoneNumber': _phoneController.text, // Corrected key
    'relationship': _relationshipController.text,
    'userId': widget.userId, // Corrected key
    'isPrimary': false, // Assuming a newly added caregiver is not primary unless specified
  };
  
  final isNew = _editingCaregiver == null;
  final url = isNew
      ? Uri.parse('${AppConfig.apiUrl}/api/caregivers')
      : Uri.parse('${AppConfig.apiUrl}/api/caregivers/${_editingCaregiver!.id}');

  try {
    final http.Response response;
    
    if (isNew) {
      // Use http.post for new caregivers
      response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode(newCaregiverData),
      );
    } else {
      // Use http.put for updating existing caregivers
      response = await http.put(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode(newCaregiverData),
      );
    }
    
    if (response.statusCode == 200 || response.statusCode == 201) {
      print('Caregiver saved successfully.');
      _fetchCaregivers();
      setState(() {
        _showForm = false;
      });
    } else {
      print('Failed to save caregiver. Status code: ${response.statusCode}');
      print('Response body: ${response.body}');
    }
  } catch (e) {
    print('An error occurred while saving caregiver: $e');
  }
}
  Future<void> _deleteCaregiver(int caregiverId) async {
    try {
      final response = await http.delete(Uri.parse('${AppConfig.apiUrl}/api/caregivers/$caregiverId'));
      if (response.statusCode == 200) {
        print('Caregiver deleted successfully.');
        _fetchCaregivers();
      } else {
        print('Failed to delete caregiver. Status code: ${response.statusCode}');
      }
    } catch (e) {
      print('An error occurred while deleting caregiver: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.0),
      ),
      child: Container(
        padding: const EdgeInsets.all(24.0),
        child: _showForm ? _buildCaregiverForm() : _buildCaregiversList(),
      ),
    );
  }

  Widget _buildCaregiversList() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildHeader(),
        const SizedBox(height: 16),
        _buildInfoBox(),
        const SizedBox(height: 16),
        _isLoading
            ? const CircularProgressIndicator()
            : _caregivers.isEmpty
                ? const Text('No caregivers added yet.')
                : Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: _caregivers.length,
                      itemBuilder: (context, index) {
                        final caregiver = _caregivers[index];
                        return _buildCaregiverTile(caregiver);
                      },
                    ),
                  ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: _showAddForm,
          icon: const Icon(Icons.add, color: Colors.white),
          label: const Text('Add New Caregiver', style: TextStyle(color: Colors.white)),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF4CAF50),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
          ),
        ),
        const SizedBox(height: 16),
        OutlinedButton(
          onPressed: () => Navigator.of(context).pop(),
          style: OutlinedButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
          ),
          child: const Text('Close'),
        ),
      ],
    );
  }
  
  Widget _buildCaregiverTile(Caregiver caregiver) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: const CircleAvatar(child: Icon(Icons.person)),
        title: Text(caregiver.name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('${caregiver.relationship} - ${caregiver.phoneNumber}'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.blue),
              onPressed: () => _showEditForm(caregiver),
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () => _deleteCaregiver(caregiver.id),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'Caregivers',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }

  Widget _buildInfoBox() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info, color: Colors.green),
          SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'How Caregiver Alerts Work',
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
                ),
                SizedBox(height: 4),
                Text(
                  'If you miss 3 consecutive medicines, your primary caregiver will receive an alert. This helps ensure your safety and medication adherence.',
                  style: TextStyle(color: Colors.black54),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCaregiverForm() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildHeader(),
        const SizedBox(height: 16),
        Text(
          _editingCaregiver == null ? 'Add New Caregiver' : 'Edit Caregiver',
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _nameController,
          decoration: const InputDecoration(labelText: 'Name', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _phoneController,
          decoration: const InputDecoration(labelText: 'Phone Number', border: OutlineInputBorder()),
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _relationshipController,
          decoration: const InputDecoration(labelText: 'Relationship', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: _saveCaregiver,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: Text(_editingCaregiver == null ? 'Save' : 'Update', style: const TextStyle(color: Colors.white)),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(
                onPressed: () {
                  setState(() {
                    _showForm = false;
                  });
                },
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Cancel'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}