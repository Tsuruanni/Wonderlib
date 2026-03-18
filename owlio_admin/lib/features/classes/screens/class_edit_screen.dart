import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:owlio_shared/owlio_shared.dart';
import 'package:uuid/uuid.dart';

import '../../../core/supabase_client.dart';
import '../../users/screens/user_list_screen.dart';
import 'class_list_screen.dart';

/// Provider for loading a single class with students
final classDetailProvider =
    FutureProvider.family<Map<String, dynamic>?, String>((ref, classId) async {
  final supabase = ref.watch(supabaseClientProvider);
  final response = await supabase
      .from(DbTables.classes)
      .select('*, schools(id, name), profiles(id, first_name, last_name, email)')
      .eq('id', classId)
      .maybeSingle();

  return response;
});

/// Provider for students available to add (same school, no class assigned)
final availableStudentsProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((ref, schoolId) async {
  final supabase = ref.watch(supabaseClientProvider);
  final response = await supabase
      .from(DbTables.profiles)
      .select('id, first_name, last_name, email')
      .eq('school_id', schoolId)
      .eq('role', UserRole.student.dbValue)
      .isFilter('class_id', null)
      .order('first_name');

  return List<Map<String, dynamic>>.from(response);
});

class ClassEditScreen extends ConsumerStatefulWidget {
  const ClassEditScreen({super.key, this.classId});

  final String? classId;

  @override
  ConsumerState<ClassEditScreen> createState() => _ClassEditScreenState();
}

class _ClassEditScreenState extends ConsumerState<ClassEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _gradeController = TextEditingController();
  final _academicYearController = TextEditingController();

  String? _schoolId;
  List<Map<String, dynamic>> _students = [];
  bool _isLoading = false;
  bool _isSaving = false;

  bool get isNewClass => widget.classId == null;

  @override
  void initState() {
    super.initState();
    if (!isNewClass) {
      _loadClass();
    } else {
      // Default academic year
      _academicYearController.text = '${DateTime.now().year}-${DateTime.now().year + 1}';
    }
  }

  Future<void> _loadClass() async {
    setState(() => _isLoading = true);

    final classData = await ref.read(classDetailProvider(widget.classId!).future);
    if (classData != null && mounted) {
      _nameController.text = classData['name'] ?? '';
      _gradeController.text = (classData['grade'] ?? '').toString();
      _academicYearController.text = classData['academic_year'] ?? '';
      setState(() {
        _schoolId = classData['school_id'] as String?;
        _students = List<Map<String, dynamic>>.from(classData['profiles'] ?? []);
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _gradeController.dispose();
    _academicYearController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final supabase = ref.read(supabaseClientProvider);

      final data = {
        'name': _nameController.text.trim(),
        'school_id': _schoolId,
        'grade': int.tryParse(_gradeController.text.trim()),
        'academic_year': _academicYearController.text.trim(),
      };

      if (isNewClass) {
        data['id'] = const Uuid().v4();
        await supabase.from(DbTables.classes).insert(data);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Sınıf başarıyla oluşturuldu')),
          );
          ref.invalidate(classesProvider);
          context.go('/classes/${data['id']}');
        }
      } else {
        await supabase.from(DbTables.classes).update(data).eq('id', widget.classId!);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Sınıf başarıyla kaydedildi')),
          );
          ref.invalidate(classDetailProvider(widget.classId!));
          ref.invalidate(classesProvider);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hata: $e'),
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
        title: const Text('Sınıfı Sil'),
        content: const Text(
          'Bu sınıfı silmek istediğinizden emin misiniz? '
          'Öğrenciler bu sınıftan çıkarılacaktır. '
          'Bu işlem geri alınamaz.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('İptal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Sil'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final supabase = ref.read(supabaseClientProvider);
      await supabase.from(DbTables.classes).delete().eq('id', widget.classId!);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sınıf silindi')),
        );
        ref.invalidate(classesProvider);
        context.go('/classes');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _addStudent() async {
    if (_schoolId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen önce bir okul seçin')),
      );
      return;
    }

    final availableStudents =
        await ref.read(availableStudentsProvider(_schoolId!).future);

    if (!mounted) return;

    if (availableStudents.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Eklenecek uygun öğrenci yok')),
      );
      return;
    }

    final selectedStudent = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Öğrenci Ekle'),
        content: SizedBox(
          width: 400,
          height: 300,
          child: ListView.builder(
            itemCount: availableStudents.length,
            itemBuilder: (context, index) {
              final student = availableStudents[index];
              final name =
                  '${student['first_name'] ?? ''} ${student['last_name'] ?? ''}'.trim();
              return ListTile(
                leading: CircleAvatar(
                  child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?'),
                ),
                title: Text(name.isNotEmpty ? name : student['email'] ?? 'Unknown'),
                subtitle: Text(student['email'] ?? ''),
                onTap: () => Navigator.pop(context, student),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
        ],
      ),
    );

    if (selectedStudent == null) return;

    try {
      final supabase = ref.read(supabaseClientProvider);
      await supabase
          .from(DbTables.profiles)
          .update({'class_id': widget.classId})
          .eq('id', selectedStudent['id']);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Öğrenci sınıfa eklendi')),
        );
        ref.invalidate(classDetailProvider(widget.classId!));
        ref.invalidate(availableStudentsProvider(_schoolId!));
        _loadClass();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _removeStudent(Map<String, dynamic> student) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Öğrenciyi Çıkar'),
        content: Text(
          '${student['first_name']} ${student['last_name']} bu sınıftan çıkarılsın mı?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('İptal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Çıkar'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final supabase = ref.read(supabaseClientProvider);
      await supabase
          .from(DbTables.profiles)
          .update({'class_id': null}).eq('id', student['id']);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Öğrenci sınıftan çıkarıldı')),
        );
        ref.invalidate(classDetailProvider(widget.classId!));
        if (_schoolId != null) {
          ref.invalidate(availableStudentsProvider(_schoolId!));
        }
        _loadClass();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final schoolsAsync = ref.watch(allSchoolsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(isNewClass ? 'Yeni Sınıf' : 'Sınıf Düzenle'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/classes'),
        ),
        actions: [
          if (!isNewClass)
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
                : Text(isNewClass ? 'Oluştur' : 'Kaydet'),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Class form
                Expanded(
                  flex: 2,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Sınıf Bilgileri',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 24),

                          // Name
                          TextFormField(
                            controller: _nameController,
                            decoration: const InputDecoration(
                              labelText: 'Sınıf Adı',
                              hintText: 'ör. 5A, 7B, İleri İngilizce',
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Sınıf adı zorunludur';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          // School dropdown
                          schoolsAsync.when(
                            data: (schools) => DropdownButtonFormField<String?>(
                              value: _schoolId,
                              decoration: const InputDecoration(
                                labelText: 'Okul',
                              ),
                              items: [
                                const DropdownMenuItem(
                                  value: null,
                                  child: Text('Bir okul seçin'),
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
                                if (value == null) {
                                  return 'Okul zorunludur';
                                }
                                return null;
                              },
                            ),
                            loading: () => const LinearProgressIndicator(),
                            error: (_, __) => const Text('Okullar yüklenirken hata oluştu'),
                          ),
                          const SizedBox(height: 16),

                          // Grade
                          TextFormField(
                            controller: _gradeController,
                            decoration: const InputDecoration(
                              labelText: 'Sınıf Seviyesi',
                              hintText: 'ör. 5, 7, 12',
                            ),
                            keyboardType: TextInputType.number,
                          ),
                          const SizedBox(height: 16),

                          // Academic year
                          TextFormField(
                            controller: _academicYearController,
                            decoration: const InputDecoration(
                              labelText: 'Akademik Yıl',
                              hintText: 'ör. 2024-2025',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Students list (only for existing classes)
                if (!isNewClass)
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
                                  'Öğrenciler (${_students.length})',
                                  style: Theme.of(context).textTheme.titleMedium,
                                ),
                                FilledButton.icon(
                                  onPressed: _addStudent,
                                  icon: const Icon(Icons.add, size: 18),
                                  label: const Text('Ekle'),
                                ),
                              ],
                            ),
                          ),
                          const Divider(height: 1),
                          Expanded(
                            child: _students.isEmpty
                                ? Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.people_outline,
                                          size: 48,
                                          color: Colors.grey.shade400,
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          'Henüz öğrenci yok',
                                          style: TextStyle(color: Colors.grey.shade600),
                                        ),
                                      ],
                                    ),
                                  )
                                : ListView.builder(
                                    itemCount: _students.length,
                                    itemBuilder: (context, index) {
                                      final student = _students[index];
                                      final name =
                                          '${student['first_name'] ?? ''} ${student['last_name'] ?? ''}'
                                              .trim();
                                      return ListTile(
                                        leading: CircleAvatar(
                                          backgroundColor:
                                              Colors.green.withValues(alpha: 0.1),
                                          child: Text(
                                            name.isNotEmpty
                                                ? name[0].toUpperCase()
                                                : '?',
                                            style: const TextStyle(
                                              color: Colors.green,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        title: Text(name.isNotEmpty
                                            ? name
                                            : student['email'] ?? 'Unknown'),
                                        subtitle: Text(student['email'] ?? ''),
                                        trailing: IconButton(
                                          icon: const Icon(Icons.remove_circle_outline),
                                          color: Colors.red,
                                          onPressed: () => _removeStudent(student),
                                        ),
                                      );
                                    },
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
}
