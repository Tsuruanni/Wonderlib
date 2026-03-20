# Learning Path Templates Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace separate Curriculum + Unit Books admin screens with a template-based learning path system that supports reusable templates, scope-based assignments, interleaved word list + book ordering, and multiple learning paths per scope.

**Architecture:** 6 new DB tables (symmetric template/scope structure), 2 new RPCs, 3 new admin screens sharing a tree-view widget, mobile app updated to consume a single unified RPC. Old tables and screens are removed entirely (no backward compat needed).

**Tech Stack:** PostgreSQL 17 (Supabase), Flutter, Riverpod, GoRouter, owlio_shared package

**Spec:** `docs/superpowers/specs/2026-03-20-learning-path-templates-design.md`

---

## Phase 1: Foundation (Database + Shared Package)

### Task 1: Create Learning Path Tables

**Files:**
- Create: `supabase/migrations/20260320000001_create_learning_path_tables.sql`

- [ ] **Step 1: Write the migration SQL**

```sql
-- =============================================
-- LEARNING PATH TEMPLATES & SCOPE ASSIGNMENTS
-- =============================================

-- 1. Template definition
CREATE TABLE learning_path_templates (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name        VARCHAR(255) NOT NULL,
  description TEXT,
  created_by  UUID REFERENCES profiles(id),
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TRIGGER update_learning_path_templates_updated_at
  BEFORE UPDATE ON learning_path_templates
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

ALTER TABLE learning_path_templates ENABLE ROW LEVEL SECURITY;

CREATE POLICY "admin_full_access" ON learning_path_templates
  FOR ALL USING (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('admin', 'head_teacher'))
  );

-- No authenticated_select: templates are admin-only. Mobile reads from scope tables.

-- 2. Template units (ordered)
CREATE TABLE learning_path_template_units (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  template_id UUID NOT NULL REFERENCES learning_path_templates(id) ON DELETE CASCADE,
  unit_id     UUID NOT NULL REFERENCES vocabulary_units(id) ON DELETE CASCADE,
  sort_order  INTEGER NOT NULL DEFAULT 0,
  UNIQUE(template_id, unit_id)
);

CREATE INDEX idx_lp_template_units_template ON learning_path_template_units(template_id);

ALTER TABLE learning_path_template_units ENABLE ROW LEVEL SECURITY;

CREATE POLICY "admin_full_access" ON learning_path_template_units
  FOR ALL USING (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('admin', 'head_teacher'))
  );

-- 3. Template items (word lists + books, interleaved)
CREATE TABLE learning_path_template_items (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  template_unit_id UUID NOT NULL REFERENCES learning_path_template_units(id) ON DELETE CASCADE,
  item_type        VARCHAR(20) NOT NULL CHECK (item_type IN ('word_list', 'book')),
  word_list_id     UUID REFERENCES word_lists(id) ON DELETE CASCADE,
  book_id          UUID REFERENCES books(id) ON DELETE CASCADE,
  sort_order       INTEGER NOT NULL DEFAULT 0,
  CHECK (
    (item_type = 'word_list' AND word_list_id IS NOT NULL AND book_id IS NULL) OR
    (item_type = 'book' AND book_id IS NOT NULL AND word_list_id IS NULL)
  )
);

CREATE INDEX idx_lp_template_items_unit ON learning_path_template_items(template_unit_id);

-- Partial unique indexes: prevent duplicate word lists or books within same unit
CREATE UNIQUE INDEX idx_lp_template_items_word_list
  ON learning_path_template_items(template_unit_id, word_list_id)
  WHERE word_list_id IS NOT NULL;

CREATE UNIQUE INDEX idx_lp_template_items_book
  ON learning_path_template_items(template_unit_id, book_id)
  WHERE book_id IS NOT NULL;

ALTER TABLE learning_path_template_items ENABLE ROW LEVEL SECURITY;

CREATE POLICY "admin_full_access" ON learning_path_template_items
  FOR ALL USING (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('admin', 'head_teacher'))
  );

-- No authenticated_select on template tables. Mobile reads from scope tables only.

-- 4. Scope learning path instance
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

CREATE TRIGGER update_scope_learning_paths_updated_at
  BEFORE UPDATE ON scope_learning_paths
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE INDEX idx_scope_lp_school ON scope_learning_paths(school_id);
CREATE INDEX idx_scope_lp_school_grade ON scope_learning_paths(school_id, grade) WHERE grade IS NOT NULL;
CREATE INDEX idx_scope_lp_class ON scope_learning_paths(class_id) WHERE class_id IS NOT NULL;

ALTER TABLE scope_learning_paths ENABLE ROW LEVEL SECURITY;

CREATE POLICY "admin_full_access" ON scope_learning_paths
  FOR ALL USING (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('admin', 'head_teacher'))
  );

CREATE POLICY "authenticated_select" ON scope_learning_paths
  FOR SELECT USING (auth.role() = 'authenticated');

-- 5. Scope learning path units (ordered)
CREATE TABLE scope_learning_path_units (
  id                     UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  scope_learning_path_id UUID NOT NULL REFERENCES scope_learning_paths(id) ON DELETE CASCADE,
  unit_id                UUID NOT NULL REFERENCES vocabulary_units(id) ON DELETE CASCADE,
  sort_order             INTEGER NOT NULL DEFAULT 0,
  UNIQUE(scope_learning_path_id, unit_id)
);

CREATE INDEX idx_scope_lp_units_path ON scope_learning_path_units(scope_learning_path_id);

ALTER TABLE scope_learning_path_units ENABLE ROW LEVEL SECURITY;

CREATE POLICY "admin_full_access" ON scope_learning_path_units
  FOR ALL USING (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('admin', 'head_teacher'))
  );

CREATE POLICY "authenticated_select" ON scope_learning_path_units
  FOR SELECT USING (auth.role() = 'authenticated');

-- 6. Scope unit items (word lists + books, interleaved)
CREATE TABLE scope_unit_items (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  scope_lp_unit_id UUID NOT NULL REFERENCES scope_learning_path_units(id) ON DELETE CASCADE,
  item_type        VARCHAR(20) NOT NULL CHECK (item_type IN ('word_list', 'book')),
  word_list_id     UUID REFERENCES word_lists(id) ON DELETE CASCADE,
  book_id          UUID REFERENCES books(id) ON DELETE CASCADE,
  sort_order       INTEGER NOT NULL DEFAULT 0,
  CHECK (
    (item_type = 'word_list' AND word_list_id IS NOT NULL AND book_id IS NULL) OR
    (item_type = 'book' AND book_id IS NOT NULL AND word_list_id IS NULL)
  )
);

CREATE INDEX idx_scope_unit_items_unit ON scope_unit_items(scope_lp_unit_id);

-- Partial unique indexes: prevent duplicate word lists or books within same unit
CREATE UNIQUE INDEX idx_scope_unit_items_word_list
  ON scope_unit_items(scope_lp_unit_id, word_list_id)
  WHERE word_list_id IS NOT NULL;

CREATE UNIQUE INDEX idx_scope_unit_items_book
  ON scope_unit_items(scope_lp_unit_id, book_id)
  WHERE book_id IS NOT NULL;

ALTER TABLE scope_unit_items ENABLE ROW LEVEL SECURITY;

CREATE POLICY "admin_full_access" ON scope_unit_items
  FOR ALL USING (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('admin', 'head_teacher'))
  );

CREATE POLICY "authenticated_select" ON scope_unit_items
  FOR SELECT USING (auth.role() = 'authenticated');
```

- [ ] **Step 2: Preview migration**

Run: `supabase db push --dry-run`
Expected: Shows 6 tables to be created, no errors

- [ ] **Step 3: Push migration**

Run: `supabase db push`
Expected: Migration applied successfully

- [ ] **Step 4: Commit**

```bash
git add supabase/migrations/20260320000001_create_learning_path_tables.sql
git commit -m "feat(db): create learning path template and scope tables"
```

---

### Task 2: Create RPC Functions

**Files:**
- Create: `supabase/migrations/20260320000002_create_learning_path_rpcs.sql`

- [ ] **Step 1: Write the apply template RPC**

```sql
-- Atomically copies a template into scope tables
CREATE OR REPLACE FUNCTION apply_learning_path_template(
  p_template_id UUID,
  p_school_id   UUID,
  p_grade       INTEGER DEFAULT NULL,
  p_class_id    UUID DEFAULT NULL,
  p_user_id     UUID DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_scope_lp_id UUID;
  v_template_name VARCHAR;
  v_template_unit RECORD;
  v_scope_unit_id UUID;
  v_item RECORD;
BEGIN
  -- Get template name
  SELECT name INTO v_template_name
  FROM learning_path_templates
  WHERE id = p_template_id;

  IF v_template_name IS NULL THEN
    RAISE EXCEPTION 'Template not found: %', p_template_id;
  END IF;

  -- Create scope learning path
  INSERT INTO scope_learning_paths (name, template_id, school_id, grade, class_id, sort_order, created_by)
  VALUES (
    v_template_name,
    p_template_id,
    p_school_id,
    p_grade,
    p_class_id,
    COALESCE(
      (SELECT MAX(sort_order) + 1 FROM scope_learning_paths
       WHERE school_id = p_school_id
         AND grade IS NOT DISTINCT FROM p_grade
         AND class_id IS NOT DISTINCT FROM p_class_id),
      0
    ),
    p_user_id
  )
  RETURNING id INTO v_scope_lp_id;

  -- Copy template units
  FOR v_template_unit IN
    SELECT id, unit_id, sort_order
    FROM learning_path_template_units
    WHERE template_id = p_template_id
    ORDER BY sort_order
  LOOP
    INSERT INTO scope_learning_path_units (scope_learning_path_id, unit_id, sort_order)
    VALUES (v_scope_lp_id, v_template_unit.unit_id, v_template_unit.sort_order)
    RETURNING id INTO v_scope_unit_id;

    -- Copy items for this unit
    FOR v_item IN
      SELECT item_type, word_list_id, book_id, sort_order
      FROM learning_path_template_items
      WHERE template_unit_id = v_template_unit.id
      ORDER BY sort_order
    LOOP
      INSERT INTO scope_unit_items (scope_lp_unit_id, item_type, word_list_id, book_id, sort_order)
      VALUES (v_scope_unit_id, v_item.item_type, v_item.word_list_id, v_item.book_id, v_item.sort_order);
    END LOOP;
  END LOOP;

  RETURN v_scope_lp_id;
END;
$$;
```

- [ ] **Step 2: Write the get_user_learning_paths RPC**

```sql
-- Returns complete learning path structure for a user.
-- Scope resolution: UNION of all matching scopes (class + grade + school-wide).
CREATE OR REPLACE FUNCTION get_user_learning_paths(p_user_id UUID)
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
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_school_id UUID;
  v_grade INTEGER;
  v_class_id UUID;
BEGIN
  -- Get user's school, grade, and class
  SELECT p.school_id, c.grade, p.class_id
  INTO v_school_id, v_grade, v_class_id
  FROM profiles p
  LEFT JOIN classes c ON c.id = p.class_id
  WHERE p.id = p_user_id;

  IF v_school_id IS NULL THEN
    RETURN; -- No school, no learning paths
  END IF;

  RETURN QUERY
  SELECT
    slp.id AS learning_path_id,
    slp.name::VARCHAR AS learning_path_name,
    slp.sort_order AS lp_sort_order,
    vu.id AS unit_id,
    vu.name::VARCHAR AS unit_name,
    vu.color::VARCHAR AS unit_color,
    vu.icon::VARCHAR AS unit_icon,
    slpu.sort_order AS unit_sort_order,
    sui.item_type::VARCHAR AS item_type,
    COALESCE(sui.word_list_id, sui.book_id) AS item_id,
    sui.sort_order AS item_sort_order
  FROM scope_learning_paths slp
  JOIN scope_learning_path_units slpu ON slpu.scope_learning_path_id = slp.id
  JOIN vocabulary_units vu ON vu.id = slpu.unit_id
  LEFT JOIN scope_unit_items sui ON sui.scope_lp_unit_id = slpu.id
  WHERE slp.school_id = v_school_id
    AND (
      -- School-wide (no grade, no class)
      (slp.grade IS NULL AND slp.class_id IS NULL)
      -- Grade-level
      OR (slp.grade = v_grade AND slp.class_id IS NULL)
      -- Class-specific
      OR (slp.class_id = v_class_id)
    )
    AND vu.is_active = true
  ORDER BY slp.sort_order, slpu.sort_order, sui.sort_order;
END;
$$;
```

- [ ] **Step 3: Preview and push**

Run: `supabase db push --dry-run` then `supabase db push`
Expected: 2 RPC functions created

- [ ] **Step 4: Commit**

```bash
git add supabase/migrations/20260320000002_create_learning_path_rpcs.sql
git commit -m "feat(db): add learning path RPC functions"
```

---

### Task 3: Drop Old Tables and RPCs

**Files:**
- Create: `supabase/migrations/20260320000003_drop_old_assignment_tables.sql`

- [ ] **Step 1: Write the drop migration**

```sql
-- Drop old RPC functions
DROP FUNCTION IF EXISTS get_assigned_vocabulary_units(UUID);
DROP FUNCTION IF EXISTS get_user_unit_books(UUID);

-- Drop old tables (CASCADE drops RLS policies, indexes, triggers)
DROP TABLE IF EXISTS unit_book_assignments CASCADE;
DROP TABLE IF EXISTS unit_curriculum_assignments CASCADE;
```

- [ ] **Step 2: Preview and push**

Run: `supabase db push --dry-run` then `supabase db push`
Expected: 2 tables and 2 functions dropped

- [ ] **Step 3: Commit**

```bash
git add supabase/migrations/20260320000003_drop_old_assignment_tables.sql
git commit -m "feat(db): drop old unit_curriculum_assignments and unit_book_assignments"
```

---

### Task 4: Update Shared Package

**Files:**
- Modify: `packages/owlio_shared/lib/src/constants/tables.dart`
- Modify: `packages/owlio_shared/lib/src/constants/rpc_functions.dart`
- Create: `packages/owlio_shared/lib/src/enums/learning_path_item_type.dart`
- Modify: `packages/owlio_shared/lib/owlio_shared.dart`

- [ ] **Step 1: Update tables.dart — add new constants**

Add to the vocabulary section of `DbTables`:

```dart
// Learning path templates
static const learningPathTemplates = 'learning_path_templates';
static const learningPathTemplateUnits = 'learning_path_template_units';
static const learningPathTemplateItems = 'learning_path_template_items';

// Learning path scope assignments
static const scopeLearningPaths = 'scope_learning_paths';
static const scopeLearningPathUnits = 'scope_learning_path_units';
static const scopeUnitItems = 'scope_unit_items';
```

- [ ] **Step 2: Update rpc_functions.dart — add new constants**

Add:
```dart
// Learning paths
static const getUserLearningPaths = 'get_user_learning_paths';
static const applyLearningPathTemplate = 'apply_learning_path_template';
```

**Do NOT remove old constants yet** (`unitBookAssignments`, `unitCurriculumAssignments`, `getUserUnitBooks`, `getAssignedVocabularyUnits`). They will be removed in Task 14 (final cleanup) to avoid a cross-phase compilation break window.

- [ ] **Step 4: Create LearningPathItemType enum**

Create file `packages/owlio_shared/lib/src/enums/learning_path_item_type.dart`:

```dart
enum LearningPathItemType {
  wordList('word_list', 'Word List'),
  book('book', 'Book');

  final String dbValue;
  final String displayName;

  const LearningPathItemType(this.dbValue, this.displayName);

  static LearningPathItemType fromDbValue(String value) {
    return LearningPathItemType.values.firstWhere(
      (e) => e.dbValue == value,
      orElse: () => LearningPathItemType.wordList,
    );
  }
}
```

- [ ] **Step 5: Update barrel export**

Add to `packages/owlio_shared/lib/owlio_shared.dart`:
```dart
export 'src/enums/learning_path_item_type.dart';
```

- [ ] **Step 6: Verify compilation**

Run: `cd packages/owlio_shared && dart analyze`
Expected: No issues found

- [ ] **Step 7: Verify compilation of all projects**

Run: `cd packages/owlio_shared && dart analyze` and `cd owlio_admin && dart analyze lib/` and `dart analyze lib/`
Expected: No issues in any project (old constants are kept for now)

- [ ] **Step 8: Commit**

```bash
git add packages/owlio_shared/
git commit -m "feat(shared): add learning path constants and enum, remove old assignment constants"
```

---

## Phase 2: Admin Panel

### Task 5: Create Shared LearningPathTreeView Widget

**Files:**
- Create: `owlio_admin/lib/core/widgets/learning_path_tree_view.dart`

This is the shared widget used by both template edit and assignment screens. It renders the tree structure of units + items with drag-drop and CRUD controls.

- [ ] **Step 1: Create the widget file**

Create `owlio_admin/lib/core/widgets/learning_path_tree_view.dart` with:

**Data classes:**
```dart
class LearningPathUnitData {
  final String? id; // null for new units
  final String unitId;
  final String unitName;
  final String? unitIcon;
  final String? unitColor;
  final int sortOrder;
  final List<LearningPathItemData> items;
}

class LearningPathItemData {
  final String? id; // null for new items
  final String itemType; // 'word_list' or 'book'
  final String itemId;
  final String itemName;
  final String? subtitle; // e.g. "5 kelime" or "A1 · 4 bölüm"
  final int sortOrder;
  final List<String>? words; // word preview for word_list items
}
```

**Widget: `LearningPathTreeView`**
- Parameters: `List<LearningPathUnitData> units`, callbacks for `onUnitReorder`, `onUnitRemove`, `onUnitAdd`, `onItemReorder`, `onItemRemove`, `onItemAdd(unitIndex, itemType)`, `bool showWordPreview`, `bool readOnly`
- Renders each unit as an expandable card with drag handle
- Within each unit, renders items with drag handles, type icon (📝/📖), name, subtitle
- Word preview: expandable row under word_list items showing comma-separated words
- Add buttons: `[+ Kelime Listesi Ekle]` `[+ Kitap Ekle]` at bottom of each unit
- `[+ Ünite Ekle]` at bottom of the tree
- Uses `ReorderableListView` for unit ordering
- Uses `ReorderableListView` nested for item ordering within each unit

**Helper: `_parseColor(String? hex)`** — reuse the existing hex color parser pattern from unit screens.

- [ ] **Step 2: Create word list search dialog**

Add to the same file or as a private widget:

```dart
void showWordListPicker(BuildContext context, WidgetRef ref, {
  required Set<String> excludeIds,
  required void Function(Map<String, dynamic> wordList) onSelect,
})
```

- Searches `DbTables.wordLists` by name (ilike)
- Shows word count, first few words preview
- Excludes already-selected word lists

**Helper: `showBookPicker`** — similar pattern, searches `DbTables.books` where `status = published` and `chapter_count > 0`.

**Helper: `showUnitPicker`** — searches `DbTables.vocabularyUnits` where `is_active = true`.

- [ ] **Step 3: Verify widget compiles**

Run: `cd owlio_admin && dart analyze lib/core/widgets/learning_path_tree_view.dart`
Expected: No issues

- [ ] **Step 4: Commit**

```bash
git add owlio_admin/lib/core/widgets/learning_path_tree_view.dart
git commit -m "feat(admin): add LearningPathTreeView shared widget"
```

---

### Task 6: Template List Screen

**Files:**
- Create: `owlio_admin/lib/features/templates/screens/template_list_screen.dart`

- [ ] **Step 1: Create the screen**

Follow existing list screen patterns (e.g., `unit_list_screen.dart`).

**Provider:**
```dart
final templatesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final supabase = ref.watch(supabaseClientProvider);
  final response = await supabase
      .from(DbTables.learningPathTemplates)
      .select('id, name, description, created_at')
      .order('created_at', ascending: false);
  return List<Map<String, dynamic>>.from(response);
});
```

**Stats provider** (for unit/item counts per template):
```dart
final templateStatsProvider = FutureProvider.family<Map<String, int>, String>((ref, templateId) async {
  final supabase = ref.watch(supabaseClientProvider);
  final units = await supabase
      .from(DbTables.learningPathTemplateUnits)
      .select('id')
      .eq('template_id', templateId);
  final items = await supabase
      .from(DbTables.learningPathTemplateItems)
      .select('item_type, template_unit_id')
      .inFilter('template_unit_id', units.map((u) => u['id'] as String).toList());
  return {
    'units': units.length,
    'word_lists': items.where((i) => i['item_type'] == 'word_list').length,
    'books': items.where((i) => i['item_type'] == 'book').length,
  };
});
```

**UI:**
- AppBar: "Öğrenme Yolu Şablonları" + [+ Yeni Şablon] button
- Back arrow → `/`
- Card list showing: name, description, stats badges ("3 ünite · 12 kelime listesi · 5 kitap")
- Tap card → `/templates/:id`
- Delete button per card (with confirmation dialog)

- [ ] **Step 2: Verify compilation**

Run: `cd owlio_admin && dart analyze lib/features/templates/`
Expected: No issues

- [ ] **Step 3: Commit**

```bash
git add owlio_admin/lib/features/templates/
git commit -m "feat(admin): add template list screen"
```

---

### Task 7: Template Edit Screen

**Files:**
- Create: `owlio_admin/lib/features/templates/screens/template_edit_screen.dart`

- [ ] **Step 1: Create the screen**

**State:**
```dart
class _TemplateEditScreenState extends ConsumerState<TemplateEditScreen> {
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  List<LearningPathUnitData> _units = [];
  bool _isLoading = false;
  bool _isSaving = false;
}
```

**Load existing template:**
- Query `learning_path_templates` for name/description
- Query `learning_path_template_units` ordered by sort_order
- For each unit, query `learning_path_template_items` ordered by sort_order
- For word_list items, also fetch word preview from `word_list_items` joined with `vocabulary_words`

**Save logic:**
- Upsert template name/description to `learning_path_templates`
- Delete all existing `learning_path_template_units` for this template (cascade deletes items)
- Re-insert all units and items with new sort_orders

**UI layout:**
- AppBar: template name + [Kaydet] + [Sil] (if editing)
- Top form section: name input + description textarea
- Body: `LearningPathTreeView` widget with full editing enabled

- [ ] **Step 2: Wire up the callbacks**

Each `LearningPathTreeView` callback maps to:
- `onUnitAdd`: show `showUnitPicker` dialog → add to `_units`
- `onUnitRemove(index)`: remove from `_units` with confirmation
- `onUnitReorder(oldIndex, newIndex)`: reorder `_units`
- `onItemAdd(unitIndex, itemType)`: show `showWordListPicker` or `showBookPicker` → add to `_units[unitIndex].items`
- `onItemRemove(unitIndex, itemIndex)`: remove from items
- `onItemReorder(unitIndex, oldIndex, newIndex)`: reorder items within unit

- [ ] **Step 3: Verify compilation**

Run: `cd owlio_admin && dart analyze lib/features/templates/`
Expected: No issues

- [ ] **Step 4: Commit**

```bash
git add owlio_admin/lib/features/templates/
git commit -m "feat(admin): add template edit screen with tree-view editor"
```

---

### Task 8: Learning Path Assignment Screen

**Files:**
- Create: `owlio_admin/lib/features/learning_path_assignments/screens/assignment_screen.dart`

- [ ] **Step 1: Create the screen with scope selection**

**State:**
```dart
class _AssignmentScreenState extends ConsumerState<AssignmentScreen> {
  String? _schoolId;
  _ScopeType _scopeType = _ScopeType.grade;
  int? _selectedGrade;
  String? _selectedClassId;
  List<_ScopeLearningPathData> _learningPaths = [];
  bool _isLoading = false;
  bool _isSaving = false;
}

class _ScopeLearningPathData {
  String? id; // null for new
  String name;
  String? templateId;
  int sortOrder;
  List<LearningPathUnitData> units;
}
```

**Scope selection UI:** Reuse the existing pattern from `curriculum_edit_screen.dart`:
- School dropdown (from `allSchoolsProvider`)
- Scope type radio buttons (Tüm Okul / Sınıf / Şube)
- Grade dropdown or Class dropdown depending on scope type
- On scope change: load existing `scope_learning_paths` for this scope

**Load existing assignments:**
```dart
Future<void> _loadScopeAssignments() async {
  // Query scope_learning_paths matching school + grade/class
  // For each, query scope_learning_path_units + scope_unit_items
  // Build _learningPaths list
}
```

- [ ] **Step 2: Add template application**

"Şablondan Ekle" button:
- Shows dialog listing all templates from `templatesProvider`
- On select: calls `apply_learning_path_template` RPC
- Reloads the scope assignments to show the new path

"Boş Öğrenme Yolu Ekle" button:
- Creates a new `_ScopeLearningPathData` with empty units
- User names it inline

- [ ] **Step 3: Add inline editing with LearningPathTreeView**

Each learning path in `_learningPaths` renders a `LearningPathTreeView`. Same callbacks as template edit, but writes to `scope_*` tables.

**Save logic per learning path:**
- If new: INSERT into `scope_learning_paths`, then units, then items
- If existing: DELETE all `scope_learning_path_units` (cascade), re-insert

**Delete learning path:** DELETE from `scope_learning_paths` (cascade cleans everything)

- [ ] **Step 4: Verify compilation**

Run: `cd owlio_admin && dart analyze lib/features/learning_path_assignments/`
Expected: No issues

- [ ] **Step 5: Commit**

```bash
git add owlio_admin/lib/features/learning_path_assignments/
git commit -m "feat(admin): add learning path assignment screen"
```

---

### Task 9: Router, Dashboard, and Cleanup

**Files:**
- Modify: `owlio_admin/lib/core/router.dart`
- Modify: `owlio_admin/lib/features/dashboard/screens/dashboard_screen.dart`
- Modify: `owlio_admin/lib/features/wordlists/screens/wordlist_edit_screen.dart`
- Delete: `owlio_admin/lib/features/curriculum/` (entire directory)
- Delete: `owlio_admin/lib/features/unit_books/` (entire directory)

- [ ] **Step 1: Update router.dart**

Remove imports and routes for curriculum and unit_books. Add new routes:

```dart
// Remove these imports:
import '../features/curriculum/screens/curriculum_edit_screen.dart';
import '../features/curriculum/screens/curriculum_list_screen.dart';
import '../features/unit_books/screens/unit_books_list_screen.dart';
import '../features/unit_books/screens/unit_books_edit_screen.dart';

// Add these imports:
import '../features/templates/screens/template_list_screen.dart';
import '../features/templates/screens/template_edit_screen.dart';
import '../features/learning_path_assignments/screens/assignment_screen.dart';

// Remove old routes:
// /curriculum, /curriculum/new, /curriculum/:assignmentId
// /unit-books, /unit-books/new

// Add new routes:
GoRoute(
  path: '/templates',
  builder: (context, state) => const TemplateListScreen(),
),
GoRoute(
  path: '/templates/new',
  builder: (context, state) => const TemplateEditScreen(),
),
GoRoute(
  path: '/templates/:templateId',
  builder: (context, state) => TemplateEditScreen(
    templateId: state.pathParameters['templateId'],
  ),
),
GoRoute(
  path: '/learning-path-assignments',
  builder: (context, state) => const AssignmentScreen(),
),
```

- [ ] **Step 2: Update dashboard_screen.dart**

Replace the two old cards (lines ~157-169):

```dart
// Old:
_DashboardCard(
  icon: Icons.assignment_outlined,
  title: 'Ünite Atamaları',
  description: 'Kelime listesi ünitelerini okul ve sınıflara ata',
  color: const Color(0xFFEA580C),
  onTap: () => context.go('/curriculum'),
),
_DashboardCard(
  icon: Icons.auto_stories,
  title: 'Ünite Kitapları',
  description: 'Okul bazında ünitelere kitap ata',
  color: const Color(0xFF1565C0),
  onTap: () => context.go('/unit-books'),
),

// New:
_DashboardCard(
  icon: Icons.route,
  title: 'Öğrenme Yolu Şablonları',
  description: 'Tekrar kullanılabilir öğrenme yolları oluştur',
  color: const Color(0xFFEA580C),
  onTap: () => context.go('/templates'),
),
_DashboardCard(
  icon: Icons.school,
  title: 'Öğrenme Yolu Ataması',
  description: 'Şablonları okul ve sınıflara ata',
  color: const Color(0xFF1565C0),
  onTap: () => context.go('/learning-path-assignments'),
),
```

- [ ] **Step 3: Clean up wordlist_edit_screen.dart**

Remove the "Ünite Ataması" section that writes `unit_id` and `order_in_unit` to word_lists. This section is no longer needed since unit membership is defined by templates/scopes.

Find and remove:
- The `_unitId` state variable and its usage
- The `_orderInUnit` state variable and its usage
- The unit dropdown UI section
- The `unit_id` and `order_in_unit` fields from the save data map

- [ ] **Step 4: Relocate shared providers BEFORE deleting old directories**

**CRITICAL:** `allVocabularyUnitsProvider` is defined in `curriculum_edit_screen.dart` but imported by `wordlist_edit_screen.dart` and `wordlist_list_screen.dart`. It must be moved BEFORE deleting the curriculum directory.

Move `allVocabularyUnitsProvider` to `owlio_admin/lib/core/providers/shared_providers.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:owlio_shared/owlio_shared.dart';
import '../supabase_client.dart';

/// All active vocabulary units (used across multiple features)
final allVocabularyUnitsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final supabase = ref.watch(supabaseClientProvider);
  final response = await supabase
      .from(DbTables.vocabularyUnits)
      .select('id, name, sort_order, color, icon, is_active')
      .eq('is_active', true)
      .order('sort_order', ascending: true);
  return List<Map<String, dynamic>>.from(response);
});
```

Also move `schoolClassesProvider` (defined in both `curriculum_edit_screen.dart` and `unit_books_edit_screen.dart`) to the same file.

Update all imports in `wordlist_edit_screen.dart`, `wordlist_list_screen.dart`, and any other files that imported these from old locations.

- [ ] **Step 5: Delete old feature directories**

```bash
rm -rf owlio_admin/lib/features/curriculum/
rm -rf owlio_admin/lib/features/unit_books/
```

- [ ] **Step 6: Fix any remaining import errors**

Search for broken imports:

Run: `cd owlio_admin && dart analyze lib/`
Expected: No issues

- [ ] **Step 6: Verify the admin panel runs**

Run: `cd owlio_admin && flutter run -d chrome`
Expected: Dashboard loads, new cards visible, old routes gone, template and assignment screens accessible

- [ ] **Step 7: Commit**

```bash
git add -A owlio_admin/
git commit -m "feat(admin): wire up new screens, remove old curriculum and unit_books screens"
```

---

## Phase 3: Mobile App

### Task 10: Update Mobile Entities and Models

**Files:**
- Create: `lib/domain/entities/learning_path.dart`
- Create: `lib/domain/entities/learning_path_item.dart`
- Modify: `lib/domain/entities/word_list.dart`
- Create: `lib/data/models/vocabulary/learning_path_model.dart`
- Modify: `lib/data/models/book/unit_book_model.dart` (or replace)

- [ ] **Step 1: Create LearningPath entity**

```dart
// lib/domain/entities/learning_path.dart
import 'package:equatable/equatable.dart';
import 'learning_path_item.dart';
import 'vocabulary_unit.dart';

class LearningPath extends Equatable {
  final String id;
  final String name;
  final int sortOrder;
  final List<LearningPathUnit> units;

  const LearningPath({
    required this.id,
    required this.name,
    required this.sortOrder,
    required this.units,
  });

  @override
  List<Object?> get props => [id, name, sortOrder, units];
}

class LearningPathUnit extends Equatable {
  final String unitId;
  final String unitName;
  final String? unitColor;
  final String? unitIcon;
  final int sortOrder;
  final List<LearningPathItem> items;

  const LearningPathUnit({
    required this.unitId,
    required this.unitName,
    this.unitColor,
    this.unitIcon,
    required this.sortOrder,
    required this.items,
  });

  @override
  List<Object?> get props => [unitId, unitName, unitColor, unitIcon, sortOrder, items];
}
```

- [ ] **Step 2: Create LearningPathItem entity**

```dart
// lib/domain/entities/learning_path_item.dart
import 'package:equatable/equatable.dart';
import 'package:owlio_shared/owlio_shared.dart';

class LearningPathItem extends Equatable {
  final LearningPathItemType itemType;
  final String itemId;
  final int sortOrder;

  const LearningPathItem({
    required this.itemType,
    required this.itemId,
    required this.sortOrder,
  });

  @override
  List<Object?> get props => [itemType, itemId, sortOrder];
}
```

- [ ] **Step 3: Create LearningPathModel for RPC deserialization**

```dart
// lib/data/models/vocabulary/learning_path_model.dart
import 'package:owlio_shared/owlio_shared.dart';
import '../../../domain/entities/learning_path.dart';
import '../../../domain/entities/learning_path_item.dart';

class LearningPathModel {
  /// Parses flat RPC rows into hierarchical LearningPath list
  static List<LearningPath> fromRpcRows(List<Map<String, dynamic>> rows) {
    final pathMap = <String, _PathBuilder>{};

    for (final row in rows) {
      final lpId = row['learning_path_id'] as String;
      final pathBuilder = pathMap.putIfAbsent(lpId, () => _PathBuilder(
        id: lpId,
        name: row['learning_path_name'] as String,
        sortOrder: row['lp_sort_order'] as int,
      ));

      final unitId = row['unit_id'] as String;
      final unitBuilder = pathBuilder.units.putIfAbsent(unitId, () => _UnitBuilder(
        unitId: unitId,
        unitName: row['unit_name'] as String,
        unitColor: row['unit_color'] as String?,
        unitIcon: row['unit_icon'] as String?,
        sortOrder: row['unit_sort_order'] as int,
      ));

      final itemType = row['item_type'] as String?;
      final itemId = row['item_id'] as String?;
      if (itemType != null && itemId != null) {
        unitBuilder.items.add(LearningPathItem(
          itemType: LearningPathItemType.fromDbValue(itemType),
          itemId: itemId,
          sortOrder: row['item_sort_order'] as int? ?? 0,
        ));
      }
    }

    return pathMap.values
        .map((pb) => LearningPath(
              id: pb.id,
              name: pb.name,
              sortOrder: pb.sortOrder,
              units: pb.units.values
                  .map((ub) => LearningPathUnit(
                        unitId: ub.unitId,
                        unitName: ub.unitName,
                        unitColor: ub.unitColor,
                        unitIcon: ub.unitIcon,
                        sortOrder: ub.sortOrder,
                        items: ub.items..sort((a, b) => a.sortOrder.compareTo(b.sortOrder)),
                      ))
                  .toList()
                ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder)),
            ))
        .toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  }
}

class _PathBuilder {
  final String id;
  final String name;
  final int sortOrder;
  final Map<String, _UnitBuilder> units = {};
  _PathBuilder({required this.id, required this.name, required this.sortOrder});
}

class _UnitBuilder {
  final String unitId;
  final String unitName;
  final String? unitColor;
  final String? unitIcon;
  final int sortOrder;
  final List<LearningPathItem> items = [];
  _UnitBuilder({required this.unitId, required this.unitName, this.unitColor, this.unitIcon, required this.sortOrder});
}
```

- [ ] **Step 4: Verify compilation**

Run: `dart analyze lib/domain/entities/learning_path.dart lib/domain/entities/learning_path_item.dart lib/data/models/vocabulary/learning_path_model.dart`
Expected: No issues

- [ ] **Step 5: Commit**

```bash
git add lib/domain/entities/learning_path.dart lib/domain/entities/learning_path_item.dart lib/data/models/vocabulary/learning_path_model.dart
git commit -m "feat: add LearningPath entity and model for new RPC"
```

---

### Task 11: Update Mobile Repository and UseCase

**Files:**
- Modify: `lib/domain/repositories/word_list_repository.dart`
- Modify: `lib/domain/repositories/book_repository.dart`
- Create: `lib/domain/usecases/wordlist/get_user_learning_paths_usecase.dart`
- Modify: `lib/data/repositories/supabase/supabase_word_list_repository.dart`
- Modify: `lib/data/repositories/supabase/supabase_book_repository.dart`

- [ ] **Step 1: Add new method to WordListRepository interface**

In `lib/domain/repositories/word_list_repository.dart`, add:
```dart
Future<Either<Failure, List<LearningPath>>> getUserLearningPaths(String userId);
```

Remove (or keep for now — will break compilation):
```dart
Future<Either<Failure, List<VocabularyUnit>>> getAssignedVocabularyUnits(String userId);
```

- [ ] **Step 2: Create GetUserLearningPathsUseCase**

```dart
// lib/domain/usecases/wordlist/get_user_learning_paths_usecase.dart
class GetUserLearningPathsUseCase implements UseCase<List<LearningPath>, String> {
  final WordListRepository _repository;
  const GetUserLearningPathsUseCase(this._repository);

  @override
  Future<Either<Failure, List<LearningPath>>> call(String userId) {
    return _repository.getUserLearningPaths(userId);
  }
}
```

- [ ] **Step 3: Implement in supabase_word_list_repository.dart**

Replace `getAssignedVocabularyUnits` with:
```dart
@override
Future<Either<Failure, List<LearningPath>>> getUserLearningPaths(String userId) async {
  try {
    final response = await _supabase.rpc(
      RpcFunctions.getUserLearningPaths,
      params: {'p_user_id': userId},
    );
    final rows = List<Map<String, dynamic>>.from(response);
    return Right(LearningPathModel.fromRpcRows(rows));
  } catch (e) {
    return Left(ServerFailure(message: e.toString()));
  }
}
```

- [ ] **Step 4: Remove getUnitBooks from book_repository**

Remove `getUnitBooks` method from:
- `lib/domain/repositories/book_repository.dart` (interface)
- `lib/data/repositories/supabase/supabase_book_repository.dart` (implementation)
- `lib/data/repositories/cached/cached_book_repository.dart` (cache wrapper)
- `lib/domain/usecases/book/get_unit_books_usecase.dart` (delete file)

- [ ] **Step 5: Verify compilation of domain + data layers**

Run: `dart analyze lib/domain/ lib/data/`
Expected: Errors only in presentation layer (providers referencing old code)

- [ ] **Step 6: Commit**

```bash
git add lib/domain/ lib/data/
git commit -m "feat: add getUserLearningPaths repository and usecase, remove old assignment methods"
```

---

### Task 12: Update Mobile Providers

**Files:**
- Modify: `lib/presentation/providers/usecase_providers.dart`
- Modify: `lib/presentation/providers/vocabulary_provider.dart`

- [ ] **Step 1: Update usecase_providers.dart**

Add:
```dart
final getUserLearningPathsUseCaseProvider = Provider<GetUserLearningPathsUseCase>((ref) {
  return GetUserLearningPathsUseCase(ref.watch(wordListRepositoryProvider));
});
```

Remove:
```dart
// Remove getAssignedVocabularyUnitsUseCaseProvider
// Remove getUnitBooksUseCaseProvider
```

- [ ] **Step 2: Update vocabulary_provider.dart — new unified provider**

Replace `vocabularyUnitsProvider` + `unitBooksProvider` + the word list grouping logic in `learningPathProvider` with a single unified provider:

```dart
final userLearningPathsProvider = FutureProvider<List<LearningPath>>((ref) async {
  final user = ref.watch(currentUserProvider).value;
  if (user == null) return [];
  final useCase = ref.watch(getUserLearningPathsUseCaseProvider);
  final result = await useCase(user.id);
  return result.fold((_) => [], (paths) => paths);
});
```

- [ ] **Step 3: Restructure learningPathProvider**

The `learningPathProvider` needs to be rewritten to:
1. Read from `userLearningPathsProvider` (replaces 3 separate providers)
2. For each learning path → for each unit → for each item:
   - If `item_type == word_list`: fetch word list details + progress
   - If `item_type == book`: fetch book details + completion status
3. Build `List<PathUnitData>` with items in sort_order (interleaved)

This is the most complex change. The existing `PathUnitData` and `PathRowData` structures will need to accommodate mixed item types in the order specified by sort_order.

- [ ] **Step 4: Remove old providers**

Remove:
- `vocabularyUnitsProvider` (replaced by `userLearningPathsProvider`)
- `unitBooksProvider` (replaced by `userLearningPathsProvider`)

- [ ] **Step 5: Verify compilation**

Run: `dart analyze lib/presentation/providers/`
Expected: Errors only in widget layer

- [ ] **Step 6: Commit**

```bash
git add lib/presentation/providers/
git commit -m "feat: restructure vocabulary providers for learning path system"
```

---

### Task 13: Update Mobile Widgets and Screens

**Files:**
- Modify: `lib/presentation/widgets/vocabulary/learning_path.dart`
- Modify: `lib/presentation/widgets/vocabulary/path_special_nodes.dart`
- Modify: `lib/presentation/widgets/vocabulary/path_row.dart`
- Modify: `lib/presentation/screens/vocabulary/vocabulary_hub_screen.dart` (only if provider name changes)
- Modify: `lib/presentation/screens/vocabulary/session_summary_screen.dart` (references `learningPathProvider`)

- [ ] **Step 1: Update LearningPath widget**

The `LearningPath` widget needs to:
- Accept multiple learning paths (from `userLearningPathsProvider`)
- Render each learning path as a named section
- Within each learning path, render units with their items in sort_order
- Items can be word lists OR books in any order (no longer "books at the end")

- [ ] **Step 2: Update PathBookNode in path_special_nodes.dart**

`PathBookNode` should work with the new `LearningPathItem` entity instead of `UnitBook`.

- [ ] **Step 3: Update path_row.dart**

`PathRowData` should support mixed item types. Each row can be a word list node or a book node.

- [ ] **Step 4: Update vocabulary_hub_screen.dart**

Minor change — use updated `userLearningPathsProvider` instead of `learningPathProvider` if the provider name changed.

- [ ] **Step 5: Full compilation check**

Run: `dart analyze lib/`
Expected: 0 issues

- [ ] **Step 6: Run the app**

Run: `flutter run -d chrome`
Expected: Vocabulary hub loads, learning path renders with units and mixed items

- [ ] **Step 7: Commit**

```bash
git add lib/presentation/
git commit -m "feat: update learning path widgets for new interleaved item system"
```

---

### Task 14: Final Cleanup

**Files:**
- Delete: `lib/domain/usecases/book/get_unit_books_usecase.dart`
- Delete: `lib/domain/usecases/wordlist/get_assigned_vocabulary_units_usecase.dart`
- Delete: `lib/data/models/book/unit_book_model.dart`
- Delete: `lib/domain/entities/unit_book.dart`
- Modify: `packages/owlio_shared/lib/src/constants/tables.dart`
- Modify: `packages/owlio_shared/lib/src/constants/rpc_functions.dart`

- [ ] **Step 1: Remove deprecated Dart files**

```bash
rm lib/domain/usecases/book/get_unit_books_usecase.dart
rm lib/domain/usecases/wordlist/get_assigned_vocabulary_units_usecase.dart
rm lib/data/models/book/unit_book_model.dart
rm lib/domain/entities/unit_book.dart
```

- [ ] **Step 2: Remove old shared package constants (deferred from Task 4)**

From `packages/owlio_shared/lib/src/constants/tables.dart`, remove:
```dart
static const unitBookAssignments = 'unit_book_assignments';
static const unitCurriculumAssignments = 'unit_curriculum_assignments';
```

From `packages/owlio_shared/lib/src/constants/rpc_functions.dart`, remove:
```dart
static const getUserUnitBooks = 'get_user_unit_books';
static const getAssignedVocabularyUnits = 'get_assigned_vocabulary_units';
```

- [ ] **Step 3: Remove all references to deleted files and constants**

Search for imports of removed files and clean up:
```bash
grep -r "unit_book" lib/ --include="*.dart"
grep -r "get_unit_books" lib/ --include="*.dart"
grep -r "get_assigned_vocabulary_units" lib/ --include="*.dart"
grep -r "unitBookAssignments" lib/ owlio_admin/lib/ --include="*.dart"
grep -r "unitCurriculumAssignments" lib/ owlio_admin/lib/ --include="*.dart"
```

Fix any remaining import references.

- [ ] **Step 4: Full project analysis**

Run: `cd packages/owlio_shared && dart analyze` and `dart analyze lib/` and `cd owlio_admin && dart analyze lib/`
Expected: 0 issues in all 3 projects

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "chore: remove deprecated unit_book code and old assignment constants"
```

---

## Execution Order

```
Phase 1: Foundation
  Task 1 → Task 2 → Task 3 → Task 4 (sequential, each depends on previous)

Phase 2: Admin Panel
  Task 5 → Task 6 + Task 7 (parallel) → Task 8 → Task 9

Phase 3: Mobile App
  Task 10 → Task 11 → Task 12 → Task 13 → Task 14 (sequential)
```

**Total: 14 tasks, ~25 files created/modified/deleted**

Phase 2 and Phase 3 can run in parallel after Phase 1 is complete, but within each phase the order matters.
