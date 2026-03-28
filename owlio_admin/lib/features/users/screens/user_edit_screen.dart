import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:owlio_shared/owlio_shared.dart';

import '../../../core/supabase_client.dart';
import '../../../core/utils/role_helpers.dart';
import 'user_list_screen.dart';

/// Provider for loading a single user
final userDetailProvider =
    FutureProvider.family<Map<String, dynamic>?, String>((ref, userId) async {
  final supabase = ref.watch(supabaseClientProvider);
  final response = await supabase
      .from(DbTables.profiles)
      .select('*, schools(id, name)')
      .eq('id', userId)
      .maybeSingle();

  return response;
});

/// Provider for user's reading progress
final userReadingProgressProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>(
        (ref, userId) async {
  final supabase = ref.watch(supabaseClientProvider);
  return List<Map<String, dynamic>>.from(await supabase
      .from(DbTables.readingProgress)
      .select('*, books(title, level)')
      .eq('user_id', userId)
      .order('updated_at', ascending: false));
});

/// Provider for user's badges
final userBadgesProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>(
        (ref, userId) async {
  final supabase = ref.watch(supabaseClientProvider);
  return List<Map<String, dynamic>>.from(await supabase
      .from(DbTables.userBadges)
      .select('*, badges(name, icon, description)')
      .eq('user_id', userId)
      .order('earned_at', ascending: false));
});

/// Provider for user's cards
final userCardsProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>(
        (ref, userId) async {
  final supabase = ref.watch(supabaseClientProvider);
  return List<Map<String, dynamic>>.from(await supabase
      .from(DbTables.userCards)
      .select('*, myth_cards(card_no, name, category, rarity, power)')
      .eq('user_id', userId)
      .order('first_obtained_at', ascending: false));
});

/// Provider for user's quiz results
final userQuizResultsProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>(
        (ref, userId) async {
  final supabase = ref.watch(supabaseClientProvider);
  return List<Map<String, dynamic>>.from(await supabase
      .from(DbTables.bookQuizResults)
      .select('*, book_quizzes(title, books(title))')
      .eq('user_id', userId)
      .order('completed_at', ascending: false));
});

class UserEditScreen extends ConsumerStatefulWidget {
  const UserEditScreen({super.key, required this.userId});

  final String userId;

  @override
  ConsumerState<UserEditScreen> createState() => _UserEditScreenState();
}

class _UserEditScreenState extends ConsumerState<UserEditScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _studentNumberController = TextEditingController();
  late final TabController _tabController;

  static final _validRoles = UserRole.values.map((r) => r.dbValue).toList();

  String _role = UserRole.student.dbValue;
  String? _schoolId;
  String? _username;
  String? _passwordPlain;
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
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
      final dbRole = user['role'] as String? ?? UserRole.student.dbValue;
      setState(() {
        _role = _validRoles.contains(dbRole) ? dbRole : 'student';
        _schoolId = user['school_id'] as String?;
        _username = user['username'] as String?;
        _passwordPlain = user['password_plain'] as String?;
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
    _tabController.dispose();
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

      await supabase
          .from(DbTables.profiles)
          .update(data)
          .eq('id', widget.userId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Kullanıcı başarıyla kaydedildi')),
        );
        ref.invalidate(userDetailProvider(widget.userId));
        ref.invalidate(usersProvider);
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

  Future<void> _handleResetProgress() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('İlerlemeyi Sıfırla'),
        content: const Text(
          'Bu kullanıcının XP ve seviyesini sıfırlamak istediğinizden emin misiniz? '
          'Bu işlem geri alınamaz.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('İptal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Sıfırla'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final supabase = ref.read(supabaseClientProvider);
      await supabase.from(DbTables.profiles).update({
        'xp': 0,
        'level': 1,
        'current_streak': 0,
      }).eq('id', widget.userId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('İlerleme başarıyla sıfırlandı')),
        );
        ref.invalidate(userDetailProvider(widget.userId));
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
        title: const Text('Kullanıcı Düzenle'),
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
                : const Text('Kaydet'),
          ),
          const SizedBox(width: 16),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.person), text: 'Profil'),
            Tab(icon: Icon(Icons.trending_up), text: 'İlerleme'),
            Tab(icon: Icon(Icons.style), text: 'Kartlar'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildProfileTab(schoolsAsync),
                _UserProgressTab(userId: widget.userId),
                _UserCardsTab(userId: widget.userId),
              ],
            ),
    );
  }

  Widget _buildProfileTab(AsyncValue<List<Map<String, dynamic>>> schoolsAsync) {
    return SingleChildScrollView(
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
                      'Yeni kullanıcılar Kullanıcı Oluştur sayfasından eklenebilir. '
                      'Bu ekran yalnızca mevcut kullanıcıları düzenlemek içindir.',
                      style: TextStyle(color: Colors.blue.shade700),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            Text(
              'Kullanıcı Bilgileri',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 24),

            // Username + Password (read-only, students only)
            if (_username != null) ...[
              TextFormField(
                initialValue: _username,
                decoration: const InputDecoration(
                  labelText: 'Username',
                  helperText: 'Kullanıcı adı değiştirilemez',
                  prefixIcon: Icon(Icons.alternate_email),
                ),
                readOnly: true,
                enabled: false,
              ),
              const SizedBox(height: 16),
            ],
            if (_passwordPlain != null) ...[
              TextFormField(
                initialValue: _passwordPlain,
                decoration: const InputDecoration(
                  labelText: 'Şifre',
                  prefixIcon: Icon(Icons.lock),
                ),
                readOnly: true,
                enabled: false,
              ),
              const SizedBox(height: 16),
            ],

            // Email (read-only)
            TextFormField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'E-posta',
                helperText: 'E-posta değiştirilemez',
              ),
              readOnly: true,
              enabled: false,
            ),
            const SizedBox(height: 16),

            // First name
            TextFormField(
              controller: _firstNameController,
              decoration: const InputDecoration(
                labelText: 'Ad',
                hintText: 'Adını girin',
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Ad zorunludur';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Last name
            TextFormField(
              controller: _lastNameController,
              decoration: const InputDecoration(
                labelText: 'Soyad',
                hintText: 'Soyadını girin',
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Soyad zorunludur';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Role dropdown
            DropdownButtonFormField<String>(
              value: _role,
              decoration: const InputDecoration(
                labelText: 'Rol',
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
                          color: getRoleColor(role),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(getRoleLabel(role)),
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
                  labelText: 'Okul',
                  helperText: 'Öğrenci ve öğretmenler için zorunludur',
                ),
                items: [
                  const DropdownMenuItem(
                    value: null,
                    child: Text('Okul Yok'),
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
                  if ((_role == UserRole.student.dbValue ||
                          _role == UserRole.teacher.dbValue) &&
                      value == null) {
                    return 'Öğrenci ve öğretmenler için okul zorunludur';
                  }
                  return null;
                },
              ),
              loading: () => const LinearProgressIndicator(),
              error: (_, __) => const Text('Okullar yüklenirken hata oluştu'),
            ),
            const SizedBox(height: 16),

            // Student number (only for students)
            if (_role == UserRole.student.dbValue)
              TextFormField(
                controller: _studentNumberController,
                decoration: const InputDecoration(
                  labelText: 'Öğrenci Numarası',
                  hintText: 'ör. 2024001',
                ),
              ),
            const SizedBox(height: 32),

            // Danger zone
            Text(
              'Tehlikeli Bölge',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.red,
                  ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _handleResetProgress,
              icon: const Icon(Icons.refresh),
              label: const Text('XP ve İlerlemeyi Sıfırla'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.orange,
                side: const BorderSide(color: Colors.orange),
              ),
            ),
          ],
        ),
      ),
    );
  }

}

// ─── Progress Tab ───────────────────────────────────────────

class _UserProgressTab extends ConsumerWidget {
  const _UserProgressTab({required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final readingAsync = ref.watch(userReadingProgressProvider(userId));
    final badgesAsync = ref.watch(userBadgesProvider(userId));
    final quizAsync = ref.watch(userQuizResultsProvider(userId));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Reading Progress
          Text('Okuma İlerlemesi',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          readingAsync.when(
            data: (progress) {
              if (progress.isEmpty) {
                return _emptyState('Henüz okuma ilerlemesi yok');
              }
              return SizedBox(
                width: double.infinity,
                child: DataTable(
                  headingRowColor: WidgetStateColor.resolveWith(
                      (_) => Colors.grey.shade100),
                  columns: const [
                    DataColumn(label: Text('Kitap')),
                    DataColumn(label: Text('Seviye')),
                    DataColumn(label: Text('İlerleme'), numeric: true),
                    DataColumn(label: Text('Son Okuma')),
                  ],
                  rows: progress.map((p) {
                    final book =
                        p['books'] as Map<String, dynamic>?;
                    final title = book?['title'] as String? ?? 'Unknown';
                    final level = book?['level'] as String? ?? '-';
                    final completionPct =
                        (p['completion_percentage'] as num?)?.toDouble() ?? 0;
                    final updatedAt =
                        DateTime.tryParse(p['updated_at'] ?? '');
                    return DataRow(cells: [
                      DataCell(Text(title,
                          style: const TextStyle(
                              fontWeight: FontWeight.w500))),
                      DataCell(_LevelChip(level: level)),
                      DataCell(Text('${completionPct.toStringAsFixed(0)}%')),
                      DataCell(Text(_formatDate(updatedAt))),
                    ]);
                  }).toList(),
                ),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('Hata: $e'),
          ),
          const SizedBox(height: 32),

          // Badges
          Text('Kazanılan Rozetler',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          badgesAsync.when(
            data: (badges) {
              if (badges.isEmpty) {
                return _emptyState('Henüz kazanılan rozet yok');
              }
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: badges.map((ub) {
                  final badge =
                      ub['badges'] as Map<String, dynamic>?;
                  final icon = badge?['icon'] as String? ?? '🏆';
                  final name = badge?['name'] as String? ?? 'Badge';
                  final earnedAt =
                      DateTime.tryParse(ub['earned_at'] ?? '');
                  return Chip(
                    avatar: Text(icon, style: const TextStyle(fontSize: 18)),
                    label: Text(name),
                    deleteIcon: Text(
                      _formatDate(earnedAt),
                      style: TextStyle(
                          fontSize: 10, color: Colors.grey.shade500),
                    ),
                    onDeleted: null,
                  );
                }).toList(),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('Hata: $e'),
          ),
          const SizedBox(height: 32),

          // Quiz Results
          Text('Quiz Sonuçları',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          quizAsync.when(
            data: (results) {
              if (results.isEmpty) {
                return _emptyState('Henüz quiz sonucu yok');
              }
              return SizedBox(
                width: double.infinity,
                child: DataTable(
                  headingRowColor: WidgetStateColor.resolveWith(
                      (_) => Colors.grey.shade100),
                  columns: const [
                    DataColumn(label: Text('Quiz')),
                    DataColumn(label: Text('Puan'), numeric: true),
                    DataColumn(label: Text('Geçti')),
                    DataColumn(label: Text('Tarih')),
                  ],
                  rows: results.map((r) {
                    final quiz =
                        r['book_quizzes'] as Map<String, dynamic>?;
                    final quizTitle =
                        quiz?['title'] as String? ?? 'Quiz';
                    final score = (r['score'] as num?)?.toInt() ?? 0;
                    final maxScore =
                        (r['max_score'] as num?)?.toInt() ?? 0;
                    final passed = r['is_passing'] as bool? ?? false;
                    final completedAt =
                        DateTime.tryParse(r['completed_at'] ?? '');
                    return DataRow(cells: [
                      DataCell(Text(quizTitle)),
                      DataCell(Text('$score/$maxScore')),
                      DataCell(Icon(
                        passed ? Icons.check_circle : Icons.cancel,
                        size: 18,
                        color: passed ? Colors.green : Colors.red,
                      )),
                      DataCell(Text(_formatDate(completedAt))),
                    ]);
                  }).toList(),
                ),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('Hata: $e'),
          ),
        ],
      ),
    );
  }

  Widget _emptyState(String message) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: Text(message,
            style: TextStyle(fontSize: 14, color: Colors.grey.shade500)),
      ),
    );
  }

  static String _formatDate(DateTime? date) {
    if (date == null) return '-';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}

class _LevelChip extends StatelessWidget {
  const _LevelChip({required this.level});

  final String level;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        level,
        style: const TextStyle(
          fontSize: 11,
          color: Colors.blue,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ─── Cards Tab ──────────────────────────────────────────────

class _UserCardsTab extends ConsumerWidget {
  const _UserCardsTab({required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cardsAsync = ref.watch(userCardsProvider(userId));

    return cardsAsync.when(
      data: (cards) {
        if (cards.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.style_outlined,
                    size: 64, color: Colors.grey.shade400),
                const SizedBox(height: 16),
                Text('Henüz toplanan kart yok',
                    style:
                        TextStyle(fontSize: 16, color: Colors.grey.shade500)),
              ],
            ),
          );
        }

        // Group by category
        final byCategory = <String, List<Map<String, dynamic>>>{};
        for (final uc in cards) {
          final mc = uc['myth_cards'] as Map<String, dynamic>?;
          final cat = mc?['category'] as String? ?? 'unknown';
          byCategory.putIfAbsent(cat, () => []).add(uc);
        }

        final uniqueCount =
            cards.map((c) => (c['myth_cards'] as Map?)?['card_no']).toSet().length;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Stats
              Row(
                children: [
                  _StatCard(
                    label: 'Toplam Kart',
                    value: '${cards.length}',
                    icon: Icons.style,
                    color: Colors.blue,
                  ),
                  const SizedBox(width: 16),
                  _StatCard(
                    label: 'Benzersiz Kart',
                    value: '$uniqueCount',
                    icon: Icons.grid_view,
                    color: Colors.purple,
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // By category
              ...byCategory.entries.map((entry) {
                final category = CardCategory.fromDbValue(entry.key);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${category.label} (${entry.value.length})',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: entry.value.map((uc) {
                        final mc =
                            uc['myth_cards'] as Map<String, dynamic>?;
                        final cardNo =
                            mc?['card_no'] as String? ?? '';
                        final name =
                            mc?['name'] as String? ?? 'Unknown';
                        final rarity = CardRarity.fromDbValue(
                            mc?['rarity'] as String? ?? '');
                        return Chip(
                          label: Text('$cardNo $name'),
                          backgroundColor:
                              _rarityBgColor(rarity),
                          labelStyle: TextStyle(
                            fontSize: 12,
                            color: _rarityColor(rarity),
                          ),
                          side: BorderSide(
                            color: _rarityColor(rarity)
                                .withValues(alpha: 0.3),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                  ],
                );
              }),
            ],
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Hata: $e')),
    );
  }

  static Color _rarityColor(CardRarity rarity) {
    switch (rarity) {
      case CardRarity.common:
        return Colors.grey.shade700;
      case CardRarity.rare:
        return Colors.blue.shade700;
      case CardRarity.epic:
        return Colors.purple.shade700;
      case CardRarity.legendary:
        return Colors.amber.shade800;
    }
  }

  static Color _rarityBgColor(CardRarity rarity) {
    switch (rarity) {
      case CardRarity.common:
        return Colors.grey.shade100;
      case CardRarity.rare:
        return Colors.blue.shade50;
      case CardRarity.epic:
        return Colors.purple.shade50;
      case CardRarity.legendary:
        return Colors.amber.shade50;
    }
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value,
                    style: const TextStyle(
                        fontSize: 24, fontWeight: FontWeight.bold)),
                Text(label,
                    style: TextStyle(
                        fontSize: 12, color: Colors.grey.shade600)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
