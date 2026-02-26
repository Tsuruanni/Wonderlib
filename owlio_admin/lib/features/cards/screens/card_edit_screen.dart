import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:owlio_shared/owlio_shared.dart';
import 'package:uuid/uuid.dart';

import '../../../core/supabase_client.dart';
import 'card_list_screen.dart';

/// Provider for loading a single card
final cardDetailProvider =
    FutureProvider.family<Map<String, dynamic>?, String>((ref, cardId) async {
  final supabase = ref.watch(supabaseClientProvider);
  final response = await supabase
      .from(DbTables.mythCards)
      .select()
      .eq('id', cardId)
      .maybeSingle();
  return response;
});

class CardEditScreen extends ConsumerStatefulWidget {
  const CardEditScreen({super.key, this.cardId});

  final String? cardId;

  @override
  ConsumerState<CardEditScreen> createState() => _CardEditScreenState();
}

class _CardEditScreenState extends ConsumerState<CardEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _cardNoController = TextEditingController();
  final _nameController = TextEditingController();
  final _powerController = TextEditingController();
  final _specialSkillController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _categoryIconController = TextEditingController();

  CardCategory _category = CardCategory.turkishMyths;
  CardRarity _rarity = CardRarity.common;
  bool _isActive = true;
  bool _isLoading = false;
  bool _isSaving = false;

  bool get isNewCard => widget.cardId == null;

  @override
  void initState() {
    super.initState();
    if (!isNewCard) {
      _loadCard();
    } else {
      _powerController.text = '10';
      _categoryIconController.text = '🐺';
      _autoGenerateCardNo();
    }
  }

  Future<void> _autoGenerateCardNo() async {
    try {
      final supabase = ref.read(supabaseClientProvider);
      final result = await supabase
          .from(DbTables.mythCards)
          .select('card_no')
          .order('card_no', ascending: false)
          .limit(1);

      if (result.isNotEmpty) {
        final lastNo = result[0]['card_no'] as String;
        final num = int.tryParse(lastNo.replaceAll('M-', '')) ?? 0;
        _cardNoController.text = 'M-${(num + 1).toString().padLeft(3, '0')}';
      } else {
        _cardNoController.text = 'M-001';
      }
    } catch (_) {
      _cardNoController.text = 'M-001';
    }
  }

  Future<void> _loadCard() async {
    setState(() => _isLoading = true);

    final card = await ref.read(cardDetailProvider(widget.cardId!).future);
    if (card != null && mounted) {
      _cardNoController.text = card['card_no'] ?? '';
      _nameController.text = card['name'] ?? '';
      _powerController.text = (card['power'] ?? 10).toString();
      _specialSkillController.text = card['special_skill'] ?? '';
      _descriptionController.text = card['description'] ?? '';
      _categoryIconController.text = card['category_icon'] ?? '';
      setState(() {
        _category =
            CardCategory.fromDbValue(card['category'] as String? ?? '');
        _rarity = CardRarity.fromDbValue(card['rarity'] as String? ?? '');
        _isActive = card['is_active'] as bool? ?? true;
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _cardNoController.dispose();
    _nameController.dispose();
    _powerController.dispose();
    _specialSkillController.dispose();
    _descriptionController.dispose();
    _categoryIconController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final supabase = ref.read(supabaseClientProvider);

      final data = {
        'card_no': _cardNoController.text.trim(),
        'name': _nameController.text.trim(),
        'category': _category.dbValue,
        'rarity': _rarity.dbValue,
        'power': int.tryParse(_powerController.text) ?? 10,
        'special_skill': _specialSkillController.text.trim().isEmpty
            ? null
            : _specialSkillController.text.trim(),
        'description': _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        'category_icon': _categoryIconController.text.trim().isEmpty
            ? null
            : _categoryIconController.text.trim(),
        'is_active': _isActive,
      };

      if (isNewCard) {
        data['id'] = const Uuid().v4();
        await supabase.from(DbTables.mythCards).insert(data);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Card created successfully')),
          );
          ref.invalidate(mythCardsProvider);
          context.go('/cards/${data['id']}');
        }
      } else {
        await supabase
            .from(DbTables.mythCards)
            .update(data)
            .eq('id', widget.cardId!);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Card saved successfully')),
          );
          ref.invalidate(cardDetailProvider(widget.cardId!));
          ref.invalidate(mythCardsProvider);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
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
        title: const Text('Delete Card'),
        content: const Text(
          'Are you sure you want to delete this card? '
          'Users who own this card will lose it. '
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
      await supabase
          .from(DbTables.mythCards)
          .delete()
          .eq('id', widget.cardId!);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Card deleted')),
        );
        ref.invalidate(mythCardsProvider);
        context.go('/cards');
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
        title: Text(isNewCard ? 'New Card' : 'Edit Card'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/cards'),
        ),
        actions: [
          if (!isNewCard)
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
                : Text(isNewCard ? 'Create' : 'Save'),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Form
                Expanded(
                  flex: 2,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Card Details',
                              style: Theme.of(context).textTheme.titleLarge),
                          const SizedBox(height: 24),

                          // Card No
                          TextFormField(
                            controller: _cardNoController,
                            decoration: const InputDecoration(
                              labelText: 'Card Number',
                              hintText: 'M-001',
                              helperText: 'Format: M-XXX',
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Card number is required';
                              }
                              if (!RegExp(r'^M-\d{3}$').hasMatch(value.trim())) {
                                return 'Must be in format M-XXX (e.g., M-001)';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          // Name
                          TextFormField(
                            controller: _nameController,
                            decoration: const InputDecoration(
                              labelText: 'Card Name',
                              hintText: 'e.g., Fenrir the Wolf',
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Name is required';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          // Category
                          DropdownButtonFormField<CardCategory>(
                            value: _category,
                            decoration: const InputDecoration(
                              labelText: 'Category',
                            ),
                            items: CardCategory.values.map((cat) {
                              return DropdownMenuItem(
                                value: cat,
                                child: Text(cat.label),
                              );
                            }).toList(),
                            onChanged: (value) {
                              if (value != null) {
                                setState(() => _category = value);
                              }
                            },
                          ),
                          const SizedBox(height: 16),

                          // Rarity
                          DropdownButtonFormField<CardRarity>(
                            value: _rarity,
                            decoration: const InputDecoration(
                              labelText: 'Rarity',
                            ),
                            items: CardRarity.values.map((r) {
                              return DropdownMenuItem(
                                value: r,
                                child: Row(
                                  children: [
                                    Container(
                                      width: 12,
                                      height: 12,
                                      decoration: BoxDecoration(
                                        color: _rarityColor(r),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(r.label),
                                  ],
                                ),
                              );
                            }).toList(),
                            onChanged: (value) {
                              if (value != null) {
                                setState(() => _rarity = value);
                              }
                            },
                          ),
                          const SizedBox(height: 16),

                          // Power
                          TextFormField(
                            controller: _powerController,
                            decoration: const InputDecoration(
                              labelText: 'Power',
                              hintText: '10',
                              helperText: 'Card power rating',
                            ),
                            keyboardType: TextInputType.number,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Power is required';
                              }
                              if (int.tryParse(value) == null) {
                                return 'Must be a number';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          // Category Icon
                          TextFormField(
                            controller: _categoryIconController,
                            decoration: const InputDecoration(
                              labelText: 'Category Icon (Emoji)',
                              hintText: '🐺',
                            ),
                            style: const TextStyle(fontSize: 24),
                          ),
                          const SizedBox(height: 16),

                          // Special Skill
                          TextFormField(
                            controller: _specialSkillController,
                            decoration: const InputDecoration(
                              labelText: 'Special Skill',
                              hintText: 'e.g., Shadow Strike',
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Description
                          TextFormField(
                            controller: _descriptionController,
                            decoration: const InputDecoration(
                              labelText: 'Description',
                              hintText: 'Card lore and description',
                            ),
                            maxLines: 4,
                          ),
                          const SizedBox(height: 16),

                          // Is Active
                          SwitchListTile(
                            title: const Text('Active'),
                            subtitle: const Text(
                                'Inactive cards are hidden from students'),
                            value: _isActive,
                            onChanged: (value) {
                              setState(() => _isActive = value);
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
                        Text('Preview',
                            style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 16),
                        Center(
                          child: SizedBox(
                            width: 200,
                            child: Card(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(
                                  color: _rarityColor(_rarity),
                                  width: 3,
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  children: [
                                    // Card No
                                    Text(
                                      _cardNoController.text.isEmpty
                                          ? 'M-XXX'
                                          : _cardNoController.text,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey.shade500,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    // Icon
                                    Container(
                                      width: 64,
                                      height: 64,
                                      decoration: BoxDecoration(
                                        color: _rarityColor(_rarity)
                                            .withValues(alpha: 0.1),
                                        borderRadius:
                                            BorderRadius.circular(12),
                                      ),
                                      child: Center(
                                        child: Text(
                                          _categoryIconController
                                                  .text.isEmpty
                                              ? '🃏'
                                              : _categoryIconController.text,
                                          style:
                                              const TextStyle(fontSize: 32),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    // Name
                                    Text(
                                      _nameController.text.isEmpty
                                          ? 'Card Name'
                                          : _nameController.text,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _category.label,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    // Rarity + Power
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 3,
                                          ),
                                          decoration: BoxDecoration(
                                            color: _rarityColor(_rarity)
                                                .withValues(alpha: 0.15),
                                            borderRadius:
                                                BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            _rarity.label,
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: _rarityColor(_rarity),
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Icon(Icons.bolt,
                                            size: 14,
                                            color: Colors.amber.shade700),
                                        Text(
                                          _powerController.text.isEmpty
                                              ? '10'
                                              : _powerController.text,
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.amber.shade700,
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (_specialSkillController
                                        .text.isNotEmpty) ...[
                                      const SizedBox(height: 8),
                                      Text(
                                        _specialSkillController.text,
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontStyle: FontStyle.italic,
                                          color: Colors.grey.shade600,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
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

  static Color _rarityColor(CardRarity rarity) {
    switch (rarity) {
      case CardRarity.common:
        return Colors.grey.shade400;
      case CardRarity.rare:
        return Colors.blue.shade400;
      case CardRarity.epic:
        return Colors.purple.shade400;
      case CardRarity.legendary:
        return Colors.amber.shade600;
    }
  }
}
