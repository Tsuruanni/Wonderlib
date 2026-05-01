import 'package:flutter/material.dart';
import '../../../core/widgets/edit_screen_shortcuts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:owlio_shared/owlio_shared.dart';
import 'package:uuid/uuid.dart';

import '../../../core/supabase_client.dart';
import 'school_list_screen.dart';

// ============================================
// PROVIDERS
// ============================================

/// Provider for loading a single school
final schoolDetailProvider =
    FutureProvider.family<Map<String, dynamic>?, String>((ref, schoolId) async {
  final supabase = ref.watch(supabaseClientProvider);
  return await supabase
      .from(DbTables.schools)
      .select()
      .eq('id', schoolId)
      .maybeSingle();
});

/// Classes for a specific school, with student counts
final schoolClassesProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>(
        (ref, schoolId) async {
  final supabase = ref.watch(supabaseClientProvider);
  final response = await supabase
      .from(DbTables.classes)
      .select('*, profiles(id, first_name, last_name, email)')
      .eq('school_id', schoolId)
      .order('grade')
      .order('name');
  return List<Map<String, dynamic>>.from(response);
});

/// Students available to add to a class (same school, no class assigned)
final _availableStudentsProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>(
        (ref, schoolId) async {
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

// ============================================
// SCREEN
// ============================================

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
      _generateCode();
    }
  }

  void _generateCode() {
    final uuid = const Uuid().v4();
    _codeController.text = uuid.substring(0, 6).toUpperCase();
  }

  Future<void> _loadSchool() async {
    setState(() => _isLoading = true);

    final school =
        await ref.read(schoolDetailProvider(widget.schoolId!).future);
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

  // ============================================
  // SCHOOL CRUD
  // ============================================

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
            const SnackBar(content: Text('Okul başarıyla oluşturuldu')),
          );
          ref.invalidate(schoolsProvider);
          context.go('/schools/${data['id']}');
        }
      } else {
        await supabase
            .from(DbTables.schools)
            .update(data)
            .eq('id', widget.schoolId!);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Okul başarıyla kaydedildi')),
          );
          ref.invalidate(schoolDetailProvider(widget.schoolId!));
          ref.invalidate(schoolsProvider);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _handleDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Okulu Sil'),
        content: const Text(
          'Bu okulu silmek istediğinizden emin misiniz? '
          'Bu işlem tüm ilişkili sınıfları da silecek ve kullanıcılardan okul atamalarını kaldıracaktır. '
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
      await supabase
          .from(DbTables.schools)
          .delete()
          .eq('id', widget.schoolId!);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Okul silindi')),
        );
        ref.invalidate(schoolsProvider);
        context.go('/schools');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // ============================================
  // CLASS CRUD
  // ============================================

  Future<void> _showAddClassDialog() async {
    final nameCtrl = TextEditingController();
    final gradeCtrl = TextEditingController();
    final yearCtrl = TextEditingController(
      text: '${DateTime.now().year}-${DateTime.now().year + 1}',
    );

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Yeni Sınıf Ekle'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Sınıf Adı *',
                  hintText: 'ör. 5A, 7B, İleri İngilizce',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              StatefulBuilder(
                builder: (ctx, setLocal) {
                  final current = int.tryParse(gradeCtrl.text.trim());
                  return DropdownButtonFormField<int?>(
                    value: current,
                    decoration: const InputDecoration(
                      labelText: 'Sınıf Seviyesi',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem<int?>(
                        value: null,
                        child: Text('Belirtilmedi'),
                      ),
                      for (var i = 1; i <= 12; i++)
                        DropdownMenuItem<int?>(
                          value: i,
                          child: Text('$i. Sınıf'),
                        ),
                    ],
                    onChanged: (v) {
                      gradeCtrl.text = v == null ? '' : v.toString();
                      setLocal(() {});
                    },
                  );
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: yearCtrl,
                decoration: const InputDecoration(
                  labelText: 'Akademik Yıl',
                  hintText: 'ör. 2025-2026',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('İptal'),
          ),
          FilledButton(
            onPressed: () {
              if (nameCtrl.text.trim().isEmpty) return;
              Navigator.pop(ctx, true);
            },
            child: const Text('Ekle'),
          ),
        ],
      ),
    );

    if (result != true || !mounted) {
      nameCtrl.dispose();
      gradeCtrl.dispose();
      yearCtrl.dispose();
      return;
    }

    try {
      final supabase = ref.read(supabaseClientProvider);
      await supabase.from(DbTables.classes).insert({
        'id': const Uuid().v4(),
        'name': nameCtrl.text.trim(),
        'school_id': widget.schoolId,
        'grade': int.tryParse(gradeCtrl.text.trim()),
        'academic_year': yearCtrl.text.trim(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sınıf oluşturuldu')),
        );
        ref.invalidate(schoolClassesProvider(widget.schoolId!));
        ref.invalidate(schoolsProvider);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      nameCtrl.dispose();
      gradeCtrl.dispose();
      yearCtrl.dispose();
    }
  }

  Future<void> _deleteClass(Map<String, dynamic> classItem) async {
    final name = classItem['name'] as String? ?? '';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sınıfı Sil'),
        content: Text(
          '"$name" sınıfını silmek istediğinize emin misiniz? '
          'Öğrenciler bu sınıftan çıkarılacaktır.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('İptal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Sil'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      final supabase = ref.read(supabaseClientProvider);
      await supabase
          .from(DbTables.classes)
          .delete()
          .eq('id', classItem['id'] as String);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('"$name" silindi')),
        );
        ref.invalidate(schoolClassesProvider(widget.schoolId!));
        ref.invalidate(schoolsProvider);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _editClass(Map<String, dynamic> classItem) async {
    final classId = classItem['id'] as String;
    final nameCtrl =
        TextEditingController(text: classItem['name'] as String? ?? '');
    final gradeCtrl = TextEditingController(
        text: (classItem['grade'] ?? '').toString());
    final yearCtrl = TextEditingController(
        text: classItem['academic_year'] as String? ?? '');

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sınıfı Düzenle'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Sınıf Adı *',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: gradeCtrl,
                decoration: const InputDecoration(
                  labelText: 'Sınıf Seviyesi',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: yearCtrl,
                decoration: const InputDecoration(
                  labelText: 'Akademik Yıl',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('İptal'),
          ),
          FilledButton(
            onPressed: () {
              if (nameCtrl.text.trim().isEmpty) return;
              Navigator.pop(ctx, true);
            },
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );

    if (result != true || !mounted) {
      nameCtrl.dispose();
      gradeCtrl.dispose();
      yearCtrl.dispose();
      return;
    }

    try {
      final supabase = ref.read(supabaseClientProvider);
      await supabase.from(DbTables.classes).update({
        'name': nameCtrl.text.trim(),
        'grade': int.tryParse(gradeCtrl.text.trim()),
        'academic_year': yearCtrl.text.trim(),
      }).eq('id', classId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sınıf güncellendi')),
        );
        ref.invalidate(schoolClassesProvider(widget.schoolId!));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      nameCtrl.dispose();
      gradeCtrl.dispose();
      yearCtrl.dispose();
    }
  }

  // ============================================
  // STUDENT MANAGEMENT
  // ============================================

  Future<void> _addStudent(String classId) async {
    final availableStudents =
        await ref.read(_availableStudentsProvider(widget.schoolId!).future);

    if (!mounted) return;

    if (availableStudents.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Eklenecek uygun öğrenci yok')),
      );
      return;
    }

    final selectedStudent = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Öğrenci Ekle'),
        content: SizedBox(
          width: 400,
          height: 300,
          child: ListView.builder(
            itemCount: availableStudents.length,
            itemBuilder: (context, index) {
              final student = availableStudents[index];
              final name =
                  '${student['first_name'] ?? ''} ${student['last_name'] ?? ''}'
                      .trim();
              return ListTile(
                leading: CircleAvatar(
                  child:
                      Text(name.isNotEmpty ? name[0].toUpperCase() : '?'),
                ),
                title: Text(
                    name.isNotEmpty ? name : student['email'] ?? 'Unknown'),
                subtitle: Text(student['email'] ?? ''),
                onTap: () => Navigator.pop(ctx, student),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('İptal'),
          ),
        ],
      ),
    );

    if (selectedStudent == null || !mounted) return;

    try {
      final supabase = ref.read(supabaseClientProvider);
      await supabase
          .from(DbTables.profiles)
          .update({'class_id': classId}).eq('id', selectedStudent['id']);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Öğrenci sınıfa eklendi')),
        );
        ref.invalidate(schoolClassesProvider(widget.schoolId!));
        ref.invalidate(_availableStudentsProvider(widget.schoolId!));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _removeStudent(
      String classId, Map<String, dynamic> student) async {
    final name =
        '${student['first_name'] ?? ''} ${student['last_name'] ?? ''}'.trim();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Öğrenciyi Çıkar'),
        content: Text('$name bu sınıftan çıkarılsın mı?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('İptal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Çıkar'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      final supabase = ref.read(supabaseClientProvider);
      await supabase
          .from(DbTables.profiles)
          .update({'class_id': null}).eq('id', student['id']);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Öğrenci sınıftan çıkarıldı')),
        );
        ref.invalidate(schoolClassesProvider(widget.schoolId!));
        ref.invalidate(_availableStudentsProvider(widget.schoolId!));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // ============================================
  // BUILD
  // ============================================

  @override
  Widget build(BuildContext context) {
    return EditScreenShortcuts(
      onSave: _isSaving ? null : _handleSave,
      child: _buildScreen(context),
    );
  }

  Widget _buildScreen(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isNewSchool ? 'Yeni Okul' : 'Okulu Düzenle'),
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
                : Text(isNewSchool ? 'Oluştur' : 'Kaydet'),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- School Form ---
                  _buildSchoolForm(context),

                  // --- Classes Section (only for existing schools) ---
                  if (!isNewSchool) ...[
                    const SizedBox(height: 32),
                    const Divider(),
                    const SizedBox(height: 24),
                    _buildClassesSection(context),
                    const SizedBox(height: 32),
                    _buildUnassignedStudentsSection(context),
                  ],
                ],
              ),
            ),
    );
  }

  // ============================================
  // SCHOOL FORM
  // ============================================

  Widget _buildSchoolForm(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Okul Bilgileri',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 24),

          // Name
          TextFormField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Okul Adı',
              hintText: 'Okul adını girin',
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Okul adı zorunludur';
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
                    labelText: 'Okul Kodu',
                    hintText: 'Benzersiz katılım kodu',
                    helperText: 'Öğrenci ve öğretmenler bu kodla katılır',
                  ),
                  textCapitalization: TextCapitalization.characters,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Okul kodu zorunludur';
                    }
                    if (value.trim().length < 4) {
                      return 'Kod en az 4 karakter olmalıdır';
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: _generateCode,
                icon: const Icon(Icons.refresh),
                tooltip: 'Yeni kod oluştur',
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Logo URL
          TextFormField(
            controller: _logoUrlController,
            decoration: const InputDecoration(
              labelText: 'Logo URL\'si',
              hintText: 'https://...',
            ),
          ),
          const SizedBox(height: 16),

          // Status dropdown
          DropdownButtonFormField<String>(
            value: _status,
            decoration: const InputDecoration(labelText: 'Durum'),
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
              if (value != null) setState(() => _status = value);
            },
          ),
        ],
      ),
    );
  }

  // ============================================
  // CLASSES SECTION
  // ============================================

  Widget _buildClassesSection(BuildContext context) {
    final classesAsync = ref.watch(schoolClassesProvider(widget.schoolId!));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: classesAsync.when(
                data: (classes) => Text(
                  'Sınıflar (${classes.length})',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                loading: () => Text('Sınıflar',
                    style: Theme.of(context).textTheme.titleLarge),
                error: (_, __) => Text('Sınıflar',
                    style: Theme.of(context).textTheme.titleLarge),
              ),
            ),
            FilledButton.icon(
              onPressed: _showAddClassDialog,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Yeni Sınıf'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        classesAsync.when(
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(),
            ),
          ),
          error: (e, _) => Center(
            child: Column(
              children: [
                Text('Hata: $e'),
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: () => ref
                      .invalidate(schoolClassesProvider(widget.schoolId!)),
                  child: const Text('Tekrar Dene'),
                ),
              ],
            ),
          ),
          data: (classes) {
            if (classes.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    children: [
                      Icon(Icons.class_outlined,
                          size: 48, color: Colors.grey.shade400),
                      const SizedBox(height: 12),
                      Text(
                        'Henüz sınıf eklenmemiş',
                        style: TextStyle(
                          fontSize: 15,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            return Column(
              children: classes
                  .map((c) => _ClassCard(
                        classItem: c,
                        onEdit: () => _editClass(c),
                        onDelete: () => _deleteClass(c),
                        onAddStudent: () =>
                            _addStudent(c['id'] as String),
                        onRemoveStudent: (s) =>
                            _removeStudent(c['id'] as String, s),
                      ))
                  .toList(),
            );
          },
        ),
      ],
    );
  }

  // ============================================
  // UNASSIGNED STUDENTS SECTION
  // ============================================

  Widget _buildUnassignedStudentsSection(BuildContext context) {
    final asyncStudents =
        ref.watch(_availableStudentsProvider(widget.schoolId!));

    return asyncStudents.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (students) {
        if (students.isEmpty) return const SizedBox.shrink();
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.orange.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.orange.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.person_off,
                      color: Colors.orange.shade700, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    'Sınıfa atanmamış öğrenciler (${students.length})',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.orange.shade900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Bu öğrenciler okula kayıtlı ama hiçbir sınıfa atanmamış. '
                'Yukarıdaki sınıflarda + butonu ile ekleyin.',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.orange.shade800,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: students.map((s) {
                  final name =
                      '${s['first_name'] ?? ''} ${s['last_name'] ?? ''}'
                          .trim();
                  return InkWell(
                    onTap: () =>
                        context.go('/users/${s['id']}'),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border:
                            Border.all(color: Colors.orange.shade200),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircleAvatar(
                            radius: 10,
                            backgroundColor:
                                Colors.orange.shade100,
                            child: Text(
                              name.isNotEmpty
                                  ? name[0].toUpperCase()
                                  : '?',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.orange.shade900,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            name.isNotEmpty
                                ? name
                                : (s['email'] as String? ?? '?'),
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        );
      },
    );
  }

  // ============================================
  // HELPERS
  // ============================================

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
        return 'Aktif';
      case 'trial':
        return 'Deneme';
      case 'suspended':
        return 'Askıya Alınmış';
      default:
        return status;
    }
  }
}

// ============================================
// CLASS CARD (expandable with students)
// ============================================

class _ClassCard extends StatelessWidget {
  const _ClassCard({
    required this.classItem,
    required this.onEdit,
    required this.onDelete,
    required this.onAddStudent,
    required this.onRemoveStudent,
  });

  final Map<String, dynamic> classItem;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onAddStudent;
  final void Function(Map<String, dynamic> student) onRemoveStudent;

  @override
  Widget build(BuildContext context) {
    final name = classItem['name'] as String? ?? '';
    final grade = classItem['grade'] as int?;
    final academicYear = classItem['academic_year'] as String?;
    final students =
        List<Map<String, dynamic>>.from(classItem['profiles'] ?? []);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.teal.withAlpha(25),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.class_, color: Colors.teal, size: 20),
        ),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Row(
          children: [
            if (grade != null) ...[
              _Chip(label: '$grade. sınıf', color: Colors.purple),
              const SizedBox(width: 6),
            ],
            _Chip(label: '${students.length} öğrenci', color: Colors.blue),
            if (academicYear != null && academicYear.isNotEmpty) ...[
              const SizedBox(width: 6),
              _Chip(label: academicYear, color: Colors.grey),
            ],
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 20),
              tooltip: 'Düzenle',
              onPressed: onEdit,
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 20),
              color: Colors.red,
              tooltip: 'Sil',
              onPressed: onDelete,
            ),
          ],
        ),
        children: [
          const Divider(height: 1),
          // Student list header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Text(
                  'Öğrenciler (${students.length})',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: onAddStudent,
                  icon: const Icon(Icons.person_add_outlined, size: 18),
                  label: const Text('Öğrenci Ekle'),
                ),
              ],
            ),
          ),
          if (students.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                'Henüz öğrenci yok',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
              ),
            )
          else
            ...students.map((student) {
              final sName =
                  '${student['first_name'] ?? ''} ${student['last_name'] ?? ''}'
                      .trim();
              return ListTile(
                dense: true,
                leading: CircleAvatar(
                  radius: 16,
                  backgroundColor: Colors.green.withAlpha(25),
                  child: Text(
                    sName.isNotEmpty ? sName[0].toUpperCase() : '?',
                    style: const TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
                title: Text(
                  sName.isNotEmpty ? sName : student['email'] ?? 'Unknown',
                  style: const TextStyle(fontSize: 14),
                ),
                subtitle: Text(
                  student['email'] ?? '',
                  style: const TextStyle(fontSize: 12),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.remove_circle_outline, size: 18),
                  color: Colors.red,
                  tooltip: 'Sınıftan çıkar',
                  onPressed: () => onRemoveStudent(student),
                ),
              );
            }),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ============================================
// CHIP WIDGET
// ============================================

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
