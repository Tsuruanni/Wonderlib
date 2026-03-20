# Learning Path Templates & Unified Assignment System

**Date:** 2026-03-20
**Status:** Design approved, pending implementation plan

## Problem

The admin panel has 5 separate screens for managing vocabulary content delivery:
- Words, Word Lists, Units, Unit Assignments (Curriculum), Unit Books

Unit Assignments and Unit Books share nearly identical scope-selection UI (school/grade/class) but are managed separately. Additionally:
- No way to save a learning path configuration as a reusable template
- Word lists are hard-coded to units (`word_lists.unit_id` FK), preventing the same word list from appearing in different units across different curricula
- Books and word lists cannot be freely interleaved within a unit
- Cannot assign multiple independent learning paths to the same scope

## Solution

### Overview

Replace the separate Curriculum + Unit Books screens with a **template-based learning path system**:

1. **Templates** define reusable learning paths (units + word lists + books in any order)
2. **Assignments** apply templates to school/grade/class scopes as independent copies
3. Each scope can have **multiple independent learning paths**
4. After applying a template, the scope's copy is **fully independent** — edits don't affect the source template or other scopes

### Key Design Decisions

| Decision | Choice | Reasoning |
|----------|--------|-----------|
| Template application model | Snapshot (copy) | Each scope independently editable after apply. Template = starting point only. |
| Word list ↔ Unit relationship | Via template/scope items, not FK | Same word list can appear in different units across templates |
| Item ordering within unit | Single sort_order, mixed types | Word lists and books freely interleaved |
| Multiple paths per scope | Yes, via scope_learning_paths | A school can use "Oxford Discover 1" + "Cambridge English 1" simultaneously |
| Backward compatibility | Not needed | Project is in development/test phase, no production users |

## Database Schema

### New Tables (6)

#### Template Side (content authoring)

```sql
-- Reusable learning path definition
CREATE TABLE learning_path_templates (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name        VARCHAR(255) NOT NULL,
  description TEXT,
  created_by  UUID REFERENCES profiles(id),
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Units within a template (ordered)
CREATE TABLE learning_path_template_units (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  template_id UUID NOT NULL REFERENCES learning_path_templates(id) ON DELETE CASCADE,
  unit_id     UUID NOT NULL REFERENCES vocabulary_units(id) ON DELETE CASCADE,
  sort_order  INTEGER NOT NULL DEFAULT 0,
  UNIQUE(template_id, unit_id)
);

-- Items (word lists + books) within each template unit (ordered, interleaved)
CREATE TABLE learning_path_template_items (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  template_unit_id UUID NOT NULL REFERENCES learning_path_template_units(id) ON DELETE CASCADE,
  item_type        VARCHAR(20) NOT NULL CHECK (item_type IN ('word_list', 'book')),
  item_id          UUID NOT NULL,
  sort_order       INTEGER NOT NULL DEFAULT 0,
  UNIQUE(template_unit_id, item_type, item_id)
);
```

#### Scope Side (applied to school/grade/class)

```sql
-- An applied learning path instance at a scope
CREATE TABLE scope_learning_paths (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name        VARCHAR(255) NOT NULL,
  template_id UUID REFERENCES learning_path_templates(id) ON DELETE SET NULL,
  school_id   UUID NOT NULL REFERENCES schools(id) ON DELETE CASCADE,
  grade       INTEGER CHECK (grade BETWEEN 1 AND 12),
  class_id    UUID REFERENCES classes(id),
  sort_order  INTEGER NOT NULL DEFAULT 0,
  created_by  UUID REFERENCES profiles(id),
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  CHECK (NOT (grade IS NOT NULL AND class_id IS NOT NULL))
);

-- Units within an applied learning path (ordered)
CREATE TABLE scope_learning_path_units (
  id                     UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  scope_learning_path_id UUID NOT NULL REFERENCES scope_learning_paths(id) ON DELETE CASCADE,
  unit_id                UUID NOT NULL REFERENCES vocabulary_units(id) ON DELETE CASCADE,
  sort_order             INTEGER NOT NULL DEFAULT 0,
  UNIQUE(scope_learning_path_id, unit_id)
);

-- Items (word lists + books) within each scope unit (ordered, interleaved)
CREATE TABLE scope_unit_items (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  scope_lp_unit_id UUID NOT NULL REFERENCES scope_learning_path_units(id) ON DELETE CASCADE,
  item_type        VARCHAR(20) NOT NULL CHECK (item_type IN ('word_list', 'book')),
  item_id          UUID NOT NULL,
  sort_order       INTEGER NOT NULL DEFAULT 0,
  UNIQUE(scope_lp_unit_id, item_type, item_id)
);
```

### Tables Removed

| Table | Replacement |
|-------|-------------|
| `unit_curriculum_assignments` | `scope_learning_path_units` |
| `unit_book_assignments` | `scope_unit_items` |

### Tables Modified

| Table | Change |
|-------|--------|
| `word_lists.unit_id` | Made nullable. No longer the source of truth for unit membership. |

### Cascade Delete Chains

```
Template deleted → template_units deleted → template_items deleted
Scope learning path deleted → scope_lp_units deleted → scope_unit_items deleted
Vocabulary unit deleted → removed from all templates and scopes
```

### Symmetric Structure

```
Template side:                    Scope side:
learning_path_templates     ↔     scope_learning_paths
  └── template_units        ↔       └── scope_learning_path_units
        └── template_items  ↔             └── scope_unit_items
```

## RPC Functions

### Removed

- `get_assigned_vocabulary_units(p_user_id)` — replaced by new RPC
- `get_user_unit_books(p_user_id)` — replaced by new RPC

### New

```sql
-- Returns the complete learning path structure for a user
-- Cascading scope resolution: class → grade → school
get_user_learning_paths(p_user_id UUID)
RETURNS TABLE (
  learning_path_id   UUID,
  learning_path_name VARCHAR,
  lp_sort_order      INTEGER,
  unit_id            UUID,
  unit_name          VARCHAR,
  unit_color         VARCHAR,
  unit_icon          VARCHAR,
  unit_sort_order    INTEGER,
  item_type          VARCHAR,
  item_id            UUID,
  item_sort_order    INTEGER
)
```

## Admin Panel UI

### Screen 1: Template List (`/templates`)

Simple list of all templates with summary stats (unit count, word list count, book count). Links to template edit screen.

### Screen 2: Template Edit (`/templates/:id`)

Tree-view editor for template content:

```
Template Name: [Oxford Discover 1]
Description:   [...]

📦 Unit 1: Basics                              [drag] [remove]
  1. 📝 Animals (5 kelime)                     [drag] [remove]
     ▶ apple, banana, cat, dog, elephant       (expandable word preview)
  2. 📝 Colors (8 kelime)                      [drag] [remove]
  3. 📖 The Cat · A1 · 4 bölüm                [drag] [remove]
  4. 📝 Family (6 kelime)                      [drag] [remove]
  [+ Add Word List]  [+ Add Book]

📦 Unit 2: Daily Life                          [drag] [remove]
  1. 📝 Food (6 kelime)                        [drag] [remove]
  2. 📖 My Day · A1                            [drag] [remove]
  [+ Add Word List]  [+ Add Book]

[+ Add Unit]
```

**Features:**
- Drag-drop reordering for units and items within units
- Word lists and books freely interleaved via sort_order
- Word preview: expandable inline display of words within each word list (read-only)
- Add unit: dialog to select from existing vocabulary_units
- Add word list: search dialog across all word_lists
- Add book: search dialog across published books
- Remove: detaches from template (does not delete the underlying entity)

### Screen 3: Learning Path Assignment (`/assignments`)

Single-page scope-based assignment with inline editing:

```
School: [Demo School ▼]
Target: ○ All School  ● Grade [5 ▼]  ○ Class [▼]

Assigned Learning Paths:

📗 Oxford Discover 1                           [drag] [delete]
  📦 Unit 1: Basics
    1. 📝 Animals (5)
    2. 📖 The Cat · A1                         [remove]
    [+ Word List]  [+ Book]
  📦 Unit 2: ...

📘 Cambridge English 1                         [drag] [delete]
  ...

[+ Apply Template]  [+ Empty Learning Path]
```

**Features:**
- Scope selection at top (school + target type + grade/class)
- Selecting a scope loads existing assignments from scope_learning_paths
- "Apply Template" copies template content into scope tables as independent data
- Full inline editing (same tree-view component as template editor)
- Multiple learning paths per scope, drag-drop reorderable
- "Empty Learning Path" creates a blank path for manual composition
- Changes only affect this scope — template and other scopes are not modified

### Shared Component: LearningPathTreeView

Both template edit and assignment screens use the same tree-view widget. Parameters:
- `units`: list of units with their items
- `onReorder`: callback for drag-drop
- `onAddItem`: callback for adding word list or book
- `onRemoveItem`: callback for removing item
- `readOnly`: boolean (for reference display)
- `showWordPreview`: boolean (expandable word list under each word list item)

### Dashboard Changes

| Old Card | New Card |
|----------|----------|
| Ünite Atamaları | Öğrenme Yolu Şablonları |
| Ünite Kitapları | Öğrenme Yolu Ataması |

### Router Changes

| Removed | Added |
|---------|-------|
| `/curriculum` | `/templates` |
| `/curriculum/new` | `/templates/new` |
| `/curriculum/:id` | `/templates/:id` |
| `/unit-books` | `/assignments` |
| `/unit-books/new` | (not needed, single-page) |

### Admin Files Removed

- `features/curriculum/screens/curriculum_list_screen.dart`
- `features/curriculum/screens/curriculum_edit_screen.dart`
- `features/unit_books/screens/unit_books_list_screen.dart`
- `features/unit_books/screens/unit_books_edit_screen.dart`

## Mobile App Changes

### Entity Changes

| Entity | Change |
|--------|--------|
| `word_list.dart` | `unitId` becomes nullable |
| `unit_book.dart` | Replaced by generic `LearningPathItem` entity |
| New: `learning_path.dart` | Top-level learning path entity (id, name, sortOrder) |

### Repository Changes

| File | Change |
|------|--------|
| `supabase_word_list_repository.dart` | `getAssignedVocabularyUnits` → calls new RPC |
| `supabase_book_repository.dart` | `getUnitBooks` → removed, handled by new RPC |

### Provider Changes

| Provider | Change |
|----------|--------|
| `vocabularyUnitsProvider` | Reads from new RPC result |
| `unitBooksProvider` | Removed — items come from unified provider |
| `learningPathProvider` | Restructured to handle multiple learning paths + mixed items |
| `allWordListsProvider` | No longer filters by `unitId != null` |

### New RPC Consumption

Single call replaces 3 separate data fetches:
```dart
// Old: 3 calls
final units = await getAssignedVocabularyUnits(userId);
final wordLists = await getAllWordLists(); // filtered by unitId
final books = await getUnitBooks(userId);

// New: 1 call
final learningPaths = await getUserLearningPaths(userId);
// Contains: paths → units → items (word lists + books, interleaved)
```

## Shared Package Changes

### New Constants in `tables.dart`

```dart
static const learningPathTemplates = 'learning_path_templates';
static const learningPathTemplateUnits = 'learning_path_template_units';
static const learningPathTemplateItems = 'learning_path_template_items';
static const scopeLearningPaths = 'scope_learning_paths';
static const scopeLearningPathUnits = 'scope_learning_path_units';
static const scopeUnitItems = 'scope_unit_items';
```

### Removed Constants

```dart
// Remove from tables.dart:
static const unitBookAssignments = 'unit_book_assignments';
static const unitCurriculumAssignments = 'unit_curriculum_assignments';

// Remove from rpc_functions.dart:
static const getUserUnitBooks = 'get_user_unit_books';
static const getAssignedVocabularyUnits = 'get_assigned_vocabulary_units';
```

### New RPC Constant

```dart
static const getUserLearningPaths = 'get_user_learning_paths';
```

## File Impact Summary

| Layer | Files Affected | Action |
|-------|---------------|--------|
| SQL Migrations | 2 new | Create tables + RPC, drop old tables + RPCs |
| Shared Package | 2 | Add new constants, remove old |
| Admin Panel | 4 removed, 5+ new | New template + assignment screens |
| Mobile Entities | 3 | Update/create entities |
| Mobile Repositories | 2 | Update to use new RPC |
| Mobile Providers | 1 critical | Restructure learningPathProvider |
| Mobile Widgets | 2 | Minor — reads from providers |
| **Total** | ~19 files | |
