import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:owlio_shared/owlio_shared.dart';
import 'package:uuid/uuid.dart';

import '../../../core/supabase_client.dart';
import 'school_list_screen.dart';

/// Provider for loading a single school
final schoolDetailProvider =
    FutureProvider.family<Map<String, dynamic>?, String>((ref, schoolId) async {
  final supabase = ref.watch(supabaseClientProvider);
  final response = await supabase
      .from(DbTables.schools)
      .select()
      .eq('id', schoolId)
      .maybeSingle();

  return response;
});

class SchoolEditScreen extends ConsumerStatefulWidget {
  const SchoolEditScreen({super.key, this.schoolId});

  final String? schoolId;

  @override
  ConsumerState<SchoolEditScreen> createState() => _SchoolEditScreenState();
}

class _SchoolEditScreenState extends ConsumerState<SchoolEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _codeController = TextEditingController();
  final _logoUrlController = TextEditingController();

  static const _validStatuses = ['active', 'trial', 'suspended'];

  String _status = 'active';
  bool _isLoading = false;
  bool _isSaving = false;

  bool get isNewSchool => widget.schoolId == null;

  @override
  void initState() {
    super.initState();
    if (!isNewSchool) {
      _loadSchool();
    } else {
      // Generate code for new school
      _generateCode();
    }
  }

  void _generateCode() {
    // Generate a random 6-character code
    final uuid = const Uuid().v4();
    _codeController.text = uuid.substring(0, 6).toUpperCase();
  }

  Future<void> _loadSchool() async {
    setState(() => _isLoading = true);

    final school = await ref.read(schoolDetailProvider(widget.schoolId!).future);
    if (school != null && mounted) {
      _nameController.text = school['name'] ?? '';
      _codeController.text = school['code'] ?? '';
      _logoUrlController.text = school['logo_url'] ?? '';
      final dbStatus = school['status'] as String? ?? 'active';
      setState(() {
        _status = _validStatuses.contains(dbStatus) ? dbStatus : 'active';
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    _logoUrlController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final supabase = ref.read(supabaseClientProvider);

      final data = {
        'name': _nameController.text.trim(),
        'code': _codeController.text.trim().toUpperCase(),
        'logo_url': _logoUrlController.text.trim(),
        'status': _status,
      };

      if (isNewSchool) {
        data['id'] = const Uuid().v4();
        await supabase.from(DbTables.schools).insert(data);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('School created successfully')),
          );
          ref.invalidate(schoolsProvider);
          context.go('/schools/${data['id']}');
        }
      } else {
        await supabase.from(DbTables.schools).update(data).eq('id', widget.schoolId!);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('School saved successfully')),
          );
          ref.invalidate(schoolDetailProvider(widget.schoolId!));
          ref.invalidate(schoolsProvider);
        }
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

  Future<void> _handleDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete School'),
        content: const Text(
          'Are you sure you want to delete this school? '
          'This will also delete all associated classes and remove school assignments from users. '
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final supabase = ref.read(supabaseClientProvider);
      await supabase.from(DbTables.schools).delete().eq('id', widget.schoolId!);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('School deleted')),
        );
        ref.invalidate(schoolsProvider);
        context.go('/schools');
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
    return Scaffold(
      appBar: AppBar(
        title: Text(isNewSchool ? 'New School' : 'Edit School'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/schools'),
        ),
        actions: [
          if (!isNewSchool)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              color: Colors.red,
              onPressed: _handleDelete,
            ),
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
                : Text(isNewSchool ? 'Create' : 'Save'),
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
                    Text(
                      'School Details',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 24),

                    // Name
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'School Name',
                        hintText: 'Enter school name',
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'School name is required';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Code
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _codeController,
                            decoration: const InputDecoration(
                              labelText: 'School Code',
                              hintText: 'Unique join code',
                              helperText: 'Students and teachers use this code to join',
                            ),
                            textCapitalization: TextCapitalization.characters,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'School code is required';
                              }
                              if (value.trim().length < 4) {
                                return 'Code must be at least 4 characters';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: _generateCode,
                          icon: const Icon(Icons.refresh),
                          tooltip: 'Generate new code',
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Logo URL
                    TextFormField(
                      controller: _logoUrlController,
                      decoration: const InputDecoration(
                        labelText: 'Logo URL',
                        hintText: 'https://...',
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Status dropdown
                    DropdownButtonFormField<String>(
                      value: _status,
                      decoration: const InputDecoration(
                        labelText: 'Status',
                      ),
                      items: _validStatuses.map((status) {
                        return DropdownMenuItem(
                          value: status,
                          child: Row(
                            children: [
                              Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: _getStatusColor(status),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(_getStatusLabel(status)),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _status = value);
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'active':
        return Colors.green;
      case 'trial':
        return Colors.orange;
      case 'suspended':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'active':
        return 'Active';
      case 'trial':
        return 'Trial';
      case 'suspended':
        return 'Suspended';
      default:
        return status;
    }
  }
}
