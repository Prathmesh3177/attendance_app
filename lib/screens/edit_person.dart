import 'package:flutter/material.dart';
import '../db/database_helper.dart';
import '../models/person.dart';

class EditPersonScreen extends StatefulWidget {
  final Person person;
  const EditPersonScreen({super.key, required this.person});

  @override
  State<EditPersonScreen> createState() => _EditPersonScreenState();
}

class _EditPersonScreenState extends State<EditPersonScreen> {
  final _formKey = GlobalKey<FormState>();
  late String name;
  late int empCode;
  late String role;

  @override
  void initState() {
    super.initState();
    name = widget.person.name;
    empCode = widget.person.empCode;
    role = widget.person.role;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Edit ${widget.person.role}'),
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
                      TextFormField(
                        decoration: const InputDecoration(
                          labelText: 'Name',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.person),
                        ),
                        initialValue: name,
                        validator: (v) => v == null || v.trim().isEmpty ? 'Enter name' : null,
                        onSaved: (v) => name = v!.trim(),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        decoration: const InputDecoration(
                          labelText: 'Employee/Student Code',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.badge),
                        ),
                        initialValue: empCode.toString(),
                        keyboardType: TextInputType.number,
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Enter code';
                          final code = int.tryParse(v);
                          if (code == null || code <= 0) return 'Enter valid code';
                          return null;
                        },
                        onSaved: (v) => empCode = int.parse(v!),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        decoration: const InputDecoration(
                          labelText: 'Role',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.work),
                        ),
                        value: role,
                        items: const [
                          DropdownMenuItem(value: 'Staff', child: Text('Staff')),
                          DropdownMenuItem(value: 'Student', child: Text('Student')),
                        ],
                        onChanged: (value) => setState(() => role = value!),
                        validator: (v) => v == null ? 'Select role' : null,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () async {
                  if (_formKey.currentState!.validate()) {
                    _formKey.currentState!.save();
                    
                    // Show loading dialog
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (context) => const Center(child: CircularProgressIndicator()),
                    );
                    
                    try {
                      // Update person in database
                      final updatedPerson = Person(
                        id: widget.person.id,
                        name: name,
                        empCode: empCode,
                        role: role,
                      );
                      
                      // Use update to preserve existing relations
                      await DatabaseHelper.updatePerson(updatedPerson);
                      
                      Navigator.pop(context); // Close loading dialog
                      Navigator.pop(context, true); // Return to previous screen
                      
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('User updated successfully!'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    } catch (e) {
                      Navigator.pop(context); // Close loading dialog
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error updating user: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                },
                icon: const Icon(Icons.save),
                label: const Text('Update'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
              const SizedBox(height: 12),
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
