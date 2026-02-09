import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/supabase_client.dart';
import 'user_list_screen.dart';

/// Provider for loading a single user
final userDetailProvider =
    FutureProvider.family<Map<String, dynamic>?, String>((ref, userId) async {
  final supabase = ref.watch(supabaseClientProvider);
  final response = await supabase
      .from('profiles')
      .select('*, schools(id, name)')
      .eq('id', userId)
      .maybeSingle();

  return response;
});

class UserEditScreen extends ConsumerStatefulWidget {
  const UserEditScreen({super.key, required this.userId});

  final String userId;

  @override
  ConsumerState<UserEditScreen> createState() => _UserEditScreenState();
}

class _UserEditScreenState extends ConsumerState<UserEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _studentNumberController = TextEditingController();

  static const _validRoles = ['student', 'teacher', 'head', 'admin'];

  String _role = 'student';
  String? _schoolId;
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    setState(() => _isLoading = true);

    final user = await ref.read(userDetailProvider(widget.userId).future);
    if (user != null && mounted) {
      _firstNameController.text = user['first_name'] ?? '';
      _lastNameController.text = user['last_name'] ?? '';
      _emailController.text = user['email'] ?? '';
      _studentNumberController.text = user['student_number'] ?? '';
      final dbRole = user['role'] as String? ?? 'student';
      setState(() {
        _role = _validRoles.contains(dbRole) ? dbRole : 'student';
        _schoolId = user['school_id'] as String?;
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _studentNumberController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final supabase = ref.read(supabaseClientProvider);

      final data = {
        'first_name': _firstNameController.text.trim(),
        'last_name': _lastNameController.text.trim(),
        'role': _role,
        'school_id': _schoolId,
        'student_number': _studentNumberController.text.trim().isEmpty
            ? null
            : _studentNumberController.text.trim(),
      };

      await supabase.from('profiles').update(data).eq('id', widget.userId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User saved successfully')),
        );
        ref.invalidate(userDetailProvider(widget.userId));
        ref.invalidate(usersProvider);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _handleResetProgress() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Progress'),
        content: const Text(
          'Are you sure you want to reset this user\'s XP and level to 0? '
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Reset'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final supabase = ref.read(supabaseClientProvider);
      await supabase.from('profiles').update({
        'xp': 0,
        'level': 1,
        'current_streak': 0,
      }).eq('id', widget.userId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Progress reset successfully')),
        );
        ref.invalidate(userDetailProvider(widget.userId));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final schoolsAsync = ref.watch(allSchoolsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit User'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/users'),
        ),
        actions: [
          const SizedBox(width: 8),
          FilledButton(
            onPressed: _isSaving ? null : _handleSave,
            child: _isSaving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Save'),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Info banner
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.blue.shade700),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'New users are created via Supabase Dashboard. '
                              'This screen is for editing existing users only.',
                              style: TextStyle(color: Colors.blue.shade700),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    Text(
                      'User Details',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 24),

                    // Email (read-only)
                    TextFormField(
                      controller: _emailController,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        helperText: 'Email cannot be changed',
                      ),
                      readOnly: true,
                      enabled: false,
                    ),
                    const SizedBox(height: 16),

                    // First name
                    TextFormField(
                      controller: _firstNameController,
                      decoration: const InputDecoration(
                        labelText: 'First Name',
                        hintText: 'Enter first name',
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'First name is required';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Last name
                    TextFormField(
                      controller: _lastNameController,
                      decoration: const InputDecoration(
                        labelText: 'Last Name',
                        hintText: 'Enter last name',
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Last name is required';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Role dropdown
                    DropdownButtonFormField<String>(
                      value: _role,
                      decoration: const InputDecoration(
                        labelText: 'Role',
                      ),
                      items: _validRoles.map((role) {
                        return DropdownMenuItem(
                          value: role,
                          child: Row(
                            children: [
                              Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: _getRoleColor(role),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(_getRoleLabel(role)),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _role = value);
                        }
                      },
                    ),
                    const SizedBox(height: 16),

                    // School dropdown
                    schoolsAsync.when(
                      data: (schools) => DropdownButtonFormField<String?>(
                        value: _schoolId,
                        decoration: const InputDecoration(
                          labelText: 'School',
                          helperText: 'Required for students and teachers',
                        ),
                        items: [
                          const DropdownMenuItem(
                            value: null,
                            child: Text('No School'),
                          ),
                          ...schools.map((school) => DropdownMenuItem(
                                value: school['id'] as String,
                                child: Text(school['name'] as String),
                              )),
                        ],
                        onChanged: (value) {
                          setState(() => _schoolId = value);
                        },
                        validator: (value) {
                          if ((_role == 'student' || _role == 'teacher') &&
                              value == null) {
                            return 'School is required for students and teachers';
                          }
                          return null;
                        },
                      ),
                      loading: () => const LinearProgressIndicator(),
                      error: (_, __) => const Text('Error loading schools'),
                    ),
                    const SizedBox(height: 16),

                    // Student number (only for students)
                    if (_role == 'student')
                      TextFormField(
                        controller: _studentNumberController,
                        decoration: const InputDecoration(
                          labelText: 'Student Number',
                          hintText: 'e.g., 2024001',
                        ),
                      ),
                    const SizedBox(height: 32),

                    // Danger zone
                    Text(
                      'Danger Zone',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Colors.red,
                          ),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _handleResetProgress,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Reset XP & Progress'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.orange,
                        side: const BorderSide(color: Colors.orange),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Color _getRoleColor(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
        return Colors.red;
      case 'head':
        return Colors.purple;
      case 'teacher':
        return Colors.blue;
      case 'student':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  String _getRoleLabel(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
        return 'Admin';
      case 'head':
        return 'Head Teacher';
      case 'teacher':
        return 'Teacher';
      case 'student':
        return 'Student';
      default:
        return role;
    }
  }
}
