# Inline Activity Editor — Design Spec

**Date:** 2026-03-21
**Scope:** Admin panel — inline activity creation/editing within the content block editor

---

## Problem

Activity blocks in the admin panel's content block editor are read-only placeholders. There is no UI to create or edit `inline_activities` rows. The only path for authoring activity content is the JSON bulk import screen.

**Current state:**
- Adding an "activity" block creates a `content_blocks` row with `activity_id = null`
- The card shows "Aktivite atanmamis" or a read-only type/title display
- `_saveBlock` has no branch for `type == 'activity'`
- Edit button sets `_isEditing = true` but no form is rendered

---

## Design

### 1. Block Creation — Type Selection Up Front

The "Add Block" menu expands from 3 options to 6:

| Current | New |
|---------|-----|
| Text | Text |
| Image | Image |
| Activity | True/False |
| | Word Translation |
| | Find Words |
| | Matching |

When a specific activity type is selected:
1. A `content_blocks` row is created with `type = 'activity'` (existing behavior)
2. The block card immediately renders the inline edit form for that activity type
3. No `inline_activities` row is created until first save

### 2. Inline Edit Forms

All forms render inside the block card (same pattern as text/image editing). Each form has a "Save" button that validates and persists.

#### True/False
- **Statement** — text input (required)
- **Correct Answer** — toggle: True / False (default: True)

#### Word Translation
- **Word** — text input (required)
- **Correct Answer (translation)** — text input (required)
- **Options** — chip list with text input to add (min 2 required; correct_answer auto-included)
- **Vocabulary Words** — autocomplete search + inline add (see Section 4)

#### Find Words
- **Instruction** — text input (required)
- **Options** — chip list with text input to add (min 1 required)
- **Correct Answers** — toggle/checkbox on each option chip to mark as correct (min 1 required; must be subset of options)
- **Vocabulary Words** — autocomplete search + inline add (see Section 4)

#### Matching
- **Instruction** — text input (required)
- **Pairs** — list of left/right text input rows (min 2 required)
  - "+" button to add new pair
  - "x" button on each row to remove
- **Vocabulary Words** — autocomplete search + inline add (see Section 4)

### 3. Validation (on save)

| Type | Rules |
|------|-------|
| `true_false` | statement not empty |
| `word_translation` | word not empty, correct_answer not empty, min 2 options, correct_answer in options |
| `find_words` | instruction not empty, min 1 option, min 1 correct_answer, correct_answers subset of options |
| `matching` | instruction not empty, min 2 pairs, no empty left/right values |

Errors displayed as red text below the relevant field or at the form level.

### 4. Vocabulary Words Field

Appears on `word_translation`, `find_words`, and `matching` forms. NOT on `true_false`.

**Autocomplete search:**
- Text input that searches `vocabulary_words` table by `word` column
- Dropdown shows matching words (word + translation if available)
- Selecting adds the word's UUID to the activity's `vocabulary_words` array
- Selected words displayed as removable chips below the input

**Inline word creation:**
- If the typed word doesn't exist, show "Add [word]" option in dropdown
- Creates a minimal `vocabulary_words` row: only `word` field filled, `source = 'activity'`
- Other fields (translation, phonetic, CEFR level, etc.) left null — to be completed later in vocabulary management screen
- Returns the new UUID immediately for use in the activity

### 5. Save Flow

1. Admin fills form, clicks "Save"
2. Validation runs — errors shown if invalid
3. If new vocabulary words were typed inline, INSERT them into `vocabulary_words` first (with `source = 'activity'`)
4. INSERT into `inline_activities`: `chapter_id`, `type`, `content` (JSONB), `vocabulary_words` (UUID[]), `xp_reward: 5`
5. UPDATE `content_blocks` row: set `activity_id` to the new `inline_activities.id`
6. Card collapses to read-only view showing activity summary

**Edit flow:** Same form, pre-populated with existing data. UPDATE instead of INSERT on `inline_activities`.

**Delete flow:** When an activity block is deleted, also DELETE the linked `inline_activities` row (currently orphaned due to ON DELETE SET NULL).

### 6. Read-Only View (collapsed)

After saving, the activity card shows:
- Activity type badge (e.g., "True/False", "Matching")
- Brief content summary (e.g., statement text, word, instruction)
- Number of vocabulary words attached
- Edit / Delete buttons

---

## Database Changes

### New migration: `source` column on `vocabulary_words`

```sql
ALTER TABLE vocabulary_words
ADD COLUMN source VARCHAR(20) DEFAULT 'manual';

COMMENT ON COLUMN vocabulary_words.source IS 'Origin of the word: manual, import, activity';
```

Existing rows get `'manual'`. CSV import updated to write `'import'`. Activity editor writes `'activity'`.

### No other schema changes needed

`inline_activities` and `content_blocks` tables already have all required columns.

---

## Vocabulary List Screen Changes

1. **Source badge** — each word row shows a colored badge when `source = 'activity'` ("AKTIVITEDEN EKLENDI")
2. **Default sort** — `created_at DESC` (most recent first)
3. **Source column** visible in the list (or badge on the word row)

---

## Files to Modify

| File | Change |
|------|--------|
| `content_block_editor.dart` | Add activity type forms, save/edit/delete logic, vocabulary autocomplete |
| `vocabulary_list_screen.dart` | Source badge, default sort by created_at DESC |
| `vocabulary_edit_screen.dart` | Show source field (read-only) |
| New migration file | `source` column on `vocabulary_words` |

---

## Out of Scope

- XP configuration per activity (fixed at 5)
- SM-2 algorithm display/configuration (handled by daily review system)
- `after_paragraph_index` field (legacy, unused by block-based reader)
- Activity reuse across chapters (1:1 relationship maintained)
- Bulk activity creation/import changes
