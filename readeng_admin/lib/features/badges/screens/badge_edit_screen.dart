import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:readeng_shared/readeng_shared.dart';
import 'package:uuid/uuid.dart';

import '../../../core/supabase_client.dart';
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
    (BadgeConditionType.xpTotal.dbValue, 'Total XP Earned'),
    (BadgeConditionType.streakDays.dbValue, 'Consecutive Days Active'),
    (BadgeConditionType.booksCompleted.dbValue, 'Books Completed'),
    (BadgeConditionType.vocabularyLearned.dbValue, 'Words Learned'),
    (BadgeConditionType.perfectScores.dbValue, 'Perfect Activity Scores'),
  ];

  static const _categories = ['achievement', 'streak', 'reading', 'vocabulary', 'special'];

  String _conditionType = BadgeConditionType.xpTotal.dbValue;
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
        'condition_value': int.tryParse(_conditionValueController.text) ?? 100,
        'xp_reward': int.tryParse(_xpRewardController.text) ?? 50,
      };

      if (isNewBadge) {
        data['id'] = const Uuid().v4();
        await supabase.from(DbTables.badges).insert(data);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Badge created successfully')),
          );
          ref.invalidate(badgesProvider);
          context.go('/badges/${data['id']}');
        }
      } else {
        await supabase.from(DbTables.badges).update(data).eq('id', widget.badgeId!);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Badge saved successfully')),
          );
          ref.invalidate(badgeDetailProvider(widget.badgeId!));
          ref.invalidate(badgesProvider);
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
        title: const Text('Delete Badge'),
        content: const Text(
          'Are you sure you want to delete this badge? '
          'Users who earned this badge will keep their records. '
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
      await supabase.from(DbTables.badges).delete().eq('id', widget.badgeId!);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Badge deleted')),
        );
        ref.invalidate(badgesProvider);
        context.go('/badges');
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
        title: Text(isNewBadge ? 'New Badge' : 'Edit Badge'),
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
                : Text(isNewBadge ? 'Create' : 'Save'),
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
                            'Badge Details',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 24),

                          // Icon
                          TextFormField(
                            controller: _iconController,
                            decoration: const InputDecoration(
                              labelText: 'Icon (Emoji)',
                              hintText: '🏆',
                              helperText: 'Enter an emoji to represent this badge',
                            ),
                            style: const TextStyle(fontSize: 24),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Icon is required';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          // Name
                          TextFormField(
                            controller: _nameController,
                            decoration: const InputDecoration(
                              labelText: 'Badge Name',
                              hintText: 'e.g., First Steps',
                            ),
                            onChanged: (_) => _generateSlug(),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Badge name is required';
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
                              hintText: 'first-steps',
                              helperText: 'Auto-generated from name',
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Slug is required';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          // Description
                          TextFormField(
                            controller: _descriptionController,
                            decoration: const InputDecoration(
                              labelText: 'Description',
                              hintText: 'Describe what this badge represents',
                            ),
                            maxLines: 3,
                          ),
                          const SizedBox(height: 16),

                          // Category
                          DropdownButtonFormField<String>(
                            value: _category,
                            decoration: const InputDecoration(
                              labelText: 'Category',
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
                            'Unlock Condition',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 16),

                          // Condition type
                          DropdownButtonFormField<String>(
                            value: _conditionType,
                            decoration: const InputDecoration(
                              labelText: 'Condition Type',
                            ),
                            items: _conditionTypes.map((type) {
                              return DropdownMenuItem(
                                value: type.$1,
                                child: Text(type.$2),
                              );
                            }).toList(),
                            onChanged: (value) {
                              if (value != null) {
                                setState(() => _conditionType = value);
                              }
                            },
                          ),
                          const SizedBox(height: 16),

                          // Condition value
                          TextFormField(
                            controller: _conditionValueController,
                            decoration: InputDecoration(
                              labelText: 'Condition Value',
                              hintText: 'e.g., 100',
                              helperText: _getConditionHelper(_conditionType),
                            ),
                            keyboardType: TextInputType.number,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Condition value is required';
                              }
                              if (int.tryParse(value) == null) {
                                return 'Must be a number';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 24),

                          Text(
                            'Reward',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 16),

                          // XP reward
                          TextFormField(
                            controller: _xpRewardController,
                            decoration: const InputDecoration(
                              labelText: 'XP Reward',
                              hintText: 'e.g., 50',
                              helperText: 'XP awarded when badge is earned',
                            ),
                            keyboardType: TextInputType.number,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'XP reward is required';
                              }
                              if (int.tryParse(value) == null) {
                                return 'Must be a number';
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
                          'Preview',
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
                                      ? 'Badge Name'
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
                                      ? 'Badge description'
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
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  String _getConditionHelper(String type) {
    switch (type) {
      case 'xp_total':
        return 'Total XP user must earn';
      case 'streak_days':
        return 'Consecutive days of activity';
      case 'books_completed':
        return 'Number of books to complete';
      case 'vocabulary_learned':
        return 'Number of words to learn';
      case 'perfect_scores':
        return 'Perfect scores on activities';
      default:
        return '';
    }
  }
}
