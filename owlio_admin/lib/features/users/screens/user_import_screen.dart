import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:owlio_shared/owlio_shared.dart';

import '../../../core/supabase_client.dart';
import '../../../core/widgets/csv_import_dialog.dart';
import 'user_list_screen.dart';

class UserImportScreen extends ConsumerWidget {
  const UserImportScreen({super.key});

  static const expectedHeaders = [
    'email',
    'first_name',
    'last_name',
    'role',
    'school_code',
    'student_number',
  ];

  static const requiredHeaders = ['email', 'role'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Import Users'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/users'),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.upload_file,
                size: 64,
                color: Colors.grey.shade400,
              ),
              const SizedBox(height: 16),
              Text(
                'Import Users from CSV',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                'Upload a CSV file to bulk import or update user profiles.',
                style: TextStyle(color: Colors.grey.shade600),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () => _showImportDialog(context, ref),
                icon: const Icon(Icons.upload),
                label: const Text('Select CSV File'),
              ),
              const SizedBox(height: 32),

              // Format info
              Container(
                constraints: const BoxConstraints(maxWidth: 600),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue.shade700),
                        const SizedBox(width: 8),
                        Text(
                          'CSV Format',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade900,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Required columns: email, role',
                      style: TextStyle(color: Colors.blue.shade900),
                    ),
                    Text(
                      'Optional columns: first_name, last_name, school_code, student_number',
                      style: TextStyle(color: Colors.blue.shade700),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'email,first_name,last_name,role,school_code,student_number\n'
                        'john@example.com,John,Doe,student,DEMO123,2024001\n'
                        'jane@example.com,Jane,Smith,teacher,DEMO123,',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                          color: Colors.grey.shade800,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Valid roles: ${UserRole.values.map((r) => r.dbValue).join(', ')}',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.blue.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showImportDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => CsvImportDialog(
        title: 'Import Users',
        expectedHeaders: expectedHeaders,
        requiredHeaders: requiredHeaders,
        processRow: (row) => _processRow(row, ref),
        onComplete: () {
          ref.invalidate(usersProvider);
        },
      ),
    );
  }

  Future<String?> _processRow(Map<String, String> row, WidgetRef ref) async {
    final supabase = ref.read(supabaseClientProvider);

    final email = row['email']?.trim();
    final role = row['role']?.trim().toLowerCase();
    final firstName = row['first_name']?.trim();
    final lastName = row['last_name']?.trim();
    final schoolCode = row['school_code']?.trim();
    final studentNumber = row['student_number']?.trim();

    // Validate email
    if (email == null || email.isEmpty) {
      return 'Email is required';
    }
    if (!RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(email)) {
      return 'Invalid email format: $email';
    }

    // Validate role
    if (role == null || role.isEmpty) {
      return 'Role is required';
    }
    if (!UserRole.values.map((r) => r.dbValue).contains(role)) {
      return 'Invalid role: $role (must be ${UserRole.values.map((r) => r.dbValue).join(', ')})';
    }

    // Look up school_id if school_code provided
    String? schoolId;
    if (schoolCode != null && schoolCode.isNotEmpty) {
      final school = await supabase
          .from(DbTables.schools)
          .select('id')
          .eq('code', schoolCode)
          .maybeSingle();

      if (school == null) {
        return 'School not found: $schoolCode';
      }
      schoolId = school['id'] as String;
    }

    // Check if profile exists
    final existing = await supabase
        .from(DbTables.profiles)
        .select('id')
        .eq('email', email)
        .maybeSingle();

    final data = <String, dynamic>{
      'email': email,
      'role': role,
      if (firstName != null && firstName.isNotEmpty) 'first_name': firstName,
      if (lastName != null && lastName.isNotEmpty) 'last_name': lastName,
      if (schoolId != null) 'school_id': schoolId,
      if (studentNumber != null && studentNumber.isNotEmpty)
        'student_number': studentNumber,
    };

    if (existing != null) {
      // Update existing profile
      await supabase.from(DbTables.profiles).update(data).eq('id', existing['id']);
    } else {
      // Cannot create auth user from admin panel
      // Just create the profile record - user will need to register
      return 'User must register first. Profile with email $email not found.';
    }

    return null; // Success
  }
}
