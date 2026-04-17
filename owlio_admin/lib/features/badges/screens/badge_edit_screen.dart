import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:owlio_shared/owlio_shared.dart';
import 'package:uuid/uuid.dart';

import '../../../core/supabase_client.dart';
import '../../../core/utils/badge_helpers.dart';
import 'badge_list_screen.dart';

/// Provider for loading a single badge
final badgeDetailProvider =
    FutureProvider.family<Map<String, dynamic>?, String>((ref, badgeId) async {
  final supabase = ref.watch(supabaseClientProvider);
  final response = await supabase
      .from(DbTables.badges)
      .select()
      .eq('id', badgeId)
      .maybeSingle();

  return response;
});

/// Provider for loading students who earned a specific badge
final badgeEarnedByProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((ref, badgeId) async {
  final supabase = ref.watch(supabaseClientProvider);
  final response = await supabase
      .from(DbTables.userBadges)
      .select('earned_at, profiles(id, first_name, last_name)')
      .eq('badge_id', badgeId)
      .order('earned_at', ascending: false);

  return List<Map<String, dynamic>>.from(response);
});

/// All monthly quests (active + inactive) for the badge editor's quest picker.
/// Inactive ones still appear so admins can attach badges in advance.
final _monthlyQuestsForBadgePickerProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final supabase = ref.watch(supabaseClientProvider);
  final response = await supabase
      .from(DbTables.monthlyQuests)
      .select('id, title, icon, is_active')
      .order('sort_order', ascending: true);
  return List<Map<String, dynamic>>.from(response);
});

class BadgeEditScreen extends ConsumerStatefulWidget {
  const BadgeEditScreen({super.key, this.badgeId});

  final String? badgeId;

  @override
  ConsumerState<BadgeEditScreen> createState() => _BadgeEditScreenState();
}

class _BadgeEditScreenState extends ConsumerState<BadgeEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _slugController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _iconController = TextEditingController();
  final _conditionValueController = TextEditingController();
  final _xpRewardController = TextEditingController();

  static final _conditionTypes = [
    (BadgeConditionType.xpTotal.dbValue, 'Toplam Kazanılan XP'),
    (BadgeConditionType.streakDays.dbValue, 'Ardışık Aktif Gün'),
    (BadgeConditionType.booksCompleted.dbValue, 'Tamamlanan Kitaplar'),
    (BadgeConditionType.vocabularyLearned.dbValue, 'Öğrenilen Kelimeler'),
    (BadgeConditionType.levelCompleted.dbValue, 'Ulaşılan Seviye'),
    (BadgeConditionType.cardsCollected.dbValue, 'Toplanan Kart Sayısı'),
    (BadgeConditionType.mythCategoryCompleted.dbValue, 'Kategori Bazlı Kart Toplama'),
    (BadgeConditionType.leagueTierReached.dbValue, 'Ulaşılan Lig'),
    (BadgeConditionType.monthlyQuestCompleted.dbValue, 'Aylık Görev Tamamlama (Milestone)'),
  ];

  static const _categories = [
    'achievement', 'streak', 'reading', 'vocabulary',
    'activities', 'xp', 'level', 'special',
  ];

  String _conditionType = BadgeConditionType.xpTotal.dbValue;
  String? _conditionParam;
  String _category = 'achievement';
  bool _isLoading = false;
  bool _isSaving = false;

  bool get isNewBadge => widget.badgeId == null;

  @override
  void initState() {
    super.initState();
    if (!isNewBadge) {
      _loadBadge();
    } else {
      _iconController.text = '🏆';
      _conditionValueController.text = '100';
      _xpRewardController.text = '50';
    }
  }

  Future<void> _loadBadge() async {
    setState(() => _isLoading = true);

    final badge = await ref.read(badgeDetailProvider(widget.badgeId!).future);
    if (badge != null && mounted) {
      _nameController.text = badge['name'] ?? '';
      _slugController.text = badge['slug'] ?? '';
      _descriptionController.text = badge['description'] ?? '';
      _iconController.text = badge['icon'] ?? '🏆';
      _conditionValueController.text = (badge['condition_value'] ?? 100).toString();
      _xpRewardController.text = (badge['xp_reward'] ?? 50).toString();
      setState(() {
        _conditionType = badge['condition_type'] ?? 'xp_total';
        _conditionParam = badge['condition_param'] as String?;
        _category = badge['category'] ?? 'achievement';
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
    }
  }

  void _generateSlug() {
    final slug = _nameController.text
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s-]'), '')
        .replaceAll(RegExp(r'\s+'), '-');
    _slugController.text = slug;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _slugController.dispose();
    _descriptionController.dispose();
    _iconController.dispose();
    _conditionValueController.dispose();
    _xpRewardController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final supabase = ref.read(supabaseClientProvider);

      final data = {
        'name': _nameController.text.trim(),
        'slug': _slugController.text.trim(),
        'description': _descriptionController.text.trim(),
        'icon': _iconController.text.trim(),
        'category': _category,
        'condition_type': _conditionType,
        'condition_value': _conditionType == 'league_tier_reached'
            ? 1  // placeholder — RPC evaluates league_tier_reached on condition_param only
            : int.tryParse(_conditionValueController.text) ?? 100,
        'condition_param': _conditionParam,
        'xp_reward': int.tryParse(_xpRewardController.text) ?? 50,
      };

      if (isNewBadge) {
        data['id'] = const Uuid().v4();
        await supabase.from(DbTables.badges).insert(data);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Rozet başarıyla oluşturuldu')),
          );
          ref.invalidate(badgesProvider);
          context.go('/badges/${data['id']}');
        }
      } else {
        await supabase.from(DbTables.badges).update(data).eq('id', widget.badgeId!);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Rozet başarıyla kaydedildi')),
          );
          ref.invalidate(badgeDetailProvider(widget.badgeId!));
          ref.invalidate(badgesProvider);
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
        title: const Text('Rozeti Sil'),
        content: const Text(
          'Bu rozeti silmek istediğinizden emin misiniz? '
          'Bu rozeti kazanan kullanıcıların kayıtları korunacaktır. '
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
      await supabase.from(DbTables.badges).delete().eq('id', widget.badgeId!);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Rozet silindi')),
        );
        ref.invalidate(badgesProvider);
        context.go('/badges');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  /// Renders the condition_param dropdown. For monthly_quest_completed we
  /// fetch the quest list from Supabase; for the other param types we use
  /// hard-coded maps from badge_helpers.
  Widget _buildConditionParamField() {
    if (_conditionType == BadgeConditionType.monthlyQuestCompleted.dbValue) {
      final questsAsync = ref.watch(_monthlyQuestsForBadgePickerProvider);
      return questsAsync.when(
        loading: () => const LinearProgressIndicator(),
        error: (e, _) => Text(
          'Quest listesi yüklenemedi: $e',
          style: const TextStyle(color: Colors.red),
        ),
        data: (quests) {
          if (quests.isEmpty) {
            return const Text(
              'Henüz monthly quest tanımlı değil. Önce Quests ekranından oluşturun.',
              style: TextStyle(color: Colors.orange),
            );
          }
          // Ensure current param is a valid id; else null so admin picks one.
          final validIds = quests.map((q) => q['id'] as String).toSet();
          final currentValue =
              (_conditionParam != null && validIds.contains(_conditionParam))
                  ? _conditionParam
                  : null;
          return DropdownButtonFormField<String>(
            value: currentValue,
            decoration: const InputDecoration(
              labelText: 'Monthly Quest',
              helperText: 'Bu rozetin bağlı olduğu aylık görev',
            ),
            items: [
              for (final q in quests)
                DropdownMenuItem(
                  value: q['id'] as String,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text((q['icon'] as String?) ?? '🏆'),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          (q['title'] as String?) ?? '(isimsiz)',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (q['is_active'] == false) ...[
                        const SizedBox(width: 6),
                        Text(
                          '(inactive)',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
            ],
            onChanged: (value) {
              if (value != null) {
                setState(() => _conditionParam = value);
              }
            },
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Quest seçilmelidir';
              }
              return null;
            },
          );
        },
      );
    }

    // Static param types (myth category / league tier)
    final options =
        _conditionType == BadgeConditionType.mythCategoryCompleted.dbValue
            ? mythCategoryOptions
            : leagueTierOptions;
    return DropdownButtonFormField<String>(
      value: _conditionParam,
      decoration: const InputDecoration(
        labelText: 'Parametre',
        helperText: 'Bu koşulun hedeflediği kategori / lig',
      ),
      items: options.entries
          .map((e) => DropdownMenuItem(
                value: e.key,
                child: Text(e.value),
              ),)
          .toList(),
      onChanged: (value) {
        if (value != null) {
          setState(() => _conditionParam = value);
        }
      },
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Parametre zorunludur';
        }
        return null;
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isNewBadge ? 'Yeni Rozet' : 'Rozet Düzenle'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/badges'),
        ),
        actions: [
          if (!isNewBadge)
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
                : Text(isNewBadge ? 'Oluştur' : 'Kaydet'),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Badge form
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
                            'Rozet Bilgileri',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 24),

                          // Icon
                          TextFormField(
                            controller: _iconController,
                            decoration: const InputDecoration(
                              labelText: 'İkon (Emoji)',
                              hintText: '🏆',
                              helperText: 'Bu rozeti temsil edecek bir emoji girin',
                            ),
                            style: const TextStyle(fontSize: 24),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'İkon zorunludur';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          // Name
                          TextFormField(
                            controller: _nameController,
                            decoration: const InputDecoration(
                              labelText: 'Rozet Adı',
                              hintText: 'ör. İlk Adımlar',
                            ),
                            onChanged: (_) => _generateSlug(),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Rozet adı zorunludur';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          // Slug
                          TextFormField(
                            controller: _slugController,
                            decoration: const InputDecoration(
                              labelText: 'Slug',
                              hintText: 'ilk-adimlar',
                              helperText: 'Addan otomatik oluşturulur',
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Slug zorunludur';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          // Description
                          TextFormField(
                            controller: _descriptionController,
                            decoration: const InputDecoration(
                              labelText: 'Açıklama',
                              hintText: 'Bu rozetin neyi temsil ettiğini açıklayın',
                            ),
                            maxLines: 3,
                          ),
                          const SizedBox(height: 16),

                          // Category
                          DropdownButtonFormField<String>(
                            value: _category,
                            decoration: const InputDecoration(
                              labelText: 'Kategori',
                            ),
                            items: _categories.map((cat) {
                              return DropdownMenuItem(
                                value: cat,
                                child: Text(cat[0].toUpperCase() + cat.substring(1)),
                              );
                            }).toList(),
                            onChanged: (value) {
                              if (value != null) {
                                setState(() => _category = value);
                              }
                            },
                          ),
                          const SizedBox(height: 24),

                          Text(
                            'Açma Koşulu',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 16),

                          // Condition type
                          DropdownButtonFormField<String>(
                            value: _conditionType,
                            decoration: const InputDecoration(
                              labelText: 'Koşul Türü',
                            ),
                            items: _conditionTypes.map((type) {
                              return DropdownMenuItem(
                                value: type.$1,
                                child: Text(type.$2),
                              );
                            }).toList(),
                            onChanged: (value) {
                              if (value != null) {
                                setState(() {
                                  _conditionType = value;
                                  final newCt = BadgeConditionType.fromDbValue(value);
                                  if (!newCt.requiresParam) {
                                    _conditionParam = null;
                                  } else if (newCt == BadgeConditionType.mythCategoryCompleted) {
                                    if (_conditionParam == null ||
                                        !mythCategoryOptions.containsKey(_conditionParam)) {
                                      _conditionParam = mythCategoryOptions.keys.first;
                                    }
                                  } else if (newCt == BadgeConditionType.leagueTierReached) {
                                    if (_conditionParam == null ||
                                        !leagueTierOptions.containsKey(_conditionParam)) {
                                      _conditionParam = leagueTierOptions.keys.first;
                                    }
                                  } else if (newCt == BadgeConditionType.monthlyQuestCompleted) {
                                    // Reset param when switching to monthly quest — quest list
                                    // is loaded async and admin must explicitly pick one.
                                    if (_conditionParam != null) {
                                      final quests = ref
                                              .read(_monthlyQuestsForBadgePickerProvider)
                                              .valueOrNull ??
                                          const [];
                                      final found = quests.any(
                                          (q) => q['id'] == _conditionParam,);
                                      if (!found) _conditionParam = null;
                                    }
                                  }
                                });
                              }
                            },
                          ),
                          // Conditional param dropdown (only when condition type needs it)
                          if (BadgeConditionType.fromDbValue(_conditionType).requiresParam) ...[
                            const SizedBox(height: 16),
                            _buildConditionParamField(),
                          ],

                          const SizedBox(height: 16),

                          // Condition value (hidden for league_tier_reached — RPC ignores it)
                          if (_conditionType != 'league_tier_reached')
                            TextFormField(
                              controller: _conditionValueController,
                              decoration: InputDecoration(
                                labelText: 'Koşul Değeri',
                                hintText: 'ör. 100',
                                helperText: getConditionHelper(_conditionType),
                              ),
                              keyboardType: TextInputType.number,
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Koşul değeri zorunludur';
                                }
                                if (int.tryParse(value) == null) {
                                  return 'Sayı olmalıdır';
                                }
                                return null;
                              },
                            ),
                          const SizedBox(height: 24),

                          Text(
                            'Ödül',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 16),

                          // XP reward
                          TextFormField(
                            controller: _xpRewardController,
                            decoration: const InputDecoration(
                              labelText: 'XP Ödülü',
                              hintText: 'ör. 50',
                              helperText: 'Rozet kazanıldığında verilen XP',
                            ),
                            keyboardType: TextInputType.number,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'XP ödülü zorunludur';
                              }
                              if (int.tryParse(value) == null) {
                                return 'Sayı olmalıdır';
                              }
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Preview
                Expanded(
                  flex: 1,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      border: Border(
                        left: BorderSide(color: Colors.grey.shade200),
                      ),
                    ),
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Önizleme',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 16),
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              children: [
                                Container(
                                  width: 80,
                                  height: 80,
                                  decoration: BoxDecoration(
                                    color: Colors.amber.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Center(
                                    child: Text(
                                      _iconController.text.isEmpty
                                          ? '🏆'
                                          : _iconController.text,
                                      style: const TextStyle(fontSize: 40),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  _nameController.text.isEmpty
                                      ? 'Rozet Adı'
                                      : _nameController.text,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _descriptionController.text.isEmpty
                                      ? 'Rozet açıklaması'
                                      : _descriptionController.text,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey.shade600,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 16),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.purple.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '+${_xpRewardController.text.isEmpty ? '50' : _xpRewardController.text} XP',
                                    style: const TextStyle(
                                      color: Colors.purple,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (!isNewBadge) ...[
                          const SizedBox(height: 24),
                          const Divider(),
                          const SizedBox(height: 16),
                          _EarnedBySection(badgeId: widget.badgeId!),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

}

class _EarnedBySection extends ConsumerWidget {
  const _EarnedBySection({required this.badgeId});

  final String badgeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final earnedByAsync = ref.watch(badgeEarnedByProvider(badgeId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        earnedByAsync.when(
          data: (students) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Kazanan Öğrenciler (${students.length})',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                if (students.isEmpty)
                  Text(
                    'Henüz kimse kazanmadı',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade500,
                      fontStyle: FontStyle.italic,
                    ),
                  )
                else
                  ...students.map((entry) {
                    final profile =
                        entry['profiles'] as Map<String, dynamic>? ?? {};
                    final firstName = profile['first_name'] as String? ?? '';
                    final lastName = profile['last_name'] as String? ?? '';
                    final name = '$firstName $lastName'.trim();
                    final earnedAt = entry['earned_at'] as String? ?? '';
                    final date = earnedAt.isNotEmpty
                        ? DateTime.tryParse(earnedAt)
                        : null;
                    final dateStr = date != null
                        ? '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}'
                        : '';

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 14,
                            backgroundColor: Colors.blue.shade50,
                            child: Text(
                              name.isNotEmpty ? name[0].toUpperCase() : '?',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.blue.shade700,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              name.isNotEmpty ? name : 'Bilinmeyen',
                              style: const TextStyle(fontSize: 13),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            dateStr,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
              ],
            );
          },
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
          error: (error, _) => Text(
            'Hata: $error',
            style: const TextStyle(color: Colors.red, fontSize: 12),
          ),
        ),
      ],
    );
  }
}
