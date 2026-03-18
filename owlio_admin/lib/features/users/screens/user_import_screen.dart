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
        title: const Text('Kullanıcıları İçe Aktar'),
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
                'CSV\'den Kullanıcı İçe Aktar',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                'Kullanıcı profillerini toplu olarak içe aktarmak veya güncellemek için CSV dosyası yükleyin.',
                style: TextStyle(color: Colors.grey.shade600),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () => _showImportDialog(context, ref),
                icon: const Icon(Icons.upload),
                label: const Text('CSV Dosyası Seç'),
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
                          'CSV Formatı',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade900,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Zorunlu sütunlar: email, role',
                      style: TextStyle(color: Colors.blue.shade900),
                    ),
                    Text(
                      'Opsiyonel sütunlar: first_name, last_name, school_code, student_number',
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
                      'Geçerli roller: ${UserRole.values.map((r) => r.dbValue).join(', ')}',
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
        title: 'Kullanıcıları İçe Aktar',
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
      return 'E-posta zorunludur';
    }
    if (!RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(email)) {
      return 'Geçersiz e-posta formatı: $email';
    }

    // Validate role
    if (role == null || role.isEmpty) {
      return 'Rol zorunludur';
    }
    if (!UserRole.values.map((r) => r.dbValue).contains(role)) {
      return 'Geçersiz rol: $role (${UserRole.values.map((r) => r.dbValue).join(', ')} olmalıdır)';
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
        return 'Okul bulunamadı: $schoolCode';
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
      return 'Kullanıcı önce kayıt olmalıdır. $email e-postasıyla profil bulunamadı.';
    }

    return null; // Success
  }
}
