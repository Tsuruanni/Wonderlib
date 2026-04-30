import 'dart:convert';
import 'dart:math';

import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:owlio_shared/owlio_shared.dart';
import 'package:universal_html/html.dart' as html;

import '../../../core/supabase_client.dart';
import '../../../core/widgets/template_download_button.dart';

// --- Providers ---

final createSchoolsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final supabase = ref.watch(supabaseClientProvider);
  final response =
      await supabase.from(DbTables.schools).select('id, name, code').order('name');
  return List<Map<String, dynamic>>.from(response);
});

final createClassesProvider = FutureProvider.family<List<Map<String, dynamic>>,
    String>((ref, schoolId) async {
  final supabase = ref.watch(supabaseClientProvider);
  final response = await supabase
      .from(DbTables.classes)
      .select('id, name')
      .eq('school_id', schoolId)
      .order('name');
  return List<Map<String, dynamic>>.from(response);
});

// --- Screen ---

class UserCreateScreen extends ConsumerStatefulWidget {
  const UserCreateScreen({super.key});

  @override
  ConsumerState<UserCreateScreen> createState() => _UserCreateScreenState();
}

class _UserCreateScreenState extends ConsumerState<UserCreateScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String? _selectedSchoolId;

  // Single creation form
  bool _isStudent = true;
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  String? _selectedClassId;
  bool _isNewClass = false;
  final _newClassNameController = TextEditingController();

  // Results (shared between tabs)
  final List<Map<String, dynamic>> _createdUsers = [];
  final List<Map<String, dynamic>> _errors = [];

  // Bulk CSV state
  List<Map<String, String>>? _csvRows;
  String? _csvError;

  // Loading
  bool _isProcessing = false;
  double _progress = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _newClassNameController.dispose();
    super.dispose();
  }

  // --- Edge Function Call ---

  Future<void> _callBulkCreate(Map<String, dynamic> body) async {
    final supabase = ref.read(supabaseClientProvider);
    final response = await supabase.functions.invoke(
      'bulk-create-students',
      body: body,
    );

    if (response.status != 200) {
      final error = response.data?['error'] ?? 'Unknown error';
      throw Exception(error);
    }

    final data = response.data as Map<String, dynamic>;
    final created = List<Map<String, dynamic>>.from(data['created'] ?? []);
    final errs = List<Map<String, dynamic>>.from(data['errors'] ?? []);

    setState(() {
      _createdUsers.addAll(created);
      _errors.addAll(errs);
    });
  }

  // --- Single Creation ---

  Future<void> _createSingleUser() async {
    if (_selectedSchoolId == null) {
      _showSnack('Lütfen önce bir okul seçin');
      return;
    }

    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();

    if (firstName.isEmpty || lastName.isEmpty) {
      _showSnack('Ad ve soyad gerekli');
      return;
    }

    if (_isStudent) {
      final className = _isNewClass
          ? _newClassNameController.text.trim()
          : _getSelectedClassName();
      if (className == null || className.isEmpty) {
        _showSnack('Lütfen bir sınıf seçin veya yeni sınıf adı girin');
        return;
      }
    } else {
      final email = _emailController.text.trim();
      if (email.isEmpty || !email.contains('@')) {
        _showSnack('Geçerli bir e-posta adresi girin');
        return;
      }
    }

    setState(() => _isProcessing = true);

    try {
      final body = <String, dynamic>{
        'school_id': _selectedSchoolId,
      };

      if (_isStudent) {
        final className = _isNewClass
            ? _newClassNameController.text.trim()
            : _getSelectedClassName()!;
        body['students'] = [
          {
            'first_name': firstName,
            'last_name': lastName,
            'class_name': className,
          }
        ];
      } else {
        body['teachers'] = [
          {
            'first_name': firstName,
            'last_name': lastName,
            'email': _emailController.text.trim(),
          }
        ];
      }

      await _callBulkCreate(body);

      // Clear form
      _firstNameController.clear();
      _lastNameController.clear();
      _emailController.clear();

      // Refresh class list if new class was created
      if (_isNewClass && _selectedSchoolId != null) {
        ref.invalidate(createClassesProvider(_selectedSchoolId!));
        setState(() {
          _isNewClass = false;
          _newClassNameController.clear();
        });
      }
    } catch (e) {
      _showSnack('Hata: $e');
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  String? _getSelectedClassName() {
    if (_selectedClassId == null || _selectedSchoolId == null) return null;
    final classesAsync = ref.read(createClassesProvider(_selectedSchoolId!));
    return classesAsync.whenOrNull(
      data: (classes) {
        final cls = classes.where((c) => c['id'] == _selectedClassId);
        return cls.isNotEmpty ? cls.first['name'] as String : null;
      },
    );
  }

  // --- Bulk CSV ---

  Future<void> _pickCsvFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
      withData: true,
    );

    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    if (file.bytes == null) {
      setState(() => _csvError = 'Dosya okunamadı');
      return;
    }

    try {
      final content = utf8.decode(file.bytes!);
      final csvData = const CsvToListConverter().convert(content);

      if (csvData.length < 2) {
        setState(() => _csvError = 'CSV dosyası boş veya sadece başlık satırı var');
        return;
      }

      final headers =
          csvData.first.map((e) => e.toString().toLowerCase().trim()).toList();

      // Accept both Turkish and English headers
      final adIdx = headers.indexOf('ad') != -1
          ? headers.indexOf('ad')
          : headers.indexOf('first_name');
      final soyadIdx = headers.indexOf('soyad') != -1
          ? headers.indexOf('soyad')
          : headers.indexOf('last_name');
      final sinifIdx = headers.indexOf('sınıf') != -1
          ? headers.indexOf('sınıf')
          : (headers.indexOf('sinif') != -1
              ? headers.indexOf('sinif')
              : headers.indexOf('class_name'));

      if (adIdx == -1 || soyadIdx == -1 || sinifIdx == -1) {
        setState(() {
          _csvError =
              'Eksik sütunlar. Beklenen: ad, soyad, sınıf\n(veya: first_name, last_name, class_name)';
        });
        return;
      }

      final parsed = <Map<String, String>>[];
      for (var i = 1; i < csvData.length; i++) {
        final row = csvData[i];
        if (row.length <= max(adIdx, max(soyadIdx, sinifIdx))) continue;
        final firstName = row[adIdx].toString().trim();
        final lastName = row[soyadIdx].toString().trim();
        final className = row[sinifIdx].toString().trim();
        if (firstName.isEmpty && lastName.isEmpty) continue;
        parsed.add({
          'first_name': firstName,
          'last_name': lastName,
          'class_name': className,
        });
      }

      setState(() {
        _csvRows = parsed;
        _csvError = null;
      });
    } catch (e) {
      setState(() => _csvError = 'CSV okuma hatası: $e');
    }
  }

  Future<void> _createBulkStudents() async {
    if (_selectedSchoolId == null || _csvRows == null) return;

    setState(() {
      _isProcessing = true;
      _progress = 0;
      _createdUsers.clear();
      _errors.clear();
    });

    try {
      final allStudents = _csvRows!;
      const batchSize = 200;

      for (var i = 0; i < allStudents.length; i += batchSize) {
        final batch =
            allStudents.sublist(i, min(i + batchSize, allStudents.length));

        await _callBulkCreate({
          'school_id': _selectedSchoolId,
          'students': batch
              .map((s) => {
                    'first_name': s['first_name'],
                    'last_name': s['last_name'],
                    'class_name': s['class_name'],
                  })
              .toList(),
        });

        setState(() {
          _progress = (i + batch.length) / allStudents.length;
        });
      }

      setState(() => _csvRows = null);
    } catch (e) {
      _showSnack('Hata: $e');
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  // --- CSV Download ---

  void _downloadCsv() {
    final csvData = [
      ['Ad', 'Soyad', 'Kullanıcı Adı / Email', 'Şifre', 'Sınıf', 'Rol'],
      ..._createdUsers.map((u) => [
            u['first_name'] ?? '',
            u['last_name'] ?? '',
            u['username'] ?? u['email'] ?? '',
            u['password'] ?? '',
            u['class_name'] ?? '',
            u['role'] ?? '',
          ]),
    ];

    final csv = const ListToCsvConverter().convert(csvData);
    final bytes = utf8.encode('\uFEFF$csv'); // BOM for Excel UTF-8
    final blob = html.Blob([bytes], 'text/csv;charset=utf-8;');
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.AnchorElement(href: url)
      ..setAttribute('download', 'olusturulan_kullanicilar.csv')
      ..click();
    html.Url.revokeObjectUrl(url);
  }

  void _showSnack(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  // --- Build ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kullanıcı Oluştur'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/users'),
        ),
      ),
      body: Column(
        children: [
          _buildSchoolSelector(),
          if (_selectedSchoolId != null) ...[
            TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: 'Tekli Oluşturma'),
                Tab(text: 'Toplu CSV'),
              ],
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildSingleTab(),
                  _buildBulkTab(),
                ],
              ),
            ),
          ] else
            const Expanded(
              child: Center(
                child: Text(
                  'Başlamak için bir okul seçin',
                  style: TextStyle(color: Colors.grey, fontSize: 16),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSchoolSelector() {
    final schoolsAsync = ref.watch(createSchoolsProvider);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: schoolsAsync.when(
        data: (schools) => DropdownButtonFormField<String>(
          value: _selectedSchoolId,
          decoration: const InputDecoration(
            labelText: 'Okul',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.school),
          ),
          items: schools
              .map((s) => DropdownMenuItem(
                    value: s['id'] as String,
                    child: Text('${s['name']} (${s['code']})'),
                  ))
              .toList(),
          onChanged: (value) => setState(() {
            _selectedSchoolId = value;
            _selectedClassId = null;
          }),
        ),
        loading: () => const LinearProgressIndicator(),
        error: (e, _) => Text('Hata: $e'),
      ),
    );
  }

  // --- Single Tab ---

  Widget _buildSingleTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Role toggle
          Row(
            children: [
              ChoiceChip(
                label: const Text('Öğrenci'),
                selected: _isStudent,
                onSelected: (_) => setState(() => _isStudent = true),
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('Öğretmen'),
                selected: !_isStudent,
                onSelected: (_) => setState(() => _isStudent = false),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Class selector (student only)
          if (_isStudent) _buildClassSelector(),

          // Name fields
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _firstNameController,
                  decoration: const InputDecoration(
                    labelText: 'Ad',
                    border: OutlineInputBorder(),
                  ),
                  textInputAction: TextInputAction.next,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _lastNameController,
                  decoration: const InputDecoration(
                    labelText: 'Soyad',
                    border: OutlineInputBorder(),
                  ),
                  textInputAction:
                      _isStudent ? TextInputAction.done : TextInputAction.next,
                  onSubmitted: _isStudent ? (_) => _createSingleUser() : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Email field (teacher only)
          if (!_isStudent) ...[
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.email),
              ),
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _createSingleUser(),
            ),
            const SizedBox(height: 12),
          ],

          // Create button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isProcessing ? null : _createSingleUser,
              icon: _isProcessing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.add),
              label: Text(_isStudent ? 'Öğrenci Oluştur' : 'Öğretmen Oluştur'),
            ),
          ),
          const SizedBox(height: 24),

          // Results
          _buildResults(),
        ],
      ),
    );
  }

  Widget _buildClassSelector() {
    if (_selectedSchoolId == null) return const SizedBox.shrink();

    final classesAsync =
        ref.watch(createClassesProvider(_selectedSchoolId!));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        classesAsync.when(
          data: (classes) {
            final items = <DropdownMenuItem<String>>[
              ...classes.map((c) => DropdownMenuItem(
                    value: c['id'] as String,
                    child: Text(c['name'] as String),
                  )),
              const DropdownMenuItem(
                value: '__new__',
                child: Text('+ Yeni sınıf ekle'),
              ),
            ];

            return DropdownButtonFormField<String>(
              value: _isNewClass ? '__new__' : _selectedClassId,
              decoration: const InputDecoration(
                labelText: 'Sınıf',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.class_),
              ),
              items: items,
              onChanged: (value) {
                if (value == '__new__') {
                  setState(() {
                    _isNewClass = true;
                    _selectedClassId = null;
                  });
                } else {
                  setState(() {
                    _isNewClass = false;
                    _selectedClassId = value;
                  });
                }
              },
            );
          },
          loading: () => const LinearProgressIndicator(),
          error: (e, _) => Text('Hata: $e'),
        ),
        if (_isNewClass) ...[
          const SizedBox(height: 12),
          TextField(
            controller: _newClassNameController,
            decoration: const InputDecoration(
              labelText: 'Yeni Sınıf Adı',
              hintText: 'ör. 5-A',
              border: OutlineInputBorder(),
            ),
          ),
        ],
        const SizedBox(height: 12),
      ],
    );
  }

  // --- Bulk Tab ---

  Widget _buildBulkTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // CSV format info
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'CSV sütunları: ad, soyad, sınıf\n'
                    'Tüm öğrenciler seçilen okula atanır. '
                    'Sınıf mevcut değilse otomatik oluşturulur.',
                    style: TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // File picker + template download
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: _isProcessing ? null : _pickCsvFile,
                icon: const Icon(Icons.upload_file),
                label: const Text('CSV Dosyası Seç'),
              ),
              const SizedBox(width: 12),
              const TemplateDownloadButton(
                assetPath: 'assets/import_templates/users_template.csv',
                downloadFilename: 'kullanici_sablonu.csv',
                contentType: 'text/csv;charset=utf-8;',
              ),
            ],
          ),

          if (_csvError != null) ...[
            const SizedBox(height: 8),
            Text(_csvError!, style: const TextStyle(color: Colors.red)),
          ],

          // Preview
          if (_csvRows != null) ...[
            const SizedBox(height: 16),
            Text(
              '${_csvRows!.length} öğrenci bulundu',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 200,
              child: SingleChildScrollView(
                child: DataTable(
                  columnSpacing: 24,
                  columns: const [
                    DataColumn(label: Text('Ad')),
                    DataColumn(label: Text('Soyad')),
                    DataColumn(label: Text('Sınıf')),
                  ],
                  rows: _csvRows!
                      .take(50) // Show first 50 for preview
                      .map((r) => DataRow(cells: [
                            DataCell(Text(r['first_name'] ?? '')),
                            DataCell(Text(r['last_name'] ?? '')),
                            DataCell(Text(r['class_name'] ?? '')),
                          ]))
                      .toList(),
                ),
              ),
            ),
            if (_csvRows!.length > 50)
              Text(
                '... ve ${_csvRows!.length - 50} öğrenci daha',
                style: TextStyle(color: Colors.grey.shade600),
              ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isProcessing ? null : _createBulkStudents,
                icon: _isProcessing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.group_add),
                label: Text('Oluştur (${_csvRows!.length} öğrenci)'),
              ),
            ),
          ],

          // Progress
          if (_isProcessing && _progress > 0) ...[
            const SizedBox(height: 12),
            LinearProgressIndicator(value: _progress),
            Text('${(_progress * 100).toInt()}%'),
          ],

          const SizedBox(height: 24),

          // Results
          _buildResults(),
        ],
      ),
    );
  }

  // --- Results ---

  Widget _buildResults() {
    if (_createdUsers.isEmpty && _errors.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Warning
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.orange.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.orange.shade200),
          ),
          child: const Row(
            children: [
              Icon(Icons.warning_amber, color: Colors.orange),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Bu şifreler bir daha gösterilemez. Lütfen CSV olarak indirin.',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Summary
        Row(
          children: [
            if (_createdUsers.isNotEmpty)
              Chip(
                avatar: const Icon(Icons.check_circle, color: Colors.green, size: 18),
                label: Text('${_createdUsers.length} oluşturuldu'),
              ),
            if (_errors.isNotEmpty) ...[
              const SizedBox(width: 8),
              Chip(
                avatar: const Icon(Icons.error, color: Colors.red, size: 18),
                label: Text('${_errors.length} hata'),
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),

        // Results table
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columnSpacing: 16,
            columns: const [
              DataColumn(label: Text('Ad Soyad')),
              DataColumn(label: Text('Kullanıcı Adı')),
              DataColumn(label: Text('Şifre')),
              DataColumn(label: Text('Sınıf')),
              DataColumn(label: Text('Durum')),
            ],
            rows: [
              ..._createdUsers.map((u) => DataRow(cells: [
                    DataCell(Text('${u['first_name']} ${u['last_name']}')),
                    DataCell(SelectableText(
                      u['username'] as String? ?? u['email'] as String? ?? '',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    )),
                    DataCell(SelectableText(
                      u['password'] as String? ?? '',
                      style: const TextStyle(fontFamily: 'monospace'),
                    )),
                    DataCell(Text(u['class_name'] as String? ?? '')),
                    DataCell(
                        Icon(Icons.check_circle, color: Colors.green.shade600)),
                  ])),
              ..._errors.map((e) => DataRow(cells: [
                    DataCell(Text('${e['first_name']} ${e['last_name']}')),
                    DataCell(const Text('-')),
                    DataCell(const Text('-')),
                    DataCell(const Text('-')),
                    DataCell(Tooltip(
                      message: e['error'] as String? ?? '',
                      child: Icon(Icons.error, color: Colors.red.shade600),
                    )),
                  ])),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Download button
        Row(
          children: [
            ElevatedButton.icon(
              onPressed: _createdUsers.isNotEmpty ? _downloadCsv : null,
              icon: const Icon(Icons.download),
              label: const Text('CSV İndir'),
            ),
            const SizedBox(width: 12),
            OutlinedButton(
              onPressed: () => setState(() {
                _createdUsers.clear();
                _errors.clear();
              }),
              child: const Text('Temizle'),
            ),
          ],
        ),
      ],
    );
  }
}
