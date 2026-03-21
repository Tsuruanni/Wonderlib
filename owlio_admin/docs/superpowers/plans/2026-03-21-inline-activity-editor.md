# Inline Activity Editor — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Enable full CRUD for inline activities within the admin panel's content block editor, with vocabulary word autocomplete and inline creation.

**Architecture:** Split the activity editor into two new widget files (`activity_editor.dart` for the form logic/UI, `vocabulary_word_picker.dart` for the reusable autocomplete component) to keep `content_block_editor.dart` manageable. The content block editor orchestrates block creation/deletion and delegates activity editing to the new widget. A single DB migration adds the `source` column.

**Tech Stack:** Flutter, Riverpod, Supabase (PostgREST), owlio_shared enums

**Spec:** `docs/superpowers/specs/2026-03-21-inline-activity-editor-design.md`

---

## File Structure

| File | Action | Responsibility |
|------|--------|----------------|
| `supabase/migrations/20260321000002_add_vocabulary_source.sql` | Create | Add `source` column to `vocabulary_words` |
| `lib/features/books/widgets/vocabulary_word_picker.dart` | Create | Autocomplete search + inline word creation widget |
| `lib/features/books/widgets/activity_editor.dart` | Create | Activity type forms, validation, save/edit logic |
| `lib/features/books/widgets/content_block_editor.dart` | Modify | Wire up activity editor, expand Add Block menu, update delete flow |
| `lib/features/vocabulary/screens/vocabulary_list_screen.dart` | Modify | Source badge, default sort by created_at DESC |
| `lib/features/vocabulary/screens/vocabulary_edit_screen.dart` | Modify | Display source field (read-only) |
| `lib/features/vocabulary/screens/vocabulary_import_screen.dart` | Modify | Write `source: 'import'` on new inserts |

---

## Task 1: Database Migration — `source` Column

**Files:**
- Create: `supabase/migrations/20260321000002_add_vocabulary_source.sql`

- [ ] **Step 1: Create migration file**

```sql
-- Add source tracking for vocabulary words
ALTER TABLE vocabulary_words
ADD COLUMN source VARCHAR(20) DEFAULT 'manual';

COMMENT ON COLUMN vocabulary_words.source IS 'Origin of the word: manual, import, activity';
```

- [ ] **Step 2: Preview migration**

Run: `cd /Users/wonderelt/Desktop/Owlio && supabase db push --dry-run`
Expected: Shows the new migration as pending

- [ ] **Step 3: Apply migration**

Run: `cd /Users/wonderelt/Desktop/Owlio && supabase db push`
Expected: Migration applied successfully

- [ ] **Step 4: Commit**

```bash
git add supabase/migrations/20260321000002_add_vocabulary_source.sql
git commit -m "feat(db): add source column to vocabulary_words"
```

---

## Task 2: Vocabulary Word Picker Widget

**Files:**
- Create: `lib/features/books/widgets/vocabulary_word_picker.dart`

This is a reusable autocomplete widget that:
- Searches `vocabulary_words` table by word text (debounced)
- Shows matching words in a dropdown with word + meaning_tr
- Allows selecting existing words (returns UUID)
- Shows "Add [word]" option when no match — opens mini-dialog for word + meaning_tr
- Creates minimal `vocabulary_words` row with `source: 'activity'`
- Handles duplicate detection (same word+meaning_tr → return existing UUID)
- Displays selected words as removable chips

- [ ] **Step 1: Create the vocabulary_word_picker.dart file**

The widget should be a `ConsumerStatefulWidget` with this API:

```dart
class VocabularyWordPicker extends ConsumerStatefulWidget {
  const VocabularyWordPicker({
    super.key,
    required this.selectedWordIds,
    required this.onChanged,
  });

  /// Current list of selected vocabulary word UUIDs
  final List<String> selectedWordIds;

  /// Called when selection changes (add or remove)
  final ValueChanged<List<String>> onChanged;
}
```

Internal state:
- `_searchController` — TextEditingController for the search input
- `_searchResults` — List<Map<String, dynamic>> from search query
- `_selectedWords` — List<Map<String, dynamic>> with `id`, `word`, `meaning_tr` for displaying chips
- `_isSearching` — bool loading state

Key methods:
- `_searchWords(String query)` — debounced search against `vocabulary_words` table using `.ilike('word', '%$query%').limit(10)`. Exclude already-selected UUIDs.
- `_selectWord(Map<String, dynamic> word)` — add UUID to list, call `onChanged`, clear search
- `_removeWord(String wordId)` — remove from list, call `onChanged`
- `_showAddWordDialog()` — dialog with two fields: Word (pre-filled from search text) + Meaning TR (required). On confirm: check if word+meaning_tr exists first (`.eq('word', word).eq('meaning_tr', meaningTr).maybeSingle()`), if exists return its UUID, else INSERT with `source: 'activity'` and return new UUID.
- `initState` / `didUpdateWidget` — load word details for `selectedWordIds` that aren't yet in `_selectedWords`

Build structure:
```
Column(
  children: [
    // Search input with dropdown overlay
    TextField(...) + dropdown results
    // Selected words as chips
    Wrap(children: selectedWords.map((w) => Chip(...)))
  ]
)
```

For the dropdown: Use a `Column` below the `TextField` (not `OverlayEntry` — simpler, this is an admin panel). Show results only when `_searchResults.isNotEmpty` or when search text doesn't match any result (show "Add [word]" option).

- [ ] **Step 2: Verify it compiles**

Run: `cd /Users/wonderelt/Desktop/Owlio/owlio_admin && dart analyze lib/features/books/widgets/vocabulary_word_picker.dart`
Expected: No errors

- [ ] **Step 3: Commit**

```bash
git add lib/features/books/widgets/vocabulary_word_picker.dart
git commit -m "feat: add vocabulary word picker widget with autocomplete and inline creation"
```

---

## Task 3: Activity Editor Widget

**Files:**
- Create: `lib/features/books/widgets/activity_editor.dart`

This widget renders the correct form for a given activity type, handles validation, and persists to `inline_activities` + updates `content_blocks.activity_id`.

- [ ] **Step 1: Create activity_editor.dart with the widget API and type dispatch**

Widget API:

```dart
class ActivityEditor extends ConsumerStatefulWidget {
  const ActivityEditor({
    super.key,
    required this.chapterId,
    required this.blockId,
    required this.activityType,
    this.existingActivity,
    required this.onSaved,
    required this.onCancel,
  });

  final String chapterId;
  final String blockId;
  /// The InlineActivityType dbValue string: 'true_false', 'word_translation', 'find_words', 'matching'
  final String activityType;
  /// If editing, the existing inline_activities row
  final Map<String, dynamic>? existingActivity;
  final VoidCallback onSaved;
  final VoidCallback onCancel;
}
```

State fields (all forms share common state pattern):
```dart
bool _isSaving = false;
String? _error; // Form-level error message

// True/False
final _statementController = TextEditingController();
bool _correctAnswer = true;

// Word Translation
final _wordController = TextEditingController();
final _translationController = TextEditingController();
List<String> _options = []; // option strings
final _optionInputController = TextEditingController();

// Find Words
final _instructionController = TextEditingController(); // shared with Matching
List<String> _fwOptions = [];
Set<String> _fwCorrectAnswers = {};
final _fwOptionInputController = TextEditingController();

// Matching
List<Map<String, String>> _pairs = []; // [{left: '', right: ''}]

// Vocabulary words (shared across word_translation, find_words, matching)
List<String> _vocabularyWordIds = [];
```

In `initState`, if `existingActivity != null`, parse `content` JSONB and populate the form fields:
```dart
final content = existingActivity!['content'] as Map<String, dynamic>;
switch (activityType) {
  case 'true_false':
    _statementController.text = content['statement'] ?? '';
    _correctAnswer = content['correct_answer'] ?? true;
  case 'word_translation':
    _wordController.text = content['word'] ?? '';
    _translationController.text = content['correct_answer'] ?? '';
    _options = List<String>.from(content['options'] ?? []);
  case 'find_words':
    _instructionController.text = content['instruction'] ?? '';
    _fwOptions = List<String>.from(content['options'] ?? []);
    _fwCorrectAnswers = Set<String>.from(content['correct_answers'] ?? []);
  case 'matching':
    _instructionController.text = content['instruction'] ?? '';
    _pairs = (content['pairs'] as List<dynamic>? ?? [])
        .map((p) => {'left': p['left'] as String? ?? '', 'right': p['right'] as String? ?? ''})
        .toList();
}
_vocabularyWordIds = List<String>.from(
  (existingActivity!['vocabulary_words'] as List<dynamic>?)?.map((e) => e.toString()) ?? [],
);
```

The `build` method dispatches to a private builder per type:
```dart
Widget build(BuildContext context, WidgetRef ref) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      // Form fields per type
      switch (widget.activityType) {
        'true_false' => _buildTrueFalseForm(),
        'word_translation' => _buildWordTranslationForm(ref),
        'find_words' => _buildFindWordsForm(ref),
        'matching' => _buildMatchingForm(ref),
        _ => Text('Unknown type: ${widget.activityType}'),
      },

      // Error display
      if (_error != null)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(_error!, style: const TextStyle(color: Colors.red)),
        ),

      // Save / Cancel buttons
      const SizedBox(height: 16),
      Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(onPressed: widget.onCancel, child: const Text('İptal')),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: _isSaving ? null : _handleSave,
            child: _isSaving
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Kaydet'),
          ),
        ],
      ),
    ],
  );
}
```

- [ ] **Step 2: Implement the four form builders**

Each builder returns a `Widget` (typically a `Column`).

**`_buildTrueFalseForm()`:**
```dart
Column(children: [
  TextField(controller: _statementController, maxLines: 3,
    decoration: InputDecoration(labelText: 'Statement', hintText: 'Enter a true/false statement...', border: OutlineInputBorder())),
  SizedBox(height: 12),
  Row(children: [
    Text('Correct Answer:', style: TextStyle(fontWeight: FontWeight.w500)),
    SizedBox(width: 12),
    SegmentedButton<bool>(
      segments: [ButtonSegment(value: true, label: Text('True')), ButtonSegment(value: false, label: Text('False'))],
      selected: {_correctAnswer},
      onSelectionChanged: (v) => setState(() => _correctAnswer = v.first),
    ),
  ]),
])
```

**`_buildWordTranslationForm(WidgetRef ref)`:**
```dart
Column(children: [
  TextField(controller: _wordController, decoration: InputDecoration(labelText: 'Word', border: OutlineInputBorder())),
  SizedBox(height: 12),
  TextField(controller: _translationController, decoration: InputDecoration(labelText: 'Correct Answer (Translation)', border: OutlineInputBorder())),
  SizedBox(height: 12),
  // Options chip list
  Text('Options (min 2, correct answer auto-included):', style: TextStyle(fontWeight: FontWeight.w500)),
  SizedBox(height: 8),
  Wrap(spacing: 8, runSpacing: 4, children: [
    ..._options.map((opt) => Chip(label: Text(opt), deleteIcon: Icon(Icons.close, size: 16),
      onDeleted: () => setState(() => _options.remove(opt)))),
  ]),
  SizedBox(height: 8),
  Row(children: [
    Expanded(child: TextField(controller: _optionInputController, decoration: InputDecoration(hintText: 'Add option...', border: OutlineInputBorder(), isDense: true))),
    SizedBox(width: 8),
    IconButton(icon: Icon(Icons.add_circle), onPressed: _addOption),
  ]),
  SizedBox(height: 16),
  VocabularyWordPicker(selectedWordIds: _vocabularyWordIds, onChanged: (ids) => setState(() => _vocabularyWordIds = ids)),
])
```

`_addOption()`:
```dart
void _addOption() {
  final text = _optionInputController.text.trim();
  if (text.isEmpty || _options.contains(text)) return;
  setState(() => _options.add(text));
  _optionInputController.clear();
}
```

**`_buildFindWordsForm(WidgetRef ref)`:**
```dart
Column(children: [
  TextField(controller: _instructionController, maxLines: 2,
    decoration: InputDecoration(labelText: 'Instruction', hintText: 'e.g. Find all the adjectives...', border: OutlineInputBorder())),
  SizedBox(height: 12),
  Text('Options (tap to mark as correct answer):', style: TextStyle(fontWeight: FontWeight.w500)),
  SizedBox(height: 8),
  Wrap(spacing: 8, runSpacing: 4, children: [
    ..._fwOptions.map((opt) {
      final isCorrect = _fwCorrectAnswers.contains(opt);
      return FilterChip(
        label: Text(opt),
        selected: isCorrect,
        onSelected: (selected) => setState(() {
          if (selected) _fwCorrectAnswers.add(opt); else _fwCorrectAnswers.remove(opt);
        }),
        deleteIcon: Icon(Icons.close, size: 16),
        onDeleted: () => setState(() { _fwOptions.remove(opt); _fwCorrectAnswers.remove(opt); }),
      );
    }),
  ]),
  SizedBox(height: 8),
  Row(children: [
    Expanded(child: TextField(controller: _fwOptionInputController, decoration: InputDecoration(hintText: 'Add option...', border: OutlineInputBorder(), isDense: true))),
    SizedBox(width: 8),
    IconButton(icon: Icon(Icons.add_circle), onPressed: _addFindWordsOption),
  ]),
  SizedBox(height: 16),
  VocabularyWordPicker(selectedWordIds: _vocabularyWordIds, onChanged: (ids) => setState(() => _vocabularyWordIds = ids)),
])
```

**`_buildMatchingForm(WidgetRef ref)`:**
```dart
Column(children: [
  TextField(controller: _instructionController, maxLines: 2,
    decoration: InputDecoration(labelText: 'Instruction', hintText: 'e.g. Match each character with their role...', border: OutlineInputBorder())),
  SizedBox(height: 12),
  Text('Pairs:', style: TextStyle(fontWeight: FontWeight.w500)),
  SizedBox(height: 8),
  ...List.generate(_pairs.length, (i) => Padding(
    padding: EdgeInsets.only(bottom: 8),
    child: Row(children: [
      Expanded(child: TextField(
        decoration: InputDecoration(labelText: 'Left ${i + 1}', border: OutlineInputBorder(), isDense: true),
        controller: TextEditingController(text: _pairs[i]['left']),
        onChanged: (v) => _pairs[i]['left'] = v,
      )),
      SizedBox(width: 8),
      Icon(Icons.arrow_forward, color: Colors.grey),
      SizedBox(width: 8),
      Expanded(child: TextField(
        decoration: InputDecoration(labelText: 'Right ${i + 1}', border: OutlineInputBorder(), isDense: true),
        controller: TextEditingController(text: _pairs[i]['right']),
        onChanged: (v) => _pairs[i]['right'] = v,
      )),
      SizedBox(width: 4),
      IconButton(icon: Icon(Icons.remove_circle, color: Colors.red, size: 20), onPressed: () => setState(() => _pairs.removeAt(i))),
    ]),
  )),
  TextButton.icon(icon: Icon(Icons.add, size: 18), label: Text('Add Pair'),
    onPressed: () => setState(() => _pairs.add({'left': '', 'right': ''}))),
  SizedBox(height: 16),
  VocabularyWordPicker(selectedWordIds: _vocabularyWordIds, onChanged: (ids) => setState(() => _vocabularyWordIds = ids)),
])
```

**Important for matching:** Don't create new `TextEditingController` in build. Instead, maintain a list of controller pairs in state:
```dart
List<TextEditingController> _leftControllers = [];
List<TextEditingController> _rightControllers = [];

// In initState, sync controllers from _pairs:
void _syncMatchingControllers() {
  for (final c in _leftControllers) c.dispose();
  for (final c in _rightControllers) c.dispose();
  _leftControllers = _pairs.map((p) => TextEditingController(text: p['left'])).toList();
  _rightControllers = _pairs.map((p) => TextEditingController(text: p['right'])).toList();
  // Add listeners to sync back to _pairs:
  for (int i = 0; i < _pairs.length; i++) {
    _leftControllers[i].addListener(() => _pairs[i]['left'] = _leftControllers[i].text);
    _rightControllers[i].addListener(() => _pairs[i]['right'] = _rightControllers[i].text);
  }
}

// When adding a pair:
void _addPair() {
  setState(() {
    _pairs.add({'left': '', 'right': ''});
    _syncMatchingControllers();
  });
}

// When removing a pair:
void _removePair(int index) {
  setState(() {
    _pairs.removeAt(index);
    _syncMatchingControllers();
  });
}
```
Call `_syncMatchingControllers()` in `initState` (after populating `_pairs`). Use `_leftControllers[i]` and `_rightControllers[i]` in the build method instead of inline constructors.

**Dispose ALL controllers in `dispose()`:**
```dart
@override
void dispose() {
  _statementController.dispose();
  _wordController.dispose();
  _translationController.dispose();
  _optionInputController.dispose();
  _instructionController.dispose();
  _fwOptionInputController.dispose();
  for (final c in _leftControllers) c.dispose();
  for (final c in _rightControllers) c.dispose();
  super.dispose();
}
```

- [ ] **Step 3: Implement validation (`_validate()`)**

```dart
String? _validate() {
  switch (widget.activityType) {
    case 'true_false':
      if (_statementController.text.trim().isEmpty) return 'Statement is required';
    case 'word_translation':
      if (_wordController.text.trim().isEmpty) return 'Word is required';
      if (_translationController.text.trim().isEmpty) return 'Translation is required';
      final allOptions = {..._options, _translationController.text.trim()};
      if (allOptions.length < 2) return 'At least 2 options required';
    case 'find_words':
      if (_instructionController.text.trim().isEmpty) return 'Instruction is required';
      if (_fwOptions.isEmpty) return 'At least 1 option required';
      if (_fwCorrectAnswers.isEmpty) return 'At least 1 correct answer required';
      if (!_fwCorrectAnswers.every((a) => _fwOptions.contains(a))) return 'Correct answers must be from options';
    case 'matching':
      if (_instructionController.text.trim().isEmpty) return 'Instruction is required';
      if (_pairs.length < 2) return 'At least 2 pairs required';
      for (final p in _pairs) {
        if ((p['left'] ?? '').trim().isEmpty || (p['right'] ?? '').trim().isEmpty) {
          return 'All pair fields must be filled';
        }
      }
  }
  return null;
}
```

- [ ] **Step 4: Implement save (`_handleSave()`)**

```dart
Future<void> _handleSave() async {
  final error = _validate();
  if (error != null) {
    setState(() => _error = error);
    return;
  }
  setState(() { _error = null; _isSaving = true; });

  try {
    final supabase = ref.read(supabaseClientProvider);

    // Build content JSONB
    final content = _buildContent();

    final isEdit = widget.existingActivity != null;
    String activityId;

    if (isEdit) {
      // UPDATE existing inline_activities row
      activityId = widget.existingActivity!['id'] as String;
      await supabase.from(DbTables.inlineActivities).update({
        'type': widget.activityType,
        'content': content,
        'vocabulary_words': _vocabularyWordIds,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', activityId);
    } else {
      // INSERT new inline_activities row
      activityId = const Uuid().v4();
      await supabase.from(DbTables.inlineActivities).insert({
        'id': activityId,
        'chapter_id': widget.chapterId,
        'type': widget.activityType,
        'content': content,
        'vocabulary_words': _vocabularyWordIds,
        'xp_reward': 5,
        'after_paragraph_index': 0,
      });

      // UPDATE content_blocks to link activity_id
      await supabase.from(DbTables.contentBlocks).update({
        'activity_id': activityId,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', widget.blockId);
    }

    widget.onSaved();
  } catch (e) {
    // Rollback: if we inserted a new activity but the content_blocks update failed,
    // delete the orphaned inline_activities row
    if (!isEdit && activityId.isNotEmpty) {
      try {
        await supabase.from(DbTables.inlineActivities).delete().eq('id', activityId);
      } catch (_) {
        // Best-effort cleanup
      }
    }
    setState(() => _error = 'Save failed: $e');
  } finally {
    if (mounted) setState(() => _isSaving = false);
  }
}

Map<String, dynamic> _buildContent() {
  switch (widget.activityType) {
    case 'true_false':
      return {
        'statement': _statementController.text.trim(),
        'correct_answer': _correctAnswer,
      };
    case 'word_translation':
      final opts = {..._options, _translationController.text.trim()}.toList();
      return {
        'word': _wordController.text.trim(),
        'correct_answer': _translationController.text.trim(),
        'options': opts,
      };
    case 'find_words':
      return {
        'instruction': _instructionController.text.trim(),
        'options': _fwOptions,
        'correct_answers': _fwCorrectAnswers.toList(),
      };
    case 'matching':
      return {
        'instruction': _instructionController.text.trim(),
        'pairs': _pairs.map((p) => {'left': (p['left'] ?? '').trim(), 'right': (p['right'] ?? '').trim()}).toList(),
      };
    default:
      return {};
  }
}
```

- [ ] **Step 5: Verify it compiles**

Run: `cd /Users/wonderelt/Desktop/Owlio/owlio_admin && dart analyze lib/features/books/widgets/activity_editor.dart`
Expected: No errors

- [ ] **Step 6: Commit**

```bash
git add lib/features/books/widgets/activity_editor.dart
git commit -m "feat: add activity editor widget with all 4 activity type forms"
```

---

## Task 4: Integrate into Content Block Editor

**Files:**
- Modify: `lib/features/books/widgets/content_block_editor.dart`

Four changes:
1. Replace single "Aktivite" add-block button with 4 type-specific buttons
2. Pass `chapterId` to `_BlockCard`
3. In `_BlockCard`, render `ActivityEditor` for activity blocks
4. Update `_deleteBlock` to also delete the linked `inline_activities` row

- [ ] **Step 1: Replace the "Aktivite" button with 4 activity type buttons**

In `_ContentBlockListState.build()`, replace the single activity button (lines 321-326) with a `PopupMenuButton`:

```dart
PopupMenuButton<String>(
  onSelected: (type) => _addBlock('activity', activityType: type),
  itemBuilder: (context) => [
    const PopupMenuItem(value: 'true_false', child: ListTile(leading: Icon(Icons.check_circle_outline), title: Text('True/False'), dense: true)),
    const PopupMenuItem(value: 'word_translation', child: ListTile(leading: Icon(Icons.translate), title: Text('Word Translation'), dense: true)),
    const PopupMenuItem(value: 'find_words', child: ListTile(leading: Icon(Icons.search), title: Text('Find Words'), dense: true)),
    const PopupMenuItem(value: 'matching', child: ListTile(leading: Icon(Icons.compare_arrows), title: Text('Matching'), dense: true)),
  ],
  child: FilledButton.tonalIcon(
    onPressed: () {}, // no-op — PopupMenuButton handles the tap; must NOT be null (null = disabled visual state)
    icon: const Icon(Icons.quiz, size: 18),
    label: const Text('Aktivite'),
  ),
),
```

Update `_addBlock` signature to accept optional `activityType`:
```dart
Future<void> _addBlock(String type, {String? activityType}) async {
  ...
  // DB payload — only real columns
  final insertData = {
    'id': newBlockId,
    'chapter_id': widget.chapterId,
    'order_index': newOrderIndex,
    'type': type,
  };

  // Local copy — includes UI-only metadata (NOT sent to DB)
  final localBlock = {
    ...insertData,
    if (activityType != null) '_activityType': activityType,
  };

  setState(() { _localBlocks = [..._localBlocks, localBlock]; });

  try {
    await supabase.from(DbTables.contentBlocks).insert(insertData); // insertData, NOT localBlock
    widget.onRefresh();
  } catch (e) {
    setState(() { _localBlocks = _localBlocks.where((b) => b['id'] != newBlockId).toList(); });
    // ... error snackbar ...
  }
}
```

**CRITICAL:** `_activityType` is a local-only key prefixed with `_` — it must NEVER be sent to Supabase. The `insertData` map (without `_activityType`) goes to the DB; `localBlock` (with `_activityType`) goes to `_localBlocks`.

- [ ] **Step 2: Pass chapterId to _BlockCard and render ActivityEditor**

Add `chapterId` to `_BlockCard`:
```dart
_BlockCard(
  key: ValueKey(block['id']),
  block: block,
  index: index,
  chapterId: widget.chapterId, // NEW
  onDelete: () => _deleteBlock(block['id'] as String),
  onRefresh: widget.onRefresh,
)
```

Update `_BlockCard` constructor and field.

In `_buildContent` for `case 'activity':`, replace the entire current FutureBuilder with:

```dart
case 'activity':
  final activityId = widget.block['activity_id'] as String?;

  // If editing or new (no activity_id), show the editor
  if (_isEditing || activityId == null) {
    final activityType = widget.block['_activityType'] as String? ?? _loadedActivity?['type'] as String? ?? 'true_false';
    return ActivityEditor(
      chapterId: widget.chapterId,
      blockId: widget.block['id'] as String,
      activityType: activityType,
      existingActivity: _loadedActivity,
      onSaved: () {
        setState(() => _isEditing = false);
        widget.onRefresh();
      },
      onCancel: () => setState(() => _isEditing = false),
    );
  }

  // Read-only view: use cached future to avoid re-fetching on every build
  _activityFuture ??= _loadActivity(activityId);
  return FutureBuilder<Map<String, dynamic>?>(
    future: _activityFuture,
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const Center(child: CircularProgressIndicator());
      }
      final activity = snapshot.data;
      if (activity == null) {
        return const Text('Activity not found');
      }
      _loadedActivity = activity; // cache for edit mode
      return _buildActivitySummary(activity);
    },
  );
```

Add fields to `_BlockCardState`:
```dart
Map<String, dynamic>? _loadedActivity;
Future<Map<String, dynamic>?>? _activityFuture; // cached to prevent re-fetching
```

Invalidate `_activityFuture` when the activity is saved (in `onSaved` callback, set `_activityFuture = null` before calling `widget.onRefresh()`).

**Hide header Save/Cancel for activity blocks** — the ActivityEditor has its own buttons. In the header section that shows Save/Cancel when `_isEditing`:
```dart
// Change from:
if (_isEditing) ...[
// Change to:
if (_isEditing && type != 'activity') ...[
```
This prevents duplicate Save/Cancel button pairs for activity blocks.

Add `_buildActivitySummary` method:
```dart
Widget _buildActivitySummary(Map<String, dynamic> activity) {
  final type = activity['type'] as String? ?? '';
  final content = activity['content'] as Map<String, dynamic>? ?? {};
  final vocabWords = (activity['vocabulary_words'] as List<dynamic>?)?.length ?? 0;

  String summary;
  switch (type) {
    case 'true_false':
      summary = content['statement'] as String? ?? '';
    case 'word_translation':
      summary = '${content['word'] ?? ''} → ${content['correct_answer'] ?? ''}';
    case 'find_words':
      summary = content['instruction'] as String? ?? '';
    case 'matching':
      final pairs = (content['pairs'] as List<dynamic>?)?.length ?? 0;
      summary = '${content['instruction'] ?? ''} ($pairs pairs)';
    default:
      summary = 'Unknown type';
  }

  final typeLabel = type.replaceAll('_', ' ').split(' ').map((w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : '').join(' ');

  return Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.purple.withValues(alpha: 0.05),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: Colors.purple.withValues(alpha: 0.2)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(color: Colors.purple.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4)),
            child: Text(typeLabel, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.purple)),
          ),
          if (vocabWords > 0) ...[
            const SizedBox(width: 8),
            Text('$vocabWords vocab words', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
          ],
        ]),
        const SizedBox(height: 8),
        Text(summary, maxLines: 2, overflow: TextOverflow.ellipsis),
      ],
    ),
  );
}
```

- [ ] **Step 3: Update delete flow to also delete inline_activities row**

In `_ContentBlockListState._deleteBlock`, before deleting the content block, read and save the `activity_id`, then after content block deletion, also delete the inline_activities row:

```dart
Future<void> _deleteBlock(String blockId) async {
  // ... existing confirmation dialog ...

  final deletedBlock = _localBlocks.where((b) => b['id'] == blockId).firstOrNull;
  if (deletedBlock == null) return;

  final activityId = deletedBlock['activity_id'] as String?; // NEW: save activity_id

  setState(() { _localBlocks = _localBlocks.where((b) => b['id'] != blockId).toList(); });

  try {
    final supabase = ref.read(supabaseClientProvider);
    await supabase.from(DbTables.contentBlocks).delete().eq('id', blockId);

    // NEW: also delete linked inline_activities row
    if (activityId != null) {
      await supabase.from(DbTables.inlineActivities).delete().eq('id', activityId);
    }

    widget.onRefresh();
  } catch (e) {
    // ... existing rollback ...
  }
}
```

- [ ] **Step 4: Also show "Not configured" badge for activity blocks without activity_id**

In `_BlockCardState.build()`, add a badge for activity blocks with no activity_id (similar to the existing "Bos" badge for empty text blocks). Add after the existing `hasText` check block around line 521:

```dart
if (type == 'activity' && (widget.block['activity_id'] as String?) == null && !_isEditing) ...[
  const SizedBox(width: 8),
  Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: Colors.orange.withValues(alpha: 0.2),
      borderRadius: BorderRadius.circular(4),
    ),
    child: const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.warning_amber, size: 12, color: Colors.orange),
        SizedBox(width: 4),
        Text('Not configured', style: TextStyle(fontSize: 10, color: Colors.orange)),
      ],
    ),
  ),
],
```

- [ ] **Step 5: Update type helpers for activity subtypes**

Update `_getTypeName` to show the activity subtype when available:
```dart
String _getTypeName(String type) {
  if (type == 'activity') {
    final activityType = widget.block['_activityType'] as String? ?? _loadedActivity?['type'] as String?;
    if (activityType != null) {
      return activityType.replaceAll('_', ' ').split(' ').map((w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : '').join(' ');
    }
    return 'Aktivite';
  }
  // ... existing cases ...
}
```

- [ ] **Step 6: Verify compilation**

Run: `cd /Users/wonderelt/Desktop/Owlio/owlio_admin && dart analyze lib/features/books/widgets/`
Expected: No errors

- [ ] **Step 7: Commit**

```bash
git add lib/features/books/widgets/content_block_editor.dart
git commit -m "feat: integrate activity editor into content block editor"
```

---

## Task 5: Vocabulary List Screen — Source Badge & Sort

**Files:**
- Modify: `lib/features/vocabulary/screens/vocabulary_list_screen.dart`

- [ ] **Step 1: Change default sort to created_at DESC**

In `vocabularyProvider` (line 66), change the `.order()` call:

```dart
// Before:
final response = await query.order('word').range(offset, offset + pageSize - 1);

// After:
final response = await query.order('created_at', ascending: false).range(offset, offset + pageSize - 1);
```

- [ ] **Step 2: Add source badge to the word table row**

In `_VocabularyTab._buildRow()`, update the first column (Kelime) to include a source badge when `source == 'activity'`:

```dart
// Kelime column (first column in the TableRow)
InkWell(
  onTap: () => context.go('/vocabulary/${w['id']}'),
  child: Padding(
    padding: const EdgeInsets.all(10),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          w['word'] ?? '',
          style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF4F46E5)),
        ),
        if (w['source'] == 'activity') ...[
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: Colors.purple.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(3),
            ),
            child: const Text(
              'AKTİVİTEDEN EKLENDİ',
              style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: Colors.purple),
            ),
          ),
        ],
      ],
    ),
  ),
),
```

- [ ] **Step 3: Verify compilation**

Run: `cd /Users/wonderelt/Desktop/Owlio/owlio_admin && dart analyze lib/features/vocabulary/screens/vocabulary_list_screen.dart`
Expected: No errors

- [ ] **Step 4: Commit**

```bash
git add lib/features/vocabulary/screens/vocabulary_list_screen.dart
git commit -m "feat: add source badge and sort by newest in vocabulary list"
```

---

## Task 6: Vocabulary Edit & Import Screen Changes

**Files:**
- Modify: `lib/features/vocabulary/screens/vocabulary_edit_screen.dart`
- Modify: `lib/features/vocabulary/screens/vocabulary_import_screen.dart`

- [ ] **Step 1: Add read-only source display to vocabulary edit screen**

In `_VocabularyEditScreenState`, add state for source:
```dart
String _source = 'manual';
```

In `_loadWord()`, load the source:
```dart
_source = word['source'] as String? ?? 'manual';
```

In the build form, after the "Kelime Bilgileri" heading section, add a source indicator when `_source != 'manual'`:
```dart
if (!isNewWord && _source != 'manual') ...[
  Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: _source == 'activity' ? Colors.purple.withValues(alpha: 0.1) : Colors.blue.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          _source == 'activity' ? Icons.quiz : Icons.upload,
          size: 16,
          color: _source == 'activity' ? Colors.purple : Colors.blue,
        ),
        const SizedBox(width: 6),
        Text(
          _source == 'activity' ? 'Aktiviteden eklendi' : 'CSV\'den içe aktarıldı',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: _source == 'activity' ? Colors.purple : Colors.blue,
          ),
        ),
      ],
    ),
  ),
  const SizedBox(height: 16),
],
```

- [ ] **Step 2: Add `source: 'import'` to CSV import**

In `vocabulary_import_screen.dart`, `_processRow()` method, when inserting new words (line 226), add `source`:

```dart
// Before (line 226):
data['id'] = const Uuid().v4();
await supabase.from(DbTables.vocabularyWords).insert(data);

// After:
data['id'] = const Uuid().v4();
data['source'] = 'import';
await supabase.from(DbTables.vocabularyWords).insert(data);
```

Note: Only set `source` on INSERT (new words), not UPDATE (existing words) — keep existing source unchanged.

- [ ] **Step 3: Verify compilation**

Run: `cd /Users/wonderelt/Desktop/Owlio/owlio_admin && dart analyze lib/features/vocabulary/screens/`
Expected: No errors

- [ ] **Step 4: Commit**

```bash
git add lib/features/vocabulary/screens/vocabulary_edit_screen.dart lib/features/vocabulary/screens/vocabulary_import_screen.dart
git commit -m "feat: show source indicator in vocab edit screen, tag CSV imports"
```

---

## Task 7: Full Integration Verification

- [ ] **Step 1: Run full analyzer**

Run: `cd /Users/wonderelt/Desktop/Owlio/owlio_admin && dart analyze lib/`
Expected: No errors (or only pre-existing warnings)

- [ ] **Step 2: Manual testing checklist**

Test in the browser (`flutter run -d chrome`):

1. **Add Block menu** — verify 4 activity type options appear in popup menu
2. **True/False** — create block, fill statement + toggle answer, save, verify read-only summary
3. **Word Translation** — create block, fill word + translation + options, save
4. **Find Words** — create block, fill instruction + options + mark correct answers, save
5. **Matching** — create block, fill instruction + add pairs, save
6. **Edit activity** — click edit on saved activity, verify form pre-populates, change values, re-save
7. **Delete activity** — delete activity block, verify `inline_activities` row is also deleted (check Supabase dashboard)
8. **Vocabulary word picker** — search for existing word, verify autocomplete
9. **Inline word creation** — type new word in picker, verify dialog with word+meaning_tr, verify word appears in vocabulary list with "AKTİVİTEDEN EKLENDİ" badge
10. **Vocabulary list** — verify default sort is newest first, verify source badge appears
11. **Vocabulary edit** — open an activity-created word, verify "Aktiviteden eklendi" indicator
12. **CSV import** — import a word, verify it gets `source: 'import'`

- [ ] **Step 3: Final commit (if any remaining fixes)**

```bash
git add -A
git commit -m "fix: integration fixes for inline activity editor"
```
