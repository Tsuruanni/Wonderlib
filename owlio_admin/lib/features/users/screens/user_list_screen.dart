import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:owlio_shared/owlio_shared.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // CountOption

import '../../../core/supabase_client.dart';
import '../../../core/utils/role_helpers.dart';

/// Provider for school filter
final schoolFilterProvider = StateProvider<String?>((ref) => null);

/// Provider for class filter
final classFilterProvider = StateProvider<String?>((ref) => null);

/// Provider for role filter
final roleFilterProvider = StateProvider<String?>((ref) => null);

/// Search query (matches first_name / last_name / email / username)
final userSearchProvider = StateProvider<String>((ref) => '');

/// Current page index (0-based)
final userPageProvider = StateProvider<int>((ref) => 0);

/// Classes for selected school (for filter dropdown)
final _filterClassesProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>(
        (ref, schoolId) async {
  final supabase = ref.watch(supabaseClientProvider);
  final response = await supabase
      .from(DbTables.classes)
      .select('id, name, grade')
      .eq('school_id', schoolId)
      .order('grade')
      .order('name');
  return List<Map<String, dynamic>>.from(response);
});

/// Loads users with filters, search, and pagination.
/// Returns `{ data, total, page, pageSize }`.
final usersProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final supabase = ref.watch(supabaseClientProvider);
  final schoolFilter = ref.watch(schoolFilterProvider);
  final classFilter = ref.watch(classFilterProvider);
  final roleFilter = ref.watch(roleFilterProvider);
  final search = ref.watch(userSearchProvider);
  final page = ref.watch(userPageProvider);

  const pageSize = 50;
  final offset = page * pageSize;

  var query = supabase
      .from(DbTables.profiles)
      .select('*, schools(name), classes(name, grade)');
  var countQuery = supabase.from(DbTables.profiles).select();

  if (schoolFilter != null) {
    query = query.eq('school_id', schoolFilter);
    countQuery = countQuery.eq('school_id', schoolFilter);
  }
  if (classFilter != null) {
    query = query.eq('class_id', classFilter);
    countQuery = countQuery.eq('class_id', classFilter);
  }
  if (roleFilter != null) {
    query = query.eq('role', roleFilter);
    countQuery = countQuery.eq('role', roleFilter);
  }
  if (search.isNotEmpty) {
    final escaped = search.replaceAll(',', ' ');
    final orFilter =
        'first_name.ilike.%$escaped%,last_name.ilike.%$escaped%,'
        'email.ilike.%$escaped%,username.ilike.%$escaped%';
    query = query.or(orFilter);
    countQuery = countQuery.or(orFilter);
  }

  final response = await query
      .order('created_at', ascending: false)
      .range(offset, offset + pageSize - 1);
  final countResult = await countQuery.count(CountOption.exact);

  return {
    'data': List<Map<String, dynamic>>.from(response),
    'total': countResult.count,
    'page': page,
    'pageSize': pageSize,
  };
});

/// Provider for loading all schools (for filter dropdown)
final allSchoolsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final supabase = ref.watch(supabaseClientProvider);
  final response = await supabase
      .from(DbTables.schools)
      .select('id, name')
      .order('name');
  return List<Map<String, dynamic>>.from(response);
});

class UserListScreen extends ConsumerStatefulWidget {
  const UserListScreen({super.key});

  @override
  ConsumerState<UserListScreen> createState() => _UserListScreenState();
}

class _UserListScreenState extends ConsumerState<UserListScreen> {
  final _searchController = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _searchController.text = ref.read(userSearchProvider);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _resetPage() {
    ref.read(userPageProvider.notifier).state = 0;
  }

  void _onSearchChanged(String value) {
    setState(() {});
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      final trimmed = value.trim();
      if (ref.read(userSearchProvider) != trimmed) {
        ref.read(userSearchProvider.notifier).state = trimmed;
        _resetPage();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final usersAsync = ref.watch(usersProvider);
    final schoolsAsync = ref.watch(allSchoolsProvider);
    final selectedSchool = ref.watch(schoolFilterProvider);
    final selectedClass = ref.watch(classFilterProvider);
    final selectedRole = ref.watch(roleFilterProvider);
    final currentPage = ref.watch(userPageProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kullanıcılar'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
        actions: [
          OutlinedButton.icon(
            onPressed: () => context.go('/users/create'),
            icon: const Icon(Icons.person_add, size: 18),
            label: const Text('Kullanıcı Oluştur'),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Column(
        children: [
          // Filters
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              border: Border(
                bottom: BorderSide(color: Colors.grey.shade200),
              ),
            ),
            child: Column(
              children: [
                // Row 1: Search
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Ad, soyad, e-posta veya kullanıcı adı ara...',
                    prefixIcon: const Icon(Icons.search),
                    border: const OutlineInputBorder(),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _debounce?.cancel();
                              _searchController.clear();
                              ref.read(userSearchProvider.notifier).state = '';
                              _resetPage();
                              setState(() {});
                            },
                          )
                        : null,
                  ),
                  onChanged: _onSearchChanged,
                ),
                const SizedBox(height: 12),
                // Row 2: Dropdowns
                Row(
                  children: [
                    // School filter
                    Expanded(
                      child: schoolsAsync.when(
                        data: (schools) => DropdownButtonFormField<String?>(
                          value: selectedSchool,
                          decoration: const InputDecoration(
                            labelText: 'Okul',
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            border: OutlineInputBorder(),
                          ),
                          items: [
                            const DropdownMenuItem(
                              value: null,
                              child: Text('Tüm Okullar'),
                            ),
                            ...schools.map((school) => DropdownMenuItem(
                                  value: school['id'] as String,
                                  child: Text(school['name'] as String),
                                )),
                          ],
                          onChanged: (value) {
                            ref.read(schoolFilterProvider.notifier).state =
                                value;
                            ref.read(classFilterProvider.notifier).state = null;
                            _resetPage();
                          },
                        ),
                        loading: () => const SizedBox.shrink(),
                        error: (_, __) => const SizedBox.shrink(),
                      ),
                    ),
                    const SizedBox(width: 16),

                    // Class filter (only when school is selected)
                    if (selectedSchool != null)
                      Expanded(
                        child: ref
                            .watch(_filterClassesProvider(selectedSchool))
                            .when(
                          data: (classes) => DropdownButtonFormField<String?>(
                            value: selectedClass,
                            decoration: const InputDecoration(
                              labelText: 'Sınıf',
                              contentPadding: EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              border: OutlineInputBorder(),
                            ),
                            items: [
                              const DropdownMenuItem(
                                  value: null, child: Text('Tüm Sınıflar')),
                              ...classes.map((cls) => DropdownMenuItem(
                                    value: cls['id'] as String,
                                    child: Text(
                                      '${cls['name']} (${cls['grade'] ?? '?'}. Sınıf)',
                                    ),
                                  )),
                            ],
                            onChanged: (value) {
                              ref.read(classFilterProvider.notifier).state =
                                  value;
                              _resetPage();
                            },
                          ),
                          loading: () => const SizedBox.shrink(),
                          error: (_, __) => const SizedBox.shrink(),
                        ),
                      ),
                    if (selectedSchool != null) const SizedBox(width: 16),

                    // Role filter
                    Expanded(
                      child: DropdownButtonFormField<String?>(
                        value: selectedRole,
                        decoration: const InputDecoration(
                          labelText: 'Rol',
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          const DropdownMenuItem(
                              value: null, child: Text('Tüm Roller')),
                          DropdownMenuItem(
                              value: UserRole.student.dbValue,
                              child: const Text('Öğrenci')),
                          DropdownMenuItem(
                              value: UserRole.teacher.dbValue,
                              child: const Text('Öğretmen')),
                          DropdownMenuItem(
                              value: UserRole.head.dbValue,
                              child: const Text('Baş Öğretmen')),
                          DropdownMenuItem(
                              value: UserRole.admin.dbValue,
                              child: const Text('Admin')),
                        ],
                        onChanged: (value) {
                          ref.read(roleFilterProvider.notifier).state = value;
                          _resetPage();
                        },
                      ),
                    ),
                    const SizedBox(width: 16),

                    // Clear filters
                    if (selectedSchool != null ||
                        selectedClass != null ||
                        selectedRole != null ||
                        ref.read(userSearchProvider).isNotEmpty)
                      TextButton.icon(
                        onPressed: () {
                          ref.read(schoolFilterProvider.notifier).state = null;
                          ref.read(classFilterProvider.notifier).state = null;
                          ref.read(roleFilterProvider.notifier).state = null;
                          ref.read(userSearchProvider.notifier).state = '';
                          _searchController.clear();
                          _resetPage();
                        },
                        icon: const Icon(Icons.clear, size: 18),
                        label: const Text('Temizle'),
                      ),
                  ],
                ),
              ],
            ),
          ),

          // Users list
          Expanded(
            child: usersAsync.when(
              data: (result) {
                final users = result['data'] as List<Map<String, dynamic>>;
                final total = result['total'] as int;
                final pageSize = result['pageSize'] as int;
                final totalPages = total == 0 ? 1 : (total / pageSize).ceil();

                if (users.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.people_outline,
                          size: 64,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Kullanıcı bulunamadı',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Filtreleri değiştirin veya yeni kullanıcı oluşturun',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return Column(
                  children: [
                    // Results info
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '$total kullanıcıdan ${users.length} tanesi',
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                          Text(
                            'Sayfa ${currentPage + 1} / $totalPages',
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ),
                    // List
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        itemCount: users.length,
                        itemBuilder: (context, index) {
                          final user = users[index];
                          return _UserCard(
                            user: user,
                            onTap: () => context.go('/users/${user['id']}'),
                          );
                        },
                      ),
                    ),
                    // Pagination controls
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            onPressed: currentPage > 0
                                ? () => ref
                                    .read(userPageProvider.notifier)
                                    .state = currentPage - 1
                                : null,
                            icon: const Icon(Icons.chevron_left),
                          ),
                          const SizedBox(width: 16),
                          Text('Sayfa ${currentPage + 1} / $totalPages'),
                          const SizedBox(width: 16),
                          IconButton(
                            onPressed: currentPage < totalPages - 1
                                ? () => ref
                                    .read(userPageProvider.notifier)
                                    .state = currentPage + 1
                                : null,
                            icon: const Icon(Icons.chevron_right),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline,
                        size: 48, color: Colors.red.shade400),
                    const SizedBox(height: 16),
                    Text('Hata: $error'),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () => ref.invalidate(usersProvider),
                      child: const Text('Tekrar Dene'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _UserCard extends StatelessWidget {
  const _UserCard({
    required this.user,
    required this.onTap,
  });

  final Map<String, dynamic> user;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final firstName = user['first_name'] as String? ?? '';
    final lastName = user['last_name'] as String? ?? '';
    final email = user['email'] as String? ?? '';
    final username = user['username'] as String?;
    final role = user['role'] as String? ?? 'student';
    final schoolName = user['schools']?['name'] as String?;
    final xp = user['xp'] as int? ?? 0;
    final level = user['level'] as int? ?? 1;

    final fullName = '$firstName $lastName'.trim();
    final displayName = fullName.isNotEmpty ? fullName : email;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Avatar
              CircleAvatar(
                radius: 24,
                backgroundColor: getRoleColor(role).withValues(alpha: 0.1),
                child: Text(
                  _getInitials(firstName, lastName, email),
                  style: TextStyle(
                    color: getRoleColor(role),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 16),

              // User info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name
                    Text(
                      displayName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),

                    // Username or email
                    if (username != null)
                      Text(
                        '@$username',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      )
                    else if (fullName.isNotEmpty && email.isNotEmpty)
                      Text(
                        email,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    const SizedBox(height: 8),

                    // Chips
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        _Chip(
                          label: getRoleLabel(role),
                          color: getRoleColor(role),
                        ),
                        if (schoolName != null)
                          _Chip(
                            label: schoolName,
                            color: Colors.grey,
                          ),
                        _Chip(
                          label: 'Lv.$level ($xp XP)',
                          color: Colors.purple,
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Arrow
              Icon(
                Icons.chevron_right,
                color: Colors.grey.shade400,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getInitials(String firstName, String lastName, String email) {
    if (firstName.isNotEmpty && lastName.isNotEmpty) {
      return '${firstName[0]}${lastName[0]}'.toUpperCase();
    }
    if (firstName.isNotEmpty) {
      return firstName[0].toUpperCase();
    }
    if (email.isNotEmpty) {
      return email[0].toUpperCase();
    }
    return '?';
  }

}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
