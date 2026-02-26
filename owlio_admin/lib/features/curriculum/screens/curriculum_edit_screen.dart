import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:owlio_shared/owlio_shared.dart';
import 'package:uuid/uuid.dart';

import '../../../core/supabase_client.dart';
import '../../users/screens/user_list_screen.dart';
import 'curriculum_list_screen.dart';

/// Provider for loading all vocabulary units
final allVocabularyUnitsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final supabase = ref.watch(supabaseClientProvider);
  final response = await supabase
      .from(DbTables.vocabularyUnits)
      .select('id, name, sort_order, color, icon, is_active')
      .eq('is_active', true)
      .order('sort_order', ascending: true);
  return List<Map<String, dynamic>>.from(response);
});

/// Provider for loading classes for a specific school
final schoolClassesProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>(
        (ref, schoolId) async {
  final supabase = ref.watch(supabaseClientProvider);
  final response = await supabase
      .from(DbTables.classes)
      .select('id, name, grade, academic_year')
      .eq('school_id', schoolId)
      .order('grade')
      .order('name');
  return List<Map<String, dynamic>>.from(response);
});

/// Provider for loading existing assignments for a scope (school+grade or school+class)
final scopeAssignmentsProvider = FutureProvider.family<
    List<Map<String, dynamic>>, Map<String, dynamic>>((ref, params) async {
  final supabase = ref.watch(supabaseClientProvider);
  final schoolId = params['school_id'] as String;
  final grade = params['grade'] as int?;
  final classId = params['class_id'] as String?;

  var query = supabase
      .from(DbTables.unitCurriculumAssignments)
      .select('id, unit_id')
      .eq('school_id', schoolId);

  if (classId != null) {
    query = query.eq('class_id', classId);
  } else if (grade != null) {
    query = query.eq('grade', grade).isFilter('class_id', null);
  } else {
    query = query.isFilter('grade', null).isFilter('class_id', null);
  }

  final response = await query;
  return List<Map<String, dynamic>>.from(response);
});

enum _ScopeType { school, grade, classSpecific }

class CurriculumEditScreen extends ConsumerStatefulWidget {
  const CurriculumEditScreen({super.key, this.assignmentId});

  final String? assignmentId;

  @override
  ConsumerState<CurriculumEditScreen> createState() =>
      _CurriculumEditScreenState();
}

class _CurriculumEditScreenState extends ConsumerState<CurriculumEditScreen> {
  String? _schoolId;
  _ScopeType _scopeType = _ScopeType.grade;
  int? _selectedGrade;
  String? _selectedClassId;
  Set<String> _selectedUnitIds = {};
  Set<String> _existingAssignmentIds = {}; // To track which to delete

  bool _isLoading = false;
  bool _isSaving = false;
  bool _isLoadingScope = false;

  bool get isNewAssignment => widget.assignmentId == null;

  @override
  void initState() {
    super.initState();
    if (!isNewAssignment) {
      _loadAssignment();
    }
  }

  Future<void> _loadAssignment() async {
    setState(() => _isLoading = true);

    try {
      final supabase = ref.read(supabaseClientProvider);
      final response = await supabase
          .from(DbTables.unitCurriculumAssignments)
          .select('id, unit_id, school_id, grade, class_id')
          .eq('id', widget.assignmentId!)
          .maybeSingle();

      if (response != null && mounted) {
        final schoolId = response['school_id'] as String;
        final grade = response['grade'] as int?;
        final classId = response['class_id'] as String?;

        setState(() {
          _schoolId = schoolId;
          if (classId != null) {
            _scopeType = _ScopeType.classSpecific;
            _selectedClassId = classId;
          } else if (grade != null) {
            _scopeType = _ScopeType.grade;
            _selectedGrade = grade;
          } else {
            _scopeType = _ScopeType.school;
          }
        });

        // Load all assignments for this scope
        await _loadScopeAssignments();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadScopeAssignments() async {
    if (_schoolId == null) return;

    setState(() => _isLoadingScope = true);

    try {
      final params = <String, dynamic>{
        'school_id': _schoolId!,
        'grade': _scopeType == _ScopeType.grade ? _selectedGrade : null,
        'class_id':
            _scopeType == _ScopeType.classSpecific ? _selectedClassId : null,
      };

      final assignments =
          await ref.read(scopeAssignmentsProvider(params).future);

      if (mounted) {
        setState(() {
          _selectedUnitIds =
              assignments.map((a) => a['unit_id'] as String).toSet();
          _existingAssignmentIds =
              assignments.map((a) => a['id'] as String).toSet();
        });
      }
    } catch (e) {
      // Silently fail - user can still create new assignments
    } finally {
      if (mounted) setState(() => _isLoadingScope = false);
    }
  }

  Future<void> _handleSave() async {
    if (_schoolId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a school')),
      );
      return;
    }

    if (_scopeType == _ScopeType.grade && _selectedGrade == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a grade')),
      );
      return;
    }

    if (_scopeType == _ScopeType.classSpecific && _selectedClassId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a class')),
      );
      return;
    }

    if (_selectedUnitIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one unit')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final supabase = ref.read(supabaseClientProvider);
      final userId = supabase.auth.currentUser?.id;

      // Delete existing assignments for this scope
      if (_existingAssignmentIds.isNotEmpty) {
        await supabase
            .from(DbTables.unitCurriculumAssignments)
            .delete()
            .inFilter('id', _existingAssignmentIds.toList());
      }

      // Insert new assignments
      final rows = _selectedUnitIds.map((unitId) {
        final row = <String, dynamic>{
          'id': const Uuid().v4(),
          'unit_id': unitId,
          'school_id': _schoolId,
          'assigned_by': userId,
        };
        if (_scopeType == _ScopeType.grade) {
          row['grade'] = _selectedGrade;
        } else if (_scopeType == _ScopeType.classSpecific) {
          row['class_id'] = _selectedClassId;
        }
        return row;
      }).toList();

      await supabase.from(DbTables.unitCurriculumAssignments).insert(rows);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '${_selectedUnitIds.length} unit(s) assigned successfully'),
          ),
        );
        ref.invalidate(curriculumAssignmentsProvider);
        context.go('/curriculum');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _handleDelete() async {
    if (_existingAssignmentIds.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Assignments'),
        content: Text(
          'Remove all ${_existingAssignmentIds.length} unit assignment(s) for this scope? '
          'Students will see all units again (default behavior).',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete All'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final supabase = ref.read(supabaseClientProvider);
      await supabase
          .from(DbTables.unitCurriculumAssignments)
          .delete()
          .inFilter('id', _existingAssignmentIds.toList());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Assignments deleted')),
        );
        ref.invalidate(curriculumAssignmentsProvider);
        context.go('/curriculum');
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
    final unitsAsync = ref.watch(allVocabularyUnitsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(isNewAssignment ? 'New Assignment' : 'Edit Assignment'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/curriculum'),
        ),
        actions: [
          if (!isNewAssignment && _existingAssignmentIds.isNotEmpty)
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
                : Text(isNewAssignment ? 'Create' : 'Save'),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left side: Scope form
                Expanded(
                  flex: 2,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Assignment Scope',
                            style: Theme.of(context).textTheme.titleLarge),
                        const SizedBox(height: 8),
                        Text(
                          'Select which students should see the assigned units.',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                        const SizedBox(height: 24),

                        // School dropdown
                        schoolsAsync.when(
                          data: (schools) => DropdownButtonFormField<String?>(
                            value: _schoolId,
                            decoration: const InputDecoration(
                              labelText: 'School *',
                            ),
                            items: [
                              const DropdownMenuItem(
                                value: null,
                                child: Text('Select a school'),
                              ),
                              ...schools.map((school) => DropdownMenuItem(
                                    value: school['id'] as String,
                                    child: Text(school['name'] as String),
                                  )),
                            ],
                            onChanged: (value) {
                              setState(() {
                                _schoolId = value;
                                _selectedClassId = null;
                                _selectedUnitIds = {};
                                _existingAssignmentIds = {};
                              });
                            },
                          ),
                          loading: () => const LinearProgressIndicator(),
                          error: (_, __) =>
                              const Text('Error loading schools'),
                        ),
                        const SizedBox(height: 24),

                        // Scope type radio buttons
                        Text('Target',
                            style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 8),
                        _ScopeRadio(
                          value: _ScopeType.school,
                          groupValue: _scopeType,
                          label: 'All School',
                          description: 'All students in the school',
                          onChanged: (v) {
                            setState(() {
                              _scopeType = v!;
                              _selectedGrade = null;
                              _selectedClassId = null;
                              _selectedUnitIds = {};
                              _existingAssignmentIds = {};
                            });
                          },
                        ),
                        _ScopeRadio(
                          value: _ScopeType.grade,
                          groupValue: _scopeType,
                          label: 'By Grade',
                          description: 'All classes of a specific grade',
                          onChanged: (v) {
                            setState(() {
                              _scopeType = v!;
                              _selectedClassId = null;
                              _selectedUnitIds = {};
                              _existingAssignmentIds = {};
                            });
                          },
                        ),
                        _ScopeRadio(
                          value: _ScopeType.classSpecific,
                          groupValue: _scopeType,
                          label: 'By Class',
                          description: 'A specific class/section only',
                          onChanged: (v) {
                            setState(() {
                              _scopeType = v!;
                              _selectedGrade = null;
                              _selectedUnitIds = {};
                              _existingAssignmentIds = {};
                            });
                          },
                        ),
                        const SizedBox(height: 16),

                        // Grade selector (visible when scope is grade)
                        if (_scopeType == _ScopeType.grade)
                          DropdownButtonFormField<int?>(
                            value: _selectedGrade,
                            decoration: const InputDecoration(
                              labelText: 'Grade *',
                            ),
                            items: [
                              const DropdownMenuItem(
                                  value: null,
                                  child: Text('Select grade')),
                              for (int i = 1; i <= 12; i++)
                                DropdownMenuItem(
                                    value: i, child: Text('Grade $i')),
                            ],
                            onChanged: (value) {
                              setState(() {
                                _selectedGrade = value;
                                _selectedUnitIds = {};
                                _existingAssignmentIds = {};
                              });
                              if (value != null) _loadScopeAssignments();
                            },
                          ),

                        // Class selector (visible when scope is class)
                        if (_scopeType == _ScopeType.classSpecific &&
                            _schoolId != null)
                          ref.watch(schoolClassesProvider(_schoolId!)).when(
                                data: (classes) =>
                                    DropdownButtonFormField<String?>(
                                  value: _selectedClassId,
                                  decoration: const InputDecoration(
                                    labelText: 'Class *',
                                  ),
                                  items: [
                                    const DropdownMenuItem(
                                        value: null,
                                        child: Text('Select class')),
                                    ...classes.map((cls) => DropdownMenuItem(
                                          value: cls['id'] as String,
                                          child: Text(
                                            '${cls['name']} (Grade ${cls['grade'] ?? '?'})',
                                          ),
                                        )),
                                  ],
                                  onChanged: (value) {
                                    setState(() {
                                      _selectedClassId = value;
                                      _selectedUnitIds = {};
                                      _existingAssignmentIds = {};
                                    });
                                    if (value != null) _loadScopeAssignments();
                                  },
                                ),
                                loading: () =>
                                    const LinearProgressIndicator(),
                                error: (_, __) =>
                                    const Text('Error loading classes'),
                              ),

                        // Load existing button for school scope
                        if (_scopeType == _ScopeType.school &&
                            _schoolId != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 16),
                            child: OutlinedButton(
                              onPressed: _loadScopeAssignments,
                              child: const Text('Load existing assignments'),
                            ),
                          ),

                        if (_isLoadingScope)
                          const Padding(
                            padding: EdgeInsets.only(top: 16),
                            child: LinearProgressIndicator(),
                          ),

                        if (_existingAssignmentIds.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 16),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.info_outline,
                                      size: 18, color: Colors.blue.shade700),
                                  const SizedBox(width: 8),
                                  Text(
                                    '${_existingAssignmentIds.length} existing assignment(s) for this scope',
                                    style:
                                        TextStyle(color: Colors.blue.shade700),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),

                // Right side: Unit selection
                Expanded(
                  flex: 1,
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border(
                        left: BorderSide(color: Colors.grey.shade200),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Units (${_selectedUnitIds.length} selected)',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              // Select all / deselect all
                              unitsAsync.when(
                                data: (units) => TextButton(
                                  onPressed: () {
                                    setState(() {
                                      if (_selectedUnitIds.length ==
                                          units.length) {
                                        _selectedUnitIds = {};
                                      } else {
                                        _selectedUnitIds = units
                                            .map((u) => u['id'] as String)
                                            .toSet();
                                      }
                                    });
                                  },
                                  child: Text(
                                    _selectedUnitIds.length ==
                                            (unitsAsync.valueOrNull?.length ??
                                                0)
                                        ? 'Deselect All'
                                        : 'Select All',
                                  ),
                                ),
                                loading: () => const SizedBox.shrink(),
                                error: (_, __) => const SizedBox.shrink(),
                              ),
                            ],
                          ),
                        ),
                        const Divider(height: 1),
                        Expanded(
                          child: unitsAsync.when(
                            data: (units) {
                              if (units.isEmpty) {
                                return Center(
                                  child: Column(
                                    mainAxisAlignment:
                                        MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.widgets_outlined,
                                          size: 48,
                                          color: Colors.grey.shade400),
                                      const SizedBox(height: 8),
                                      Text('No vocabulary units found',
                                          style: TextStyle(
                                              color: Colors.grey.shade600)),
                                    ],
                                  ),
                                );
                              }

                              return ListView.builder(
                                itemCount: units.length,
                                itemBuilder: (context, index) {
                                  final unit = units[index];
                                  final unitId = unit['id'] as String;
                                  final isSelected =
                                      _selectedUnitIds.contains(unitId);

                                  return CheckboxListTile(
                                    value: isSelected,
                                    onChanged: (checked) {
                                      setState(() {
                                        if (checked == true) {
                                          _selectedUnitIds.add(unitId);
                                        } else {
                                          _selectedUnitIds.remove(unitId);
                                        }
                                      });
                                    },
                                    secondary: CircleAvatar(
                                      backgroundColor: _parseUnitColor(
                                              unit['color'] as String?)
                                          .withValues(alpha: 0.15),
                                      child: Text(
                                        unit['icon'] as String? ?? '📚',
                                        style: const TextStyle(fontSize: 18),
                                      ),
                                    ),
                                    title: Text(
                                      unit['name'] as String? ?? 'Unit',
                                      style: TextStyle(
                                        fontWeight: isSelected
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                      ),
                                    ),
                                    subtitle: Text(
                                      'Order: ${unit['sort_order']}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade500,
                                      ),
                                    ),
                                  );
                                },
                              );
                            },
                            loading: () => const Center(
                                child: CircularProgressIndicator()),
                            error: (error, _) =>
                                Center(child: Text('Error: $error')),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Color _parseUnitColor(String? hex) {
    if (hex == null || hex.length < 7) return const Color(0xFF58CC02);
    try {
      return Color(int.parse(hex.substring(1), radix: 16) + 0xFF000000);
    } catch (_) {
      return const Color(0xFF58CC02);
    }
  }
}

class _ScopeRadio extends StatelessWidget {
  const _ScopeRadio({
    required this.value,
    required this.groupValue,
    required this.label,
    required this.description,
    required this.onChanged,
  });

  final _ScopeType value;
  final _ScopeType groupValue;
  final String label;
  final String description;
  final ValueChanged<_ScopeType?> onChanged;

  @override
  Widget build(BuildContext context) {
    return RadioListTile<_ScopeType>(
      value: value,
      groupValue: groupValue,
      onChanged: onChanged,
      title: Text(label),
      subtitle: Text(description,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
      contentPadding: EdgeInsets.zero,
      dense: true,
    );
  }
}
