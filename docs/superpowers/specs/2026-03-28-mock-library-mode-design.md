# Mock Library Mode — Design Spec

**Date:** 2026-03-28
**Status:** Draft
**Scope:** Main App (Flutter), Admin Panel, Database (settings only)

---

## Overview

Marketing-oriented feature that makes the library look "full" before content is ready. When enabled via admin toggle, 150 hardcoded mock books (100 classics + 50 original titles) appear at the end of each CEFR level shelf. Mock books are visually locked with a frosted glass effect and lock icon — not tappable, not stored in the database. Real books get a small "Demo" badge so users understand which content is currently accessible.

## Key Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Data storage | Client-side hardcoded Dart list | Zero DB pollution, instant rollback by toggling off, no migration risk |
| Toggle mechanism | `system_settings` boolean (`mock_library_enabled`) | Consistent with existing feature flags, admin-controlled |
| Placement | End of each CEFR level shelf | Real books stay prominent, mock books extend the "scroll depth" |
| Mock lock visual | Frosted glass + lock icon (no label) | Looks like a real locked book — no "Coming Soon" text breaks the illusion |
| Mock tap behavior | Disabled (no dialog, no navigation) | Cleaner than showing a dialog for 150 fake books |
| Mock cover image | None — placeholder with blur effect | No asset management needed, consistent look |
| Real book indicator | Small "Demo" badge on real books | Signals that accessible books are demo content; locked ones are "the real library" |
| Scope | All roles see mock books when enabled | Teachers and students both get the "full library" impression |
| Book content | 100 real classics + 50 original-sounding titles | Classics add credibility, originals show "exclusive content coming" |

---

## 1. System Settings

### 1.1 New Setting

| Key | Category | Type | Default | Description |
|-----|----------|------|---------|-------------|
| `mock_library_enabled` | `app` | `boolean` | `false` | Kütüphane Demo Modu — show 150 mock books in library |

Inserted via migration into `system_settings` table. Admin panel's existing `SettingsScreen` already renders `app` category settings — no UI changes needed in admin beyond the migration.

---

## 2. Mock Book Data

### 2.1 Data File

**New file:** `lib/data/datasources/mock_books_data.dart`

Contains a `const List<Book>` of 150 entries. Each entry:

```dart
Book(
  id: 'mock_001',                    // Deterministic, prefixed
  title: 'Alice in Wonderland',
  slug: 'alice-in-wonderland',
  author: 'Lewis Carroll',
  level: 'A2',                       // CEFR level
  genre: 'Fantasy',                  // Matches existing genre strings
  chapterCount: 12,                  // Realistic random 5–20
  status: BookStatus.published,
  createdAt: DateTime(2026, 1, 1),   // Static date
  updatedAt: DateTime(2026, 1, 1),
)
```

### 2.2 Book Distribution

**By level (~25 each):**

| Level | Count | Emphasis |
|-------|-------|----------|
| A1 | 25 | Short fables, fairy tales, simple stories |
| A2 | 25 | Children's classics, adventure |
| B1 | 25 | Young adult classics, mystery |
| B2 | 25 | Literature, science fiction |
| C1 | 25 | Advanced literature, philosophy |
| C2 | 25 | Complex classics, original literary fiction |

**By type:**
- 100 classic titles: Real public-domain works (Alice in Wonderland, Treasure Island, The Jungle Book, Robin Hood, Peter Pan, Aesop's Fables, 20,000 Leagues Under the Sea, The Call of the Wild, etc.)
- 50 original titles: Fictional but realistic-sounding titles (e.g., "The Lighthouse Keeper's Secret", "Beyond the Frozen Ridge", "Whispers in the Willow Garden")

**Categories:** Adventure, Fantasy, Mystery, Science Fiction, Fairy Tale, Classic, Fable, Historical Fiction, Horror, Poetry — distributed to match realistic library diversity.

### 2.3 Mock Book Identification

A book is identified as mock via: `book.id.startsWith('mock_')`

Helper getter added to `Book` entity:

```dart
bool get isMock => id.startsWith('mock_');
```

---

## 3. Presentation Layer

### 3.1 Provider Changes

**`booksByLevelProvider`** in `library_screen.dart`:

```
Current flow:
  booksProvider → filter by search/category → group by level

New flow:
  booksProvider → filter by search/category → group by level
  IF mockLibraryEnabled:
    → for each level, append matching mock books (also filtered by search/category)
```

Mock books respect the active search query and category filter — if a user searches "Alice", mock "Alice in Wonderland" shows up. If they filter by "Fantasy", only Fantasy mock books appear.

### 3.2 Book Card Rendering

**`_BookShelfItem`** gets two changes when mock mode is active:

#### Real Book Card (mock mode active)

Same as current design, plus a small "Demo" badge:

```
┌─────────────────┐
│   Book Cover     │
│   (image)        │
│          [Demo]  │  ← small badge, top-right
├─────────────────┤
│ Title (2 lines)  │
│ Genre Badge      │
└─────────────────┘
```

**Demo badge details:**
- Position: top-right corner (same spot as completed checkmark / quiz badge)
- Style: small pill — `AppColors.warning` background, white bold text, "Demo" label
- Only shown when `mockLibraryEnabled == true` (when mock mode is off, real books look completely normal)
- Does NOT replace completed/quiz badges — if a book is completed, show checkmark instead of Demo badge

#### Mock Book Card

```
┌─────────────────┐
│ ░░░░░░░░░░░░░░░ │  Frosted glass: placeholder bg
│ ░░░░░░░░░░░░░░░ │  + BackdropFilter(blur)
│ ░░░░ 🔒 ░░░░░░ │  + white overlay (0.3 opacity)
│ ░░░░░░░░░░░░░░░ │  + lock icon (centered, no label)
│ ░░░░░░░░░░░░░░░ │
├─────────────────┤
│ Title (2 lines)  │  Normal title text
│ Genre Badge      │  Normal genre pill
└─────────────────┘
   No progress bar
   No tap response
```

**Mock card visual details:**
- Background: `AppColors.neutral.withOpacity(0.15)` base color
- Blur: `ImageFilter.blur(sigmaX: 8, sigmaY: 8)` via `BackdropFilter`
- Overlay: semi-transparent white `Container(color: Colors.white.withOpacity(0.3))`
- Lock icon: `Icons.lock_rounded`, size 32, `AppColors.neutralText` (centered, no text below)
- Card border: same as normal cards but slightly more transparent (`AppColors.neutral.withOpacity(0.5)`)
- No `PressableScale` wrapper — replaced with plain `Container`

### 3.3 Shelf Progress

Mock books do NOT count toward shelf progress calculations. The progress bar (completed/total) only reflects real books.

---

## 4. System Settings Integration

### 4.1 Entity

Add to `SystemSettings`:
```dart
final bool mockLibraryEnabled;  // default: false
```

### 4.2 Model

Add parsing in `SystemSettingsModel.fromRows()`:
```dart
mockLibraryEnabled: _getBool(map, 'mock_library_enabled', false),
```

### 4.3 Provider Access

Library screen reads via existing `systemSettingsProvider`:
```dart
final mockEnabled = ref.watch(systemSettingsProvider).valueOrNull?.mockLibraryEnabled ?? false;
```

---

## 5. Files Changed

| File | Change Type | Description |
|------|-------------|-------------|
| `lib/data/datasources/mock_books_data.dart` | **New** | 150 hardcoded Book entries |
| `lib/domain/entities/book.dart` | Modify | Add `isMock` getter |
| `lib/domain/entities/system_settings.dart` | Modify | Add `mockLibraryEnabled` field |
| `lib/data/models/settings/system_settings_model.dart` | Modify | Parse `mock_library_enabled` |
| `lib/presentation/screens/library/library_screen.dart` | Modify | Inject mock books into `booksByLevelProvider`, render mock card variant |
| `supabase/migrations/XXXXXXXX_add_mock_library_setting.sql` | **New** | Insert `mock_library_enabled` row |

---

## 6. Edge Cases

| Scenario | Behavior |
|----------|----------|
| Mock mode off | No mock books shown, no Demo badges on real books, zero performance cost (list never instantiated) |
| Mock mode toggled while user on library screen | Provider rebuilds, mock books appear/disappear |
| Search matches only mock books | Mock books shown alone (no "empty state" triggered) |
| Search matches no books at all (real or mock) | Normal empty state widget shown |
| Category filter active | Mock books filtered by genre too |
| Real book has same title as mock book | Both shown — mock at end of shelf, real in normal position |
| Library lock active (assignment) | Assignment lock applies to real books only; mock books always show locked regardless |
| Real book completed + mock mode on | Completed checkmark shown (no Demo badge) — completion badge takes priority |
| Real book quiz ready + mock mode on | Quiz badge shown (no Demo badge) — quiz badge takes priority |
| Offline mode | Mock books always available (hardcoded, no network needed) |
| Admin panel | Only toggle switch visible, no mock book list preview |

---

## 7. What This Does NOT Do

- Does not modify the `books` database table
- Does not affect book detail, reader, quiz, or any reading flow
- Does not change assignment or lock mechanisms
- Does not add mock books to admin book list
- Does not affect teacher reports or student progress
- Does not require any Supabase edge function changes
