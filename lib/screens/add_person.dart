import 'package:flutter/material.dart';
import '../db/database_helper.dart';
import '../models/person.dart';

class AddPersonScreen extends StatefulWidget {
  final String role; // 'Staff' or 'Student'
  const AddPersonScreen({super.key, required this.role});

  @override
  State<AddPersonScreen> createState() => _AddPersonScreenState();
}

class _AddPersonScreenState extends State<AddPersonScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _empCodeController = TextEditingController();
  String? _selectedClass; // For Students only

  @override
  void dispose() {
    _nameController.dispose();
    _empCodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Add ${widget.role}'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // Name Field
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Full Name',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.person),
                          hintText: 'Enter full name',
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Please enter a name';
                          }
                          if (v.trim().length < 2) {
                            return 'Name must be at least 2 characters';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Code Field
                      TextFormField(
                        controller: _empCodeController,
                        decoration: const InputDecoration(
                          labelText: 'Employee/Student Code (Optional)',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.badge),
                          hintText: 'Leave empty for auto-assignment',
                        ),
                        keyboardType: TextInputType.number,
                        validator: (v) {
                          if (v != null && v.isNotEmpty) {
                            final code = int.tryParse(v);
                            if (code == null || code <= 0) {
                              return 'Enter a valid code number';
                            }
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Dropdown for Student Class
                      if (widget.role == 'Student') ...[
                        DropdownButtonFormField<String>(
                          value: _selectedClass,
                          decoration: const InputDecoration(
                            labelText: 'Select Class',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.school),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: '8th',
                              child: Text('8th Class'),
                            ),
                            DropdownMenuItem(
                              value: '9th',
                              child: Text('9th Class'),
                            ),
                            DropdownMenuItem(
                              value: '10th',
                              child: Text('10th Class'),
                            ),
                          ],
                          onChanged: (value) {
                            setState(() {
                              _selectedClass = value;
                            });
                          },
                          validator: (value) {
                            if (widget.role == 'Student' &&
                                (value == null || value.isEmpty)) {
                              return 'Please select a class';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Info Box
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info, color: Colors.blue.shade700),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Role: ${widget.role}',
                                style: TextStyle(
                                  color: Colors.blue.shade700,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Save Button
              ElevatedButton.icon(
                onPressed: () async {
                  if (_formKey.currentState!.validate()) {
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (context) =>
                          const Center(child: CircularProgressIndicator()),
                    );

                    try {
                      final name = _nameController.text.trim();
                      final empCode = _empCodeController.text.isNotEmpty
                          ? int.parse(_empCodeController.text)
                          : 0;

                      final p = Person(
                        name: name,
                        empCode: empCode,
                        role: widget.role,
                        studentClass:
                            widget.role == 'Student' ? _selectedClass : null,
                      );

                      await DatabaseHelper.insertPerson(p);

                      Navigator.pop(context); // Close loading
                      if (!context.mounted) return;
                      Navigator.pop(context, true); // Go back

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content:
                              Text('${widget.role} added successfully!'),
                          backgroundColor: Colors.green,
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    } catch (e) {
                      Navigator.pop(context); // Close loading
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content:
                              Text('Error adding ${widget.role}: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                },
                icon: const Icon(Icons.save),
                label: const Text('Save'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
              const SizedBox(height: 12),

              // Cancel Button
              OutlinedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.cancel),
                label: const Text('Cancel'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
