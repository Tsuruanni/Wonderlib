# Tile Theme Editor — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let admins create/edit tile themes (height, gradient colors, node positions) and assign them to vocabulary units, with the main app fetching themes from DB instead of using hardcoded values.

**Architecture:** New `tile_themes` DB table + domain/data layer (entity → model → repository → usecase → provider). Admin panel gets a new CRUD feature (list + edit screens with live preview). The existing `TileTheme` widget data class gains a `height` field and the orchestrator resolves themes from DB with hardcoded fallback.

**Tech Stack:** Flutter, Riverpod, Supabase (PostgreSQL + RLS), owlio_shared (DbTables), go_router

**Spec:** `docs/superpowers/specs/2026-03-29-tile-theme-editor-design.md`

---

## File Map

| File | Action | Responsibility |
|------|--------|----------------|
| `supabase/migrations/2026MMDD_create_tile_themes.sql` | Create | DB table + RLS + seed data + vocabulary_units FK |
| `packages/owlio_shared/lib/src/constants/tables.dart` | Modify | Add `tileThemes` constant |
| `lib/domain/entities/tile_theme.dart` | Create | TileThemeEntity value object |
| `lib/data/models/tile_theme_model.dart` | Create | JSON parsing, toEntity() |
| `lib/domain/repositories/tile_theme_repository.dart` | Create | Abstract interface |
| `lib/data/repositories/supabase/supabase_tile_theme_repository.dart` | Create | Supabase implementation |
| `lib/domain/usecases/tile_theme/get_tile_themes_usecase.dart` | Create | UseCase wrapper |
| `lib/presentation/providers/repository_providers.dart` | Modify | Register tile theme repository |
| `lib/presentation/providers/usecase_providers.dart` | Modify | Register tile theme usecase |
| `lib/presentation/providers/tile_theme_provider.dart` | Create | tileThemesProvider (DB + fallback) |
| `lib/domain/entities/vocabulary_unit.dart` | Modify | Add tileThemeId field |
| `lib/data/models/vocabulary/vocabulary_unit_model.dart` | Modify | Parse tile_theme_id |
| `lib/presentation/widgets/learning_path/tile_themes.dart` | Modify | Add height to TileTheme, remove kTileHeight |
| `lib/presentation/widgets/learning_path/map_tile.dart` | Modify | Use theme.height |
| `lib/presentation/widgets/learning_path/learning_path.dart` | Modify | Resolve themes from provider |
| `lib/presentation/providers/vocabulary_provider.dart` | Modify | activeNodeYProvider uses per-theme height |
| `owlio_admin/lib/features/tiles/screens/tile_theme_list_screen.dart` | Create | Admin list screen |
| `owlio_admin/lib/features/tiles/screens/tile_theme_edit_screen.dart` | Create | Admin edit screen with preview |
| `owlio_admin/lib/features/units/screens/unit_edit_screen.dart` | Modify | Add theme dropdown |
| `owlio_admin/lib/core/router.dart` | Modify | Add /tiles routes |

---

### Task 1: Database migration

**Files:**
- Create: `supabase/migrations/20260329200001_create_tile_themes.sql`

- [ ] **Step 1: Write migration file**

```sql
-- ============================================
-- Tile Themes — configurable map tile visuals
-- ============================================

CREATE TABLE tile_themes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  height INT NOT NULL DEFAULT 1000,
  fallback_color_1 TEXT NOT NULL DEFAULT '#2E7D32',
  fallback_color_2 TEXT NOT NULL DEFAULT '#81C784',
  node_positions JSONB NOT NULL DEFAULT '[]',
  sort_order INT NOT NULL DEFAULT 0,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- RLS
ALTER TABLE tile_themes ENABLE ROW LEVEL SECURITY;

CREATE POLICY "admin_full_access" ON tile_themes
  FOR ALL USING (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('admin', 'head'))
  );

CREATE POLICY "authenticated_read" ON tile_themes
  FOR SELECT USING (auth.uid() IS NOT NULL);

-- Seed 6 default themes
INSERT INTO tile_themes (name, height, fallback_color_1, fallback_color_2, node_positions, sort_order) VALUES
  ('Forest',   1000, '#2E7D32', '#81C784', '[{"x":0.50,"y":0.08},{"x":0.35,"y":0.22},{"x":0.58,"y":0.36},{"x":0.32,"y":0.50},{"x":0.55,"y":0.64},{"x":0.40,"y":0.78},{"x":0.50,"y":0.92}]', 0),
  ('Beach',    1000, '#0288D1', '#81D4FA', '[{"x":0.48,"y":0.08},{"x":0.62,"y":0.22},{"x":0.38,"y":0.36},{"x":0.55,"y":0.50},{"x":0.35,"y":0.64},{"x":0.52,"y":0.78},{"x":0.45,"y":0.92}]', 1),
  ('Mountain', 1000, '#546E7A', '#B0BEC5', '[{"x":0.50,"y":0.08},{"x":0.38,"y":0.22},{"x":0.60,"y":0.36},{"x":0.35,"y":0.50},{"x":0.58,"y":0.64},{"x":0.42,"y":0.78},{"x":0.50,"y":0.92}]', 2),
  ('Desert',   1000, '#E65100', '#FFCC80', '[{"x":0.52,"y":0.08},{"x":0.36,"y":0.22},{"x":0.56,"y":0.36},{"x":0.40,"y":0.50},{"x":0.60,"y":0.64},{"x":0.38,"y":0.78},{"x":0.48,"y":0.92}]', 3),
  ('Garden',   1000, '#C2185B', '#F48FB1', '[{"x":0.50,"y":0.08},{"x":0.40,"y":0.22},{"x":0.58,"y":0.36},{"x":0.35,"y":0.50},{"x":0.55,"y":0.64},{"x":0.45,"y":0.78},{"x":0.50,"y":0.92}]', 4),
  ('Winter',   1000, '#1565C0', '#BBDEFB', '[{"x":0.48,"y":0.08},{"x":0.60,"y":0.22},{"x":0.36,"y":0.36},{"x":0.58,"y":0.50},{"x":0.38,"y":0.64},{"x":0.52,"y":0.78},{"x":0.45,"y":0.92}]', 5);

-- Add tile_theme_id FK to vocabulary_units
ALTER TABLE vocabulary_units
  ADD COLUMN tile_theme_id UUID REFERENCES tile_themes(id) ON DELETE SET NULL;
```

- [ ] **Step 2: Dry-run migration**

```bash
supabase db push --dry-run
```

Expected: Shows the CREATE TABLE, policies, inserts, and ALTER TABLE. No errors.

- [ ] **Step 3: Push migration**

```bash
supabase db push
```

Expected: Migration applied successfully.

- [ ] **Step 4: Commit**

```bash
git add supabase/migrations/20260329200001_create_tile_themes.sql
git commit -m "feat: add tile_themes table with seed data and vocabulary_units FK"
```

---

### Task 2: Add DbTables constant

**Files:**
- Modify: `packages/owlio_shared/lib/src/constants/tables.dart`

- [ ] **Step 1: Add tileThemes constant**

In `packages/owlio_shared/lib/src/constants/tables.dart`, add after the avatars section (before closing `}`):

```dart
  // Tile Themes
  static const tileThemes = 'tile_themes';
```

- [ ] **Step 2: Verify**

```bash
dart analyze packages/owlio_shared/
```

Expected: No errors.

- [ ] **Step 3: Commit**

```bash
git add packages/owlio_shared/lib/src/constants/tables.dart
git commit -m "feat: add tileThemes to DbTables constants"
```

---

### Task 3: Domain entity + model + repository + usecase

**Files:**
- Create: `lib/domain/entities/tile_theme.dart`
- Create: `lib/data/models/tile_theme_model.dart`
- Create: `lib/domain/repositories/tile_theme_repository.dart`
- Create: `lib/data/repositories/supabase/supabase_tile_theme_repository.dart`
- Create: `lib/domain/usecases/tile_theme/get_tile_themes_usecase.dart`

- [ ] **Step 1: Create entity**

```dart
// lib/domain/entities/tile_theme.dart
import 'package:equatable/equatable.dart';

/// A configurable map tile theme for the learning path.
class TileThemeEntity extends Equatable {
  const TileThemeEntity({
    required this.id,
    required this.name,
    required this.height,
    required this.fallbackColor1,
    required this.fallbackColor2,
    required this.nodePositions,
    required this.sortOrder,
    required this.isActive,
  });

  final String id;
  final String name;
  final int height;
  final String fallbackColor1; // hex: "#2E7D32"
  final String fallbackColor2; // hex: "#81C784"
  final List<({double x, double y})> nodePositions;
  final int sortOrder;
  final bool isActive;

  @override
  List<Object?> get props => [id, name, height, fallbackColor1, fallbackColor2, nodePositions, sortOrder, isActive];
}
```

- [ ] **Step 2: Create model**

```dart
// lib/data/models/tile_theme_model.dart
import '../../domain/entities/tile_theme.dart';

class TileThemeModel {
  const TileThemeModel({
    required this.id,
    required this.name,
    required this.height,
    required this.fallbackColor1,
    required this.fallbackColor2,
    required this.nodePositions,
    required this.sortOrder,
    required this.isActive,
  });

  factory TileThemeModel.fromJson(Map<String, dynamic> json) {
    final positionsRaw = json['node_positions'];
    final positions = <({double x, double y})>[];
    if (positionsRaw is List) {
      for (final p in positionsRaw) {
        if (p is Map) {
          positions.add((
            x: (p['x'] as num?)?.toDouble() ?? 0.5,
            y: (p['y'] as num?)?.toDouble() ?? 0.5,
          ));
        }
      }
    }

    return TileThemeModel(
      id: json['id'] as String,
      name: json['name'] as String,
      height: json['height'] as int? ?? 1000,
      fallbackColor1: json['fallback_color_1'] as String? ?? '#2E7D32',
      fallbackColor2: json['fallback_color_2'] as String? ?? '#81C784',
      nodePositions: positions,
      sortOrder: json['sort_order'] as int? ?? 0,
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  final String id;
  final String name;
  final int height;
  final String fallbackColor1;
  final String fallbackColor2;
  final List<({double x, double y})> nodePositions;
  final int sortOrder;
  final bool isActive;

  TileThemeEntity toEntity() {
    return TileThemeEntity(
      id: id,
      name: name,
      height: height,
      fallbackColor1: fallbackColor1,
      fallbackColor2: fallbackColor2,
      nodePositions: nodePositions,
      sortOrder: sortOrder,
      isActive: isActive,
    );
  }
}
```

- [ ] **Step 3: Create repository interface**

```dart
// lib/domain/repositories/tile_theme_repository.dart
import 'package:dartz/dartz.dart';

import '../../core/errors/failures.dart';
import '../entities/tile_theme.dart';

abstract class TileThemeRepository {
  Future<Either<Failure, List<TileThemeEntity>>> getTileThemes();
}
```

- [ ] **Step 4: Create Supabase repository implementation**

```dart
// lib/data/repositories/supabase/supabase_tile_theme_repository.dart
import 'package:dartz/dartz.dart';
import 'package:owlio_shared/owlio_shared.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/failures.dart';
import '../../../domain/entities/tile_theme.dart';
import '../../../domain/repositories/tile_theme_repository.dart';
import '../../models/tile_theme_model.dart';

class SupabaseTileThemeRepository implements TileThemeRepository {
  final SupabaseClient _client;

  const SupabaseTileThemeRepository(this._client);

  @override
  Future<Either<Failure, List<TileThemeEntity>>> getTileThemes() async {
    try {
      final response = await _client
          .from(DbTables.tileThemes)
          .select()
          .eq('is_active', true)
          .order('sort_order');

      final rows = List<Map<String, dynamic>>.from(response);
      final themes = rows.map((r) => TileThemeModel.fromJson(r).toEntity()).toList();
      return Right(themes);
    } on PostgrestException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
}
```

- [ ] **Step 5: Create usecase**

```dart
// lib/domain/usecases/tile_theme/get_tile_themes_usecase.dart
import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../../core/usecases/usecase.dart';
import '../../entities/tile_theme.dart';
import '../../repositories/tile_theme_repository.dart';

class GetTileThemesUseCase implements UseCase<List<TileThemeEntity>, NoParams> {
  final TileThemeRepository repository;

  const GetTileThemesUseCase(this.repository);

  @override
  Future<Either<Failure, List<TileThemeEntity>>> call(NoParams params) {
    return repository.getTileThemes();
  }
}
```

- [ ] **Step 6: Verify**

```bash
dart analyze lib/domain/entities/tile_theme.dart lib/data/models/tile_theme_model.dart lib/domain/repositories/tile_theme_repository.dart lib/data/repositories/supabase/supabase_tile_theme_repository.dart lib/domain/usecases/tile_theme/get_tile_themes_usecase.dart
```

Expected: No errors. Check that `UseCase` and `NoParams` come from `core/usecases/usecase.dart`.

- [ ] **Step 7: Commit**

```bash
git add lib/domain/entities/tile_theme.dart lib/data/models/tile_theme_model.dart lib/domain/repositories/tile_theme_repository.dart lib/data/repositories/supabase/supabase_tile_theme_repository.dart lib/domain/usecases/tile_theme/get_tile_themes_usecase.dart
git commit -m "feat: add tile theme domain layer (entity, model, repository, usecase)"
```

---

### Task 4: Register providers + create tile theme provider

**Files:**
- Modify: `lib/presentation/providers/repository_providers.dart`
- Modify: `lib/presentation/providers/usecase_providers.dart`
- Create: `lib/presentation/providers/tile_theme_provider.dart`

- [ ] **Step 1: Register repository provider**

In `lib/presentation/providers/repository_providers.dart`, add import:

```dart
import '../../data/repositories/supabase/supabase_tile_theme_repository.dart';
import '../../domain/repositories/tile_theme_repository.dart';
```

Add provider (after the last existing repository provider):

```dart
final tileThemeRepositoryProvider = Provider<TileThemeRepository>((ref) {
  return SupabaseTileThemeRepository(Supabase.instance.client);
});
```

- [ ] **Step 2: Register usecase provider**

In `lib/presentation/providers/usecase_providers.dart`, add import:

```dart
import '../../domain/usecases/tile_theme/get_tile_themes_usecase.dart';
import 'repository_providers.dart';
```

Note: `repository_providers.dart` may already be imported. Only add if missing.

Add provider:

```dart
final getTileThemesUseCaseProvider = Provider<GetTileThemesUseCase>((ref) {
  return GetTileThemesUseCase(ref.watch(tileThemeRepositoryProvider));
});
```

- [ ] **Step 3: Create tile theme provider**

```dart
// lib/presentation/providers/tile_theme_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/usecases/usecase.dart';
import '../../domain/entities/tile_theme.dart';
import 'usecase_providers.dart';

/// Fetches active tile themes from DB.
/// Falls back to empty list on failure (orchestrator uses hardcoded fallback).
final tileThemesProvider = FutureProvider<List<TileThemeEntity>>((ref) async {
  final useCase = ref.watch(getTileThemesUseCaseProvider);
  final result = await useCase(NoParams());
  return result.fold((_) => [], (themes) => themes);
});
```

- [ ] **Step 4: Verify**

```bash
dart analyze lib/presentation/providers/repository_providers.dart lib/presentation/providers/usecase_providers.dart lib/presentation/providers/tile_theme_provider.dart
```

Expected: No errors.

- [ ] **Step 5: Commit**

```bash
git add lib/presentation/providers/repository_providers.dart lib/presentation/providers/usecase_providers.dart lib/presentation/providers/tile_theme_provider.dart
git commit -m "feat: register tile theme providers (repository, usecase, data)"
```

---

### Task 5: Add tileThemeId to VocabularyUnit

**Files:**
- Modify: `lib/domain/entities/vocabulary_unit.dart`
- Modify: `lib/data/models/vocabulary/vocabulary_unit_model.dart`

- [ ] **Step 1: Add field to entity**

In `lib/domain/entities/vocabulary_unit.dart`, add `tileThemeId` field:

```dart
class VocabularyUnit extends Equatable {
  const VocabularyUnit({
    required this.id,
    required this.name,
    this.description,
    required this.sortOrder,
    this.color,
    this.icon,
    this.isActive = true,
    this.tileThemeId,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final String? description;
  final int sortOrder;
  final String? color;
  final String? icon;
  final bool isActive;
  final String? tileThemeId;
  final DateTime createdAt;
  final DateTime updatedAt;

  @override
  List<Object?> get props => [
        id,
        name,
        description,
        sortOrder,
        color,
        icon,
        isActive,
        tileThemeId,
        createdAt,
        updatedAt,
      ];
}
```

- [ ] **Step 2: Add field to model**

In `lib/data/models/vocabulary/vocabulary_unit_model.dart`, add `tileThemeId`:

Constructor: add `this.tileThemeId,`

Field: add `final String? tileThemeId;`

In `fromJson`: add `tileThemeId: json['tile_theme_id'] as String?,`

In `toEntity()`: add `tileThemeId: tileThemeId,`

- [ ] **Step 3: Verify**

```bash
dart analyze lib/domain/entities/vocabulary_unit.dart lib/data/models/vocabulary/vocabulary_unit_model.dart
```

Expected: No errors.

- [ ] **Step 4: Commit**

```bash
git add lib/domain/entities/vocabulary_unit.dart lib/data/models/vocabulary/vocabulary_unit_model.dart
git commit -m "feat: add tileThemeId to VocabularyUnit entity and model"
```

---

### Task 6: Update TileTheme widget class + MapTile + orchestrator + activeNodeYProvider

**Files:**
- Modify: `lib/presentation/widgets/learning_path/tile_themes.dart`
- Modify: `lib/presentation/widgets/learning_path/map_tile.dart`
- Modify: `lib/presentation/widgets/learning_path/learning_path.dart`
- Modify: `lib/presentation/providers/vocabulary_provider.dart`

- [ ] **Step 1: Add height to TileTheme and remove kTileHeight**

In `lib/presentation/widgets/learning_path/tile_themes.dart`:

Add `height` field to `TileTheme`:

```dart
class TileTheme {
  const TileTheme({
    required this.name,
    required this.assetPath,
    required this.nodePositions,
    required this.fallbackColors,
    this.height = 1000.0,
  });

  final String name;
  final String assetPath;
  final List<Offset> nodePositions;
  final List<Color> fallbackColors;
  final double height;
}
```

Remove `kTileHeight`:

```dart
// REMOVE this line:
// const kTileHeight = 1000.0;
```

Keep `kTileWidth = 800.0` and `kDividerHeight = 60.0`.

Add each hardcoded theme a `height: 1000.0` parameter (they already default to 1000.0 so this is optional but explicit).

- [ ] **Step 2: Update MapTile to use theme.height**

In `lib/presentation/widgets/learning_path/map_tile.dart`, replace all `kTileHeight` references with `theme.height`:

Line 40: `height: kTileHeight,` → `height: theme.height,`
Line 79: `final top = position.dy * kTileHeight - 40;` → `final top = position.dy * theme.height - 40;`

The `_PositionedNode` needs access to `theme.height`. Pass it down:

```dart
class _PositionedNode extends StatelessWidget {
  const _PositionedNode({
    required this.position,
    required this.data,
    required this.tileHeight,
  });

  final Offset position;
  final MapTileNodeData data;
  final double tileHeight;

  @override
  Widget build(BuildContext context) {
    final left = position.dx * kTileWidth - 70;
    final top = position.dy * tileHeight - 40;
    // ... rest unchanged
  }
}
```

Update the `MapTile.build` to pass `tileHeight`:

```dart
_PositionedNode(
  position: theme.nodePositions[i],
  data: nodes[i],
  tileHeight: theme.height,
),
```

- [ ] **Step 3: Update orchestrator to resolve themes from DB**

In `lib/presentation/widgets/learning_path/learning_path.dart`, add import:

```dart
import '../../providers/tile_theme_provider.dart';
import '../../../domain/entities/tile_theme.dart';
```

In `_buildTiles`, add theme resolution:

```dart
Widget _buildTiles(BuildContext context, WidgetRef ref, List<PathUnitData> units) {
    final settings = ref.watch(systemSettingsProvider).valueOrNull;
    final star3 = settings?.starRating3 ?? 90;
    final star2 = settings?.starRating2 ?? 70;
    final star1 = settings?.starRating1 ?? 50;

    final wordsToday = ref.watch(wordsStartedTodayFromListsProvider).valueOrNull ?? 0;
    final canStartNewList = wordsToday < dailyWordListLimit;

    // Fetch DB themes for resolution
    final dbThemes = ref.watch(tileThemesProvider).valueOrNull ?? [];

    final children = <Widget>[];
    bool foundActive = false;

    for (int unitIdx = 0; unitIdx < units.length; unitIdx++) {
      final unit = units[unitIdx];
      final isUnitLocked = unitIdx > 0 && !units[unitIdx - 1].isAllComplete;

      // Resolve theme: unit-specific from DB, or fallback cycling
      final theme = _resolveTheme(unit, unitIdx, dbThemes);

      // ... rest of the loop stays the same, but replace:
      // final theme = tileThemeForUnit(unitIdx);
      // with the theme resolved above
```

Add the resolution helper method to `LearningPathView`:

```dart
TileTheme _resolveTheme(PathUnitData unit, int unitIdx, List<TileThemeEntity> dbThemes) {
  if (unit.unit.tileThemeId != null && dbThemes.isNotEmpty) {
    final match = dbThemes.where((t) => t.id == unit.unit.tileThemeId).firstOrNull;
    if (match != null) {
      return TileTheme(
        name: match.name,
        assetPath: '',
        height: match.height.toDouble(),
        nodePositions: match.nodePositions.map((p) => Offset(p.x, p.y)).toList(),
        fallbackColors: [_parseHex(match.fallbackColor1), _parseHex(match.fallbackColor2)],
      );
    }
  }
  return tileThemeForUnit(unitIdx);
}

static Color _parseHex(String hex) {
  if (hex.length < 7) return const Color(0xFF58CC02);
  try {
    return Color(int.parse(hex.substring(1), radix: 16) + 0xFF000000);
  } catch (_) {
    return const Color(0xFF58CC02);
  }
}
```

- [ ] **Step 4: Update activeNodeYProvider for per-theme height**

In `lib/presentation/providers/vocabulary_provider.dart`, update the provider to use resolved theme heights:

```dart
import 'tile_theme_provider.dart';
import '../../domain/entities/tile_theme.dart';
```

Replace the `activeNodeYProvider`:

```dart
final activeNodeYProvider = Provider<double?>((ref) {
  final pathUnits = ref.watch(learningPathProvider).valueOrNull;
  if (pathUnits == null || pathUnits.isEmpty) return null;

  final dbThemes = ref.watch(tileThemesProvider).valueOrNull ?? [];

  var cumulativeY = 0.0;

  for (int unitIdx = 0; unitIdx < pathUnits.length; unitIdx++) {
    final unit = pathUnits[unitIdx];
    final isUnitLocked = unitIdx > 0 && !pathUnits[unitIdx - 1].isAllComplete;

    // Resolve theme height
    final themeHeight = _resolveThemeHeight(unit, unitIdx, dbThemes);
    final theme = _resolveThemePositions(unit, unitIdx, dbThemes);

    cumulativeY += kDividerHeight; // divider before tile

    final locks = calculateLocks(
      items: unit.items,
      sequentialLock: unit.sequentialLock,
      booksExemptFromLock: unit.booksExemptFromLock,
      isUnitLocked: isUnitLocked,
    );

    for (int itemIdx = 0; itemIdx < unit.items.length; itemIdx++) {
      final item = unit.items[itemIdx];
      final isItemLocked = locks[itemIdx];

      if (!isItemLocked && !item.isComplete && item is! PathDailyReviewItem) {
        if (itemIdx >= theme.length) continue;
        return cumulativeY + theme[itemIdx].dy * themeHeight;
      }
    }

    cumulativeY += themeHeight; // tile height
  }

  return null;
});

double _resolveThemeHeight(PathUnitData unit, int unitIdx, List<TileThemeEntity> dbThemes) {
  if (unit.unit.tileThemeId != null && dbThemes.isNotEmpty) {
    final match = dbThemes.where((t) => t.id == unit.unit.tileThemeId).firstOrNull;
    if (match != null) return match.height.toDouble();
  }
  return tileThemeForUnit(unitIdx).height;
}

List<Offset> _resolveThemePositions(PathUnitData unit, int unitIdx, List<TileThemeEntity> dbThemes) {
  if (unit.unit.tileThemeId != null && dbThemes.isNotEmpty) {
    final match = dbThemes.where((t) => t.id == unit.unit.tileThemeId).firstOrNull;
    if (match != null) return match.nodePositions.map((p) => Offset(p.x, p.y)).toList();
  }
  return tileThemeForUnit(unitIdx).nodePositions;
}
```

- [ ] **Step 5: Verify**

```bash
dart analyze lib/presentation/widgets/learning_path/ lib/presentation/providers/vocabulary_provider.dart lib/presentation/providers/tile_theme_provider.dart
```

Expected: No errors. Fix any `kTileHeight` references that were missed.

- [ ] **Step 6: Commit**

```bash
git add lib/presentation/widgets/learning_path/tile_themes.dart lib/presentation/widgets/learning_path/map_tile.dart lib/presentation/widgets/learning_path/learning_path.dart lib/presentation/providers/vocabulary_provider.dart
git commit -m "feat: use DB tile themes with per-unit height and fallback cycling"
```

---

### Task 7: Admin — tile theme list screen

**Files:**
- Create: `owlio_admin/lib/features/tiles/screens/tile_theme_list_screen.dart`

- [ ] **Step 1: Write list screen**

```dart
// owlio_admin/lib/features/tiles/screens/tile_theme_list_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:owlio_shared/owlio_shared.dart';

import '../../../core/supabase_client.dart';

// ============================================
// PROVIDERS
// ============================================

final tileThemesAdminProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final supabase = ref.watch(supabaseClientProvider);
  final response = await supabase
      .from(DbTables.tileThemes)
      .select()
      .order('sort_order', ascending: true);
  return List<Map<String, dynamic>>.from(response);
});

// ============================================
// SCREEN
// ============================================

class TileThemeListScreen extends ConsumerWidget {
  const TileThemeListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themesAsync = ref.watch(tileThemesAdminProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tile Temaları'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
        actions: [
          FilledButton.icon(
            onPressed: () => context.go('/tiles/new'),
            icon: const Icon(Icons.add),
            label: const Text('Yeni Tema'),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: themesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Hata: $e')),
        data: (themes) {
          if (themes.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.map_outlined, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text('Henüz tema yok'),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () => context.go('/tiles/new'),
                    icon: const Icon(Icons.add),
                    label: const Text('Yeni Tema'),
                  ),
                ],
              ),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: DataTable(
              columns: const [
                DataColumn(label: Text('Renk')),
                DataColumn(label: Text('Tema Adı')),
                DataColumn(label: Text('Yükseklik')),
                DataColumn(label: Text('Node Sayısı')),
                DataColumn(label: Text('Sıralama')),
                DataColumn(label: Text('Aktif')),
                DataColumn(label: Text('')),
              ],
              rows: themes.map((theme) {
                final color1 = _parseHex(theme['fallback_color_1'] as String? ?? '#888888');
                final color2 = _parseHex(theme['fallback_color_2'] as String? ?? '#CCCCCC');
                final positions = theme['node_positions'] as List? ?? [];

                return DataRow(cells: [
                  DataCell(
                    Container(
                      width: 48,
                      height: 24,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [color1, color2]),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  DataCell(Text(theme['name'] as String? ?? '')),
                  DataCell(Text('${theme['height'] ?? 1000}px')),
                  DataCell(Text('${positions.length}')),
                  DataCell(Text('${theme['sort_order'] ?? 0}')),
                  DataCell(Icon(
                    (theme['is_active'] as bool? ?? true)
                        ? Icons.check_circle
                        : Icons.cancel,
                    color: (theme['is_active'] as bool? ?? true)
                        ? Colors.green
                        : Colors.red,
                    size: 20,
                  )),
                  DataCell(
                    IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () => context.go('/tiles/${theme['id']}'),
                    ),
                  ),
                ]);
              }).toList(),
            ),
          );
        },
      ),
    );
  }

  Color _parseHex(String hex) {
    if (hex.length < 7) return Colors.grey;
    try {
      return Color(int.parse(hex.substring(1), radix: 16) + 0xFF000000);
    } catch (_) {
      return Colors.grey;
    }
  }
}
```

- [ ] **Step 2: Verify**

```bash
dart analyze owlio_admin/lib/features/tiles/screens/tile_theme_list_screen.dart
```

Expected: No errors.

- [ ] **Step 3: Commit**

```bash
git add owlio_admin/lib/features/tiles/screens/tile_theme_list_screen.dart
git commit -m "feat: add tile theme list screen to admin panel"
```

---

### Task 8: Admin — tile theme edit screen with live preview

**Files:**
- Create: `owlio_admin/lib/features/tiles/screens/tile_theme_edit_screen.dart`

- [ ] **Step 1: Write edit screen**

```dart
// owlio_admin/lib/features/tiles/screens/tile_theme_edit_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:owlio_shared/owlio_shared.dart';
import 'package:uuid/uuid.dart';

import '../../../core/supabase_client.dart';
import 'tile_theme_list_screen.dart';

// ============================================
// PROVIDERS
// ============================================

final tileThemeDetailProvider =
    FutureProvider.family<Map<String, dynamic>?, String>((ref, themeId) async {
  final supabase = ref.watch(supabaseClientProvider);
  final response = await supabase
      .from(DbTables.tileThemes)
      .select()
      .eq('id', themeId)
      .maybeSingle();
  return response;
});

// ============================================
// SCREEN
// ============================================

class TileThemeEditScreen extends ConsumerStatefulWidget {
  const TileThemeEditScreen({super.key, this.themeId});
  final String? themeId;

  @override
  ConsumerState<TileThemeEditScreen> createState() =>
      _TileThemeEditScreenState();
}

class _TileThemeEditScreenState extends ConsumerState<TileThemeEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _sortOrderController = TextEditingController(text: '0');
  final _color1Controller = TextEditingController(text: '#2E7D32');
  final _color2Controller = TextEditingController(text: '#81C784');

  double _height = 1000;
  bool _isActive = true;
  bool _isLoading = false;
  bool _isInitialized = false;

  // Dynamic node positions: list of (x%, y%) pairs
  final List<_NodePosition> _nodes = [];

  bool get _isNew => widget.themeId == null;

  @override
  void initState() {
    super.initState();
    if (_isNew) {
      // Start with 3 default nodes
      _nodes.addAll([
        _NodePosition(50, 15),
        _NodePosition(35, 50),
        _NodePosition(50, 85),
      ]);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _sortOrderController.dispose();
    _color1Controller.dispose();
    _color2Controller.dispose();
    super.dispose();
  }

  void _populateFields(Map<String, dynamic> theme) {
    if (_isInitialized) return;
    _isInitialized = true;

    _nameController.text = theme['name'] as String? ?? '';
    _sortOrderController.text = '${theme['sort_order'] ?? 0}';
    _color1Controller.text = theme['fallback_color_1'] as String? ?? '#2E7D32';
    _color2Controller.text = theme['fallback_color_2'] as String? ?? '#81C784';
    _height = (theme['height'] as int? ?? 1000).toDouble();
    _isActive = theme['is_active'] as bool? ?? true;

    _nodes.clear();
    final positions = theme['node_positions'] as List? ?? [];
    for (final p in positions) {
      if (p is Map) {
        _nodes.add(_NodePosition(
          ((p['x'] as num?)?.toDouble() ?? 0.5) * 100,
          ((p['y'] as num?)?.toDouble() ?? 0.5) * 100,
        ));
      }
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final supabase = ref.read(supabaseClientProvider);

      final nodePositionsJson = _nodes
          .map((n) => {'x': (n.x / 100).toStringAsFixed(2), 'y': (n.y / 100).toStringAsFixed(2)})
          .map((m) => {'x': double.parse(m['x']!), 'y': double.parse(m['y']!)})
          .toList();

      final data = {
        'name': _nameController.text.trim(),
        'height': _height.round(),
        'fallback_color_1': _color1Controller.text.trim(),
        'fallback_color_2': _color2Controller.text.trim(),
        'node_positions': nodePositionsJson,
        'sort_order': int.tryParse(_sortOrderController.text) ?? 0,
        'is_active': _isActive,
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (_isNew) {
        data['id'] = const Uuid().v4();
        await supabase.from(DbTables.tileThemes).insert(data);
      } else {
        await supabase
            .from(DbTables.tileThemes)
            .update(data)
            .eq('id', widget.themeId!);
      }

      ref.invalidate(tileThemesAdminProvider);
      if (!_isNew) {
        ref.invalidate(tileThemeDetailProvider(widget.themeId!));
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_isNew ? 'Tema oluşturuldu!' : 'Tema güncellendi!')),
        );
        context.go('/tiles');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Temayı Sil'),
        content: const Text('Bu tema kalıcı olarak silinecek. Emin misiniz?'),
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

    setState(() => _isLoading = true);
    try {
      final supabase = ref.read(supabaseClientProvider);
      await supabase.from(DbTables.tileThemes).delete().eq('id', widget.themeId!);
      ref.invalidate(tileThemesAdminProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tema silindi')),
        );
        context.go('/tiles');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isNew) {
      final themeAsync = ref.watch(tileThemeDetailProvider(widget.themeId!));
      return themeAsync.when(
        loading: () => Scaffold(
          appBar: AppBar(title: const Text('Tema Düzenle')),
          body: const Center(child: CircularProgressIndicator()),
        ),
        error: (e, _) => Scaffold(
          appBar: AppBar(title: const Text('Tema Düzenle')),
          body: Center(child: Text('Hata: $e')),
        ),
        data: (theme) {
          if (theme == null) {
            return Scaffold(
              appBar: AppBar(title: const Text('Tema Düzenle')),
              body: const Center(child: Text('Tema bulunamadı')),
            );
          }
          _populateFields(theme);
          return _buildForm();
        },
      );
    }
    return _buildForm();
  }

  Widget _buildForm() {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isNew ? 'Yeni Tema' : 'Tema Düzenle'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/tiles'),
        ),
        actions: [
          if (!_isNew)
            TextButton.icon(
              onPressed: _isLoading ? null : _delete,
              icon: const Icon(Icons.delete, color: Colors.red),
              label: const Text('Sil', style: TextStyle(color: Colors.red)),
            ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: _isLoading ? null : _save,
            child: _isLoading
                ? const SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(_isNew ? 'Oluştur' : 'Kaydet'),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left: Form
            Expanded(
              flex: 2,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Form(
                    key: _formKey,
                    child: ListView(
                      children: [
                        Text('Tema Detayları', style: Theme.of(context).textTheme.titleLarge),
                        const SizedBox(height: 24),
                        TextFormField(
                          controller: _nameController,
                          decoration: const InputDecoration(
                            labelText: 'Tema Adı *',
                            hintText: 'ör. Forest, Beach, Mountain',
                            border: OutlineInputBorder(),
                          ),
                          validator: (v) => v == null || v.trim().isEmpty ? 'Zorunlu' : null,
                          onChanged: (_) => setState(() {}),
                        ),
                        const SizedBox(height: 16),
                        // Height slider
                        Row(
                          children: [
                            const Text('Yükseklik: '),
                            Expanded(
                              child: Slider(
                                value: _height,
                                min: 300,
                                max: 1500,
                                divisions: 24,
                                label: '${_height.round()}px',
                                onChanged: (v) => setState(() => _height = v),
                              ),
                            ),
                            SizedBox(
                              width: 70,
                              child: Text('${_height.round()}px',
                                  style: const TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // Colors
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _color1Controller,
                                decoration: const InputDecoration(
                                  labelText: 'Gradient Renk 1',
                                  hintText: '#2E7D32',
                                  border: OutlineInputBorder(),
                                ),
                                onChanged: (_) => setState(() {}),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: TextFormField(
                                controller: _color2Controller,
                                decoration: const InputDecoration(
                                  labelText: 'Gradient Renk 2',
                                  hintText: '#81C784',
                                  border: OutlineInputBorder(),
                                ),
                                onChanged: (_) => setState(() {}),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _sortOrderController,
                                decoration: const InputDecoration(
                                  labelText: 'Sıralama',
                                  border: OutlineInputBorder(),
                                ),
                                keyboardType: TextInputType.number,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: SwitchListTile(
                                title: const Text('Aktif'),
                                value: _isActive,
                                onChanged: (v) => setState(() => _isActive = v),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        // Node positions
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Node Pozisyonları (${_nodes.length})',
                                style: Theme.of(context).textTheme.titleMedium),
                            FilledButton.icon(
                              onPressed: () {
                                setState(() => _nodes.add(_NodePosition(50, 50)));
                              },
                              icon: const Icon(Icons.add, size: 18),
                              label: const Text('Node Ekle'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ...List.generate(_nodes.length, (i) {
                          final node = _nodes[i];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 60,
                                  child: Text('Node ${i + 1}',
                                      style: const TextStyle(fontWeight: FontWeight.bold)),
                                ),
                                const Text('X: '),
                                Expanded(
                                  child: Slider(
                                    value: node.x,
                                    min: 0, max: 100,
                                    divisions: 100,
                                    label: '${node.x.round()}%',
                                    onChanged: (v) => setState(() => node.x = v),
                                  ),
                                ),
                                SizedBox(width: 40, child: Text('${node.x.round()}%')),
                                const SizedBox(width: 8),
                                const Text('Y: '),
                                Expanded(
                                  child: Slider(
                                    value: node.y,
                                    min: 0, max: 100,
                                    divisions: 100,
                                    label: '${node.y.round()}%',
                                    onChanged: (v) => setState(() => node.y = v),
                                  ),
                                ),
                                SizedBox(width: 40, child: Text('${node.y.round()}%')),
                                IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                                  onPressed: () => setState(() => _nodes.removeAt(i)),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 24),
            // Right: Live Preview
            Expanded(
              flex: 1,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Önizleme', style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 16),
                      _TilePreview(
                        color1: _parseHex(_color1Controller.text),
                        color2: _parseHex(_color2Controller.text),
                        height: _height,
                        nodes: _nodes,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _parseHex(String hex) {
    if (hex.length < 7) return Colors.grey;
    try {
      return Color(int.parse(hex.substring(1), radix: 16) + 0xFF000000);
    } catch (_) {
      return Colors.grey;
    }
  }
}

// ============================================
// HELPERS
// ============================================

class _NodePosition {
  double x; // 0-100 percentage
  double y; // 0-100 percentage

  _NodePosition(this.x, this.y);
}

/// Scaled-down tile preview with gradient + numbered node dots.
class _TilePreview extends StatelessWidget {
  const _TilePreview({
    required this.color1,
    required this.color2,
    required this.height,
    required this.nodes,
  });

  final Color color1;
  final Color color2;
  final double height;
  final List<_NodePosition> nodes;

  static const _previewWidth = 280.0;

  @override
  Widget build(BuildContext context) {
    final scale = _previewWidth / 800.0;
    final previewHeight = height * scale;

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: _previewWidth,
        height: previewHeight,
        child: Stack(
          children: [
            // Gradient background
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [color1, color2],
                  ),
                ),
              ),
            ),
            // Node dots
            for (int i = 0; i < nodes.length; i++)
              Positioned(
                left: (nodes[i].x / 100) * _previewWidth - 14,
                top: (nodes[i].y / 100) * previewHeight - 14,
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white70, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '${i + 1}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Verify**

```bash
dart analyze owlio_admin/lib/features/tiles/screens/tile_theme_edit_screen.dart
```

Expected: No errors.

- [ ] **Step 3: Commit**

```bash
git add owlio_admin/lib/features/tiles/screens/tile_theme_edit_screen.dart
git commit -m "feat: add tile theme edit screen with live preview to admin panel"
```

---

### Task 9: Admin — wire routes + unit edit dropdown

**Files:**
- Modify: `owlio_admin/lib/core/router.dart`
- Modify: `owlio_admin/lib/features/units/screens/unit_edit_screen.dart`

- [ ] **Step 1: Add tile routes to admin router**

In `owlio_admin/lib/core/router.dart`, add imports:

```dart
import '../features/tiles/screens/tile_theme_list_screen.dart';
import '../features/tiles/screens/tile_theme_edit_screen.dart';
```

Add routes (before the closing `]` of `routes:`):

```dart
      // Tile Themes
      GoRoute(
        path: '/tiles',
        builder: (context, state) => const TileThemeListScreen(),
      ),
      GoRoute(
        path: '/tiles/new',
        builder: (context, state) => const TileThemeEditScreen(),
      ),
      GoRoute(
        path: '/tiles/:themeId',
        builder: (context, state) => TileThemeEditScreen(
          themeId: state.pathParameters['themeId'],
        ),
      ),
```

- [ ] **Step 2: Add theme dropdown to unit edit screen**

In `owlio_admin/lib/features/units/screens/unit_edit_screen.dart`:

Add import:
```dart
import '../../tiles/screens/tile_theme_list_screen.dart';
```

Add state field:
```dart
String? _tileThemeId;
```

In `_populateFields`, add:
```dart
_tileThemeId = unit['tile_theme_id'] as String?;
```

In `_save`, add to `data` map:
```dart
'tile_theme_id': _tileThemeId,
```

In the form `ListView.children`, after the `SwitchListTile` for `_isActive`, add:

```dart
const SizedBox(height: 16),
// Tile theme dropdown
Consumer(builder: (context, ref, _) {
  final themesAsync = ref.watch(tileThemesAdminProvider);
  return themesAsync.when(
    loading: () => const LinearProgressIndicator(),
    error: (e, _) => Text('Tema yüklenemedi: $e'),
    data: (themes) {
      return DropdownButtonFormField<String?>(
        value: _tileThemeId,
        decoration: const InputDecoration(
          labelText: 'Tile Teması',
          hintText: 'Otomatik (sıralı döngü)',
          border: OutlineInputBorder(),
        ),
        items: [
          const DropdownMenuItem<String?>(
            value: null,
            child: Text('Otomatik'),
          ),
          ...themes.map((t) => DropdownMenuItem<String?>(
                value: t['id'] as String,
                child: Text(t['name'] as String? ?? ''),
              )),
        ],
        onChanged: (v) => setState(() => _tileThemeId = v),
      );
    },
  );
}),
```

- [ ] **Step 3: Verify**

```bash
dart analyze owlio_admin/lib/core/router.dart owlio_admin/lib/features/units/screens/unit_edit_screen.dart
```

Expected: No errors.

- [ ] **Step 4: Commit**

```bash
git add owlio_admin/lib/core/router.dart owlio_admin/lib/features/units/screens/unit_edit_screen.dart
git commit -m "feat: wire tile theme routes and add theme dropdown to unit editor"
```

---

### Task 10: Full verification

**Files:**
- All modified files

- [ ] **Step 1: Full analysis — main app**

```bash
dart analyze lib/
```

Expected: No new errors (only pre-existing infos).

- [ ] **Step 2: Full analysis — admin panel**

```bash
dart analyze owlio_admin/lib/
```

Expected: No new errors.

- [ ] **Step 3: Full analysis — shared package**

```bash
dart analyze packages/owlio_shared/
```

Expected: No errors.

- [ ] **Step 4: Test in browser**

```bash
flutter run -d chrome
```

Navigate to Learning Path tab. Expected:
- Tiles render with gradient backgrounds (seed data themes loaded from DB)
- Node positions match seed data
- If a unit has no `tile_theme_id`, falls back to cycling

- [ ] **Step 5: Test admin panel**

```bash
cd owlio_admin && flutter run -d chrome
```

Navigate to `/tiles`. Expected:
- 6 seed themes listed in DataTable
- Click edit → form populated with theme data
- Slider changes update preview in real-time
- Save persists to DB

- [ ] **Step 6: Final commit (if fixes needed)**

```bash
git add -A
git commit -m "fix: resolve any issues found during full verification"
```
