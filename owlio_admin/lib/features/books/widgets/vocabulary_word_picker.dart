import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:owlio_shared/owlio_shared.dart';
import 'package:uuid/uuid.dart';

import '../../../core/supabase_client.dart';

/// A reusable autocomplete widget for selecting vocabulary words.
///
/// Searches [vocabulary_words] by word text (debounced), shows matching words
/// in a dropdown with word + meaning_tr, and allows inline creation of new words
/// when no match is found.
class VocabularyWordPicker extends ConsumerStatefulWidget {
  const VocabularyWordPicker({
    super.key,
    required this.selectedWordIds,
    required this.onChanged,
  });

  /// Current list of selected vocabulary word UUIDs.
  final List<String> selectedWordIds;

  /// Called when selection changes (add or remove).
  final ValueChanged<List<String>> onChanged;

  @override
  ConsumerState<VocabularyWordPicker> createState() =>
      _VocabularyWordPickerState();
}

class _VocabularyWordPickerState extends ConsumerState<VocabularyWordPicker> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  List<Map<String, dynamic>> _searchResults = [];
  List<Map<String, dynamic>> _selectedWords = [];
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _loadSelectedWordDetails(widget.selectedWordIds);
  }

  @override
  void didUpdateWidget(covariant VocabularyWordPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    final newIds = widget.selectedWordIds
        .where((id) => !_selectedWords.any((w) => w['id'] == id))
        .toList();
    if (newIds.isNotEmpty) {
      _loadSelectedWordDetails(newIds);
    }
    // Remove words no longer in selectedWordIds
    final updated =
        _selectedWords.where((w) => widget.selectedWordIds.contains(w['id'])).toList();
    if (updated.length != _selectedWords.length) {
      setState(() => _selectedWords = updated);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _loadSelectedWordDetails(List<String> ids) async {
    if (ids.isEmpty) return;
    final supabase = ref.read(supabaseClientProvider);
    final response = await supabase
        .from(DbTables.vocabularyWords)
        .select('id, word, meaning_tr')
        .inFilter('id', ids);
    final rows = List<Map<String, dynamic>>.from(response);
    if (mounted) {
      setState(() {
        for (final row in rows) {
          if (!_selectedWords.any((w) => w['id'] == row['id'])) {
            _selectedWords.add(row);
          }
        }
      });
    }
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 300), () => _searchWords(query));
  }

  Future<void> _searchWords(String query) async {
    if (!mounted) return;
    setState(() => _isSearching = true);
    try {
      final supabase = ref.read(supabaseClientProvider);
      final response = await supabase
          .from(DbTables.vocabularyWords)
          .select('id, word, meaning_tr')
          .ilike('word', '%$query%')
          .limit(10);
      final rows = List<Map<String, dynamic>>.from(response);
      // Exclude already-selected words
      final filtered =
          rows.where((r) => !widget.selectedWordIds.contains(r['id'])).toList();
      if (mounted) {
        setState(() {
          _searchResults = filtered;
          _isSearching = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  void _selectWord(Map<String, dynamic> word) {
    final newIds = [...widget.selectedWordIds, word['id'] as String];
    setState(() {
      if (!_selectedWords.any((w) => w['id'] == word['id'])) {
        _selectedWords.add(word);
      }
      _searchResults = [];
      _searchController.clear();
    });
    widget.onChanged(newIds);
  }

  void _removeWord(String wordId) {
    final newIds = widget.selectedWordIds.where((id) => id != wordId).toList();
    setState(() => _selectedWords.removeWhere((w) => w['id'] == wordId));
    widget.onChanged(newIds);
  }

  Future<void> _showAddWordDialog() async {
    final searchText = _searchController.text.trim();
    final wordController = TextEditingController(text: searchText);
    final meaningController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Vocabulary Word'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: wordController,
                decoration: const InputDecoration(
                  labelText: 'Word',
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
                autofocus: searchText.isEmpty,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: meaningController,
                decoration: const InputDecoration(
                  labelText: 'Meaning (TR)',
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
                autofocus: searchText.isNotEmpty,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState?.validate() ?? false) {
                Navigator.pop(ctx, {
                  'word': wordController.text.trim(),
                  'meaning_tr': meaningController.text.trim(),
                });
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );

    wordController.dispose();
    meaningController.dispose();

    if (result == null || !mounted) return;

    final wordText = result['word']!;
    final meaningTr = result['meaning_tr']!;

    try {
      final supabase = ref.read(supabaseClientProvider);

      // Check if word+meaning_tr already exists (unique index is LOWER(word), meaning_tr)
      final existing = await supabase
          .from(DbTables.vocabularyWords)
          .select('id, word, meaning_tr')
          .eq('word', wordText)
          .eq('meaning_tr', meaningTr)
          .maybeSingle();

      if (existing != null) {
        _selectWord(Map<String, dynamic>.from(existing));
        return;
      }

      // Insert new word with source: 'activity'
      const uuid = Uuid();
      final newId = uuid.v4();
      await supabase.from(DbTables.vocabularyWords).insert({
        'id': newId,
        'word': wordText,
        'meaning_tr': meaningTr,
        'source': 'activity',
      });

      _selectWord({'id': newId, 'word': wordText, 'meaning_tr': meaningTr});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add word: $e')),
        );
      }
    }
  }

  bool get _showDropdown =>
      _searchController.text.trim().isNotEmpty &&
      (_searchResults.isNotEmpty || (!_isSearching));

  @override
  Widget build(BuildContext context) {
    final searchText = _searchController.text.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Vocabulary Words',
          style: TextStyle(fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Search vocabulary words...',
            border: const OutlineInputBorder(),
            isDense: true,
            suffixIcon: _isSearching
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : null,
          ),
          onChanged: _onSearchChanged,
        ),
        if (_showDropdown)
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(4),
              ),
              color: Theme.of(context).colorScheme.surface,
            ),
            constraints: const BoxConstraints(maxHeight: 200),
            child: ListView(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              children: [
                ..._searchResults.map(
                  (word) => ListTile(
                    dense: true,
                    title: Text(word['word'] as String),
                    subtitle: Text(
                      word['meaning_tr'] as String,
                      style: const TextStyle(fontSize: 12),
                    ),
                    onTap: () => _selectWord(word),
                  ),
                ),
                if (searchText.isNotEmpty)
                  ListTile(
                    dense: true,
                    leading: const Icon(Icons.add, size: 18),
                    title: Text('Add "$searchText"'),
                    onTap: _showAddWordDialog,
                  ),
              ],
            ),
          ),
        if (_selectedWords.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _selectedWords.map((word) {
              return Chip(
                label: Text(
                  '${word['word']} — ${word['meaning_tr']}',
                  style: const TextStyle(fontSize: 12),
                ),
                onDeleted: () => _removeWord(word['id'] as String),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              );
            }).toList(),
          ),
        ],
      ],
    );
  }
}
