# Mock Library Mode Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a toggle-able mock library mode that shows 150 hardcoded locked books alongside real books, making the library look full for marketing demos.

**Architecture:** Client-side hardcoded mock Book list injected into the library screen's provider chain when `mock_library_enabled` system setting is true. Mock books render with frosted glass + lock icon; real books get a "Demo" badge. No database book records created.

**Tech Stack:** Flutter/Dart, Riverpod providers, Supabase (settings migration only), BackdropFilter for frosted glass UI

---

### Task 1: Database Migration — Add `mock_library_enabled` Setting

**Files:**
- Create: `supabase/migrations/20260329100001_add_mock_library_setting.sql`

- [ ] **Step 1: Create the migration file**

```sql
-- Add mock library mode toggle to system settings
INSERT INTO system_settings (key, value, category, description, type, sort_order)
VALUES (
  'mock_library_enabled',
  'false',
  'app',
  'Kütüphane Demo Modu — Kilitli demo kitapları kütüphanede göster',
  'boolean',
  100
)
ON CONFLICT (key) DO NOTHING;
```

- [ ] **Step 2: Dry-run the migration**

Run: `supabase db push --dry-run`
Expected: Shows the INSERT will be applied, no errors.

- [ ] **Step 3: Push the migration**

Run: `supabase db push`
Expected: Migration applied successfully.

- [ ] **Step 4: Commit**

```bash
git add supabase/migrations/20260329100001_add_mock_library_setting.sql
git commit -m "feat: add mock_library_enabled system setting migration"
```

---

### Task 2: System Settings — Add `mockLibraryEnabled` Field

**Files:**
- Modify: `lib/domain/entities/system_settings.dart`
- Modify: `lib/data/models/settings/system_settings_model.dart`

- [ ] **Step 1: Add field to SystemSettings entity**

In `lib/domain/entities/system_settings.dart`, add to constructor parameters (after `starRating1`):

```dart
    // Mock library
    this.mockLibraryEnabled = false,
```

Add field declaration (after `starRating1` field):

```dart
  // Mock library
  final bool mockLibraryEnabled;
```

Add to `props` list (after `starRating1`):

```dart
        mockLibraryEnabled,
```

- [ ] **Step 2: Add parsing to SystemSettingsModel**

In `lib/data/models/settings/system_settings_model.dart`:

Add to constructor (after `starRating1`):

```dart
    required this.mockLibraryEnabled,
```

Add field declaration (after `starRating1`):

```dart
  final bool mockLibraryEnabled;
```

In `fromMap` factory, add (after `starRating1` line):

```dart
      mockLibraryEnabled: _toBool(m['mock_library_enabled'], _d.mockLibraryEnabled),
```

In `toEntity()`, add (after `starRating1` line):

```dart
        mockLibraryEnabled: mockLibraryEnabled,
```

- [ ] **Step 3: Verify it compiles**

Run: `cd /Users/wonderelt/Desktop/Owlio && dart analyze lib/domain/entities/system_settings.dart lib/data/models/settings/system_settings_model.dart`
Expected: No issues found.

- [ ] **Step 4: Commit**

```bash
git add lib/domain/entities/system_settings.dart lib/data/models/settings/system_settings_model.dart
git commit -m "feat: add mockLibraryEnabled to system settings entity and model"
```

---

### Task 3: Book Entity — Add `isMock` Getter

**Files:**
- Modify: `lib/domain/entities/book.dart`

- [ ] **Step 1: Add isMock getter**

In `lib/domain/entities/book.dart`, add after the `readingTime` getter (before `@override List<Object?> get props`):

```dart
  /// Whether this is a client-side mock book (not from database)
  bool get isMock => id.startsWith('mock_');
```

- [ ] **Step 2: Verify it compiles**

Run: `cd /Users/wonderelt/Desktop/Owlio && dart analyze lib/domain/entities/book.dart`
Expected: No issues found.

- [ ] **Step 3: Commit**

```bash
git add lib/domain/entities/book.dart
git commit -m "feat: add isMock getter to Book entity"
```

---

### Task 4: Mock Book Data — Create 150 Hardcoded Books

**Files:**
- Create: `lib/data/datasources/mock_books_data.dart`

- [ ] **Step 1: Create the mock books data file**

Create `lib/data/datasources/mock_books_data.dart` with 150 `Book` entries. The file structure:

```dart
import '../../domain/entities/book.dart';

/// 150 mock books for demo/marketing mode.
/// 100 classic titles + 50 original titles.
/// Distributed ~25 per CEFR level (A1–C2).
/// These are never stored in the database.
const kMockBooks = <Book>[
  // ── A1 (25 books) ──────────────────────────────────
  Book(
    id: 'mock_001',
    title: 'The Tortoise and the Hare',
    slug: 'the-tortoise-and-the-hare',
    author: 'Aesop',
    level: 'A1',
    genre: 'Fable',
    chapterCount: 5,
    status: BookStatus.published,
    createdAt: _epoch,
    updatedAt: _epoch,
  ),
  Book(
    id: 'mock_002',
    title: 'The Boy Who Cried Wolf',
    slug: 'the-boy-who-cried-wolf',
    author: 'Aesop',
    level: 'A1',
    genre: 'Fable',
    chapterCount: 5,
    status: BookStatus.published,
    createdAt: _epoch,
    updatedAt: _epoch,
  ),
  // ... (continue for all 150 books)
];

const _epoch = DateTime(2026, 1, 1);
```

The full file must contain all 150 books. Distribution:

**A1 (25 books)** — Short fables, fairy tales, simple stories:
- Classics: The Tortoise and the Hare, The Boy Who Cried Wolf, The Fox and the Grapes, The Ant and the Grasshopper, The Lion and the Mouse, Goldilocks and the Three Bears, The Three Little Pigs, Little Red Riding Hood, The Ugly Duckling, Jack and the Beanstalk, Hansel and Gretel, The Gingerbread Man, Thumbelina, The Elves and the Shoemaker, Puss in Boots, The Golden Goose, The Emperor's New Clothes
- Originals: Sunny the Lost Firefly, The Brave Little Acorn, Milo's First Adventure, Pepper and the Rainbow, The Friendly Cloud, Lily and the Magic Pond, A Hat for Bear, Otto's Big Day

**A2 (25 books)** — Children's classics, adventure:
- Classics: Aesop's Fables, Peter Pan, Pinocchio, The Wonderful Wizard of Oz, Alice in Wonderland, Black Beauty, Heidi, The Secret Garden, A Little Princess, The Wind in the Willows, The Velveteen Rabbit, Bambi, The Happy Prince, The Nutcracker, Stuart Little, Charlotte's Web, James and the Giant Peach
- Originals: The Clockwork Fox, Bridges Over Willowbrook, The Map of Lost Things, Starlight and the Forgotten Cave, Tales from Cedar Street, Lily and the Storm Chaser, The Last Balloon, River's End

**B1 (25 books)** — Young adult classics, mystery:
- Classics: Treasure Island, The Jungle Book, Robin Hood, The Call of the Wild, White Fang, Around the World in 80 Days, Journey to the Center of the Earth, The Prince and the Pauper, Tom Sawyer, A Christmas Carol, Oliver Twist, The Railway Children, Anne of Green Gables, Little Women, Swiss Family Robinson, The Phantom of the Opera, Sherlock Holmes: A Study in Scarlet
- Originals: The Lighthouse Keeper's Secret, Ink and Ember, Frost Hollow, The Silent Compass, Whispers in the Willow Garden, The Cartographer's Apprentice, Echoes of Thornfield, Night Letters

**B2 (25 books)** — Literature, science fiction:
- Classics: 20000 Leagues Under the Sea, The Time Machine, The War of the Worlds, The Invisible Man, Frankenstein, Dracula, The Island of Doctor Moreau, The Strange Case of Dr Jekyll and Mr Hyde, The Hound of the Baskervilles, The Picture of Dorian Gray, Great Expectations, David Copperfield, Jane Eyre, Wuthering Heights, Northanger Abbey, The Scarlet Letter, Gulliver's Travels
- Originals: Beyond the Frozen Ridge, The Meridian Protocol, Glass City, The Frequency of Stars, Hollow Earth Diaries, The Iron Garden, Saltwater Bones, Apex

**C1 (25 books)** — Advanced literature, philosophy:
- Classics: Pride and Prejudice, Sense and Sensibility, Persuasion, The Count of Monte Cristo, Les Misérables, Moby Dick, The Odyssey, Don Quixote, Crime and Punishment, The Brothers Karamazov, Anna Karenina, War and Peace, Madame Bovary, The Three Musketeers, A Tale of Two Cities, Ivanhoe, The Iliad
- Originals: The Weight of Light, Axiom, Refraction, The Ninth Library, The Philosopher's Corridor, The Architecture of Silence, Meridian, The Cartesian Dream

**C2 (25 books)** — Complex classics, original literary fiction:
- Classics: Ulysses, Hamlet, Macbeth, Othello, King Lear, The Divine Comedy, Paradise Lost, Faust, Canterbury Tales, Metamorphoses, Meditations, The Republic, Decameron, Beowulf, The Aeneid, Doctor Faustus, One Thousand and One Nights
- Originals: The Ontology of Rain, Palimpsest, Tessellations, Nocturne in Three Voices, The Apocryphal Hours, Heliograph, Eidolon, The Antechamber

**Genre distribution across all 150:**
Adventure, Fantasy, Mystery, Science Fiction, Fairy Tale, Classic, Fable, Historical Fiction, Horror, Poetry — distributed realistically per level.

- [ ] **Step 2: Verify it compiles**

Run: `cd /Users/wonderelt/Desktop/Owlio && dart analyze lib/data/datasources/mock_books_data.dart`
Expected: No issues found.

- [ ] **Step 3: Commit**

```bash
git add lib/data/datasources/mock_books_data.dart
git commit -m "feat: add 150 hardcoded mock books for library demo mode"
```

---

### Task 5: Library Screen — Inject Mock Books and Render Mock Cards

**Files:**
- Modify: `lib/presentation/screens/library/library_screen.dart`

This is the main integration task. Three changes in this file:

1. `booksByLevelProvider` — append mock books when enabled
2. `_LibraryShelf` — exclude mock books from progress count
3. `_BookShelfItem` — render mock card variant + Demo badge on real books

- [ ] **Step 1: Add imports**

At the top of `lib/presentation/screens/library/library_screen.dart`, add:

```dart
import 'dart:ui';
import '../../../data/datasources/mock_books_data.dart';
import '../../providers/system_settings_provider.dart';
import '../../../domain/entities/system_settings.dart';
```

Note: `dart:ui` is needed for `ImageFilter.blur` in the frosted glass effect.

- [ ] **Step 2: Add `mockLibraryEnabledProvider` convenience provider**

After the `availableCategoriesProvider` definition (around line 69), add:

```dart
/// Whether mock library mode is enabled (from system settings).
final mockLibraryEnabledProvider = Provider<bool>((ref) {
  return ref.watch(systemSettingsProvider).valueOrNull?.mockLibraryEnabled ?? false;
});
```

- [ ] **Step 3: Modify `booksByLevelProvider` to inject mock books**

Replace the existing `booksByLevelProvider` (lines 46–55) with:

```dart
/// Books grouped by level (A1, A2, B1...), sorted by level key.
/// When mock mode is enabled, appends mock books to the end of each level.
final booksByLevelProvider = Provider<Map<String, List<Book>>>((ref) {
  final books = ref.watch(libraryFilteredBooksProvider).valueOrNull ?? [];
  final mockEnabled = ref.watch(mockLibraryEnabledProvider);
  final searchQuery = ref.watch(librarySearchQueryProvider).toLowerCase();
  final selectedCategory = ref.watch(selectedCategoryProvider);

  final map = <String, List<Book>>{};

  // Add real books
  for (var book in books) {
    map.putIfAbsent(book.level.toUpperCase(), () => []).add(book);
  }

  // Append filtered mock books at the end of each level
  if (mockEnabled) {
    for (var mock in kMockBooks) {
      final matchesSearch = searchQuery.isEmpty ||
          mock.title.toLowerCase().contains(searchQuery);
      final matchesCategory =
          selectedCategory == null || mock.genre == selectedCategory;
      if (matchesSearch && matchesCategory) {
        map.putIfAbsent(mock.level.toUpperCase(), () => []).add(mock);
      }
    }
  }

  return Map.fromEntries(
    map.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
  );
});
```

- [ ] **Step 4: Update `availableCategoriesProvider` to include mock book genres**

Replace the existing `availableCategoriesProvider` (lines 58–69) with:

```dart
/// Extracts unique categories from all books (and mock books when enabled) for the filter chips.
final availableCategoriesProvider = Provider<AsyncValue<List<String>>>((ref) {
  final booksAsync = ref.watch(booksProvider(null));
  final mockEnabled = ref.watch(mockLibraryEnabledProvider);
  return booksAsync.whenData((books) {
    final genres = books
        .map((b) => b.genre)
        .where((g) => g != null && g.isNotEmpty)
        .map((g) => g!)
        .toSet();

    // Include mock book genres when mock mode is enabled
    if (mockEnabled) {
      for (var mock in kMockBooks) {
        if (mock.genre != null && mock.genre!.isNotEmpty) {
          genres.add(mock.genre!);
        }
      }
    }

    return genres.toList()..sort();
  });
});
```

- [ ] **Step 5: Update `_LibraryShelf` to exclude mock books from progress**

In the `_LibraryShelf.build()` method, change the progress calculation (lines 299–301) from:

```dart
    final completedIds = ref.watch(completedBookIdsProvider).valueOrNull ?? {};
    final completedCount = books.where((b) => completedIds.contains(b.id)).length;
    final progress = books.isEmpty ? 0.0 : completedCount / books.length;
```

to:

```dart
    final completedIds = ref.watch(completedBookIdsProvider).valueOrNull ?? {};
    final realBooks = books.where((b) => !b.isMock).toList();
    final completedCount = realBooks.where((b) => completedIds.contains(b.id)).length;
    final progress = realBooks.isEmpty ? 0.0 : completedCount / realBooks.length;
```

Also update the header count display. Change the text in the counter pill (line 346) from:

```dart
                  '$completedCount / ${books.length}',
```

to:

```dart
                  '$completedCount / ${realBooks.length}',
```

- [ ] **Step 6: Update `_BookShelfItem` to handle mock books**

Replace the entire `_BookShelfItem` class with:

```dart
class _BookShelfItem extends ConsumerWidget {
  final Book book;

  const _BookShelfItem({required this.book});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Mock books: simplified locked card
    if (book.isMock) {
      return _MockBookCard(book: book);
    }

    final canAccess = ref.watch(canAccessBookProvider(book.id));
    final isCompleted = ref.watch(completedBookIdsProvider).valueOrNull?.contains(book.id) ?? false;
    final isQuizReady = ref.watch(isQuizReadyProvider(book.id)).valueOrNull ?? false;
    final progress = ref.watch(readingProgressProvider(book.id)).valueOrNull;
    final percentage = progress?.completionPercentage ?? 0;
    final mockEnabled = ref.watch(mockLibraryEnabledProvider);

    return PressableScale(
      onTap: () {
        if (canAccess) {
          context.go(AppRoutes.bookDetailPath(book.id));
        } else {
           showDialog(
             context: context,
             builder: (_) => AlertDialog(
               shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
               title: Text("Locked", style: GoogleFonts.fredoka(fontSize: 24, color: AppColors.danger)),
               content: Text(
                 "Complete your assignment to read this book.",
                 style: GoogleFonts.nunito(fontSize: 16),
               ),
               actions: [
                 TextButton(
                   onPressed: () => Navigator.pop(context),
                   child: Text("OK", style: GoogleFonts.fredoka(fontSize: 18, color: AppColors.primary))
                 )
               ],
             ),
           );
        }
      },
      child: Container(
        width: 140,
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.neutral, width: 2),
          boxShadow: [
            BoxShadow(
              color: AppColors.neutral.withOpacity(0.6),
              offset: const Offset(0, 4),
              blurRadius: 0,
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                    child: CachedBookImage(
                      imageUrl: book.coverUrl,
                      fit: BoxFit.cover,
                      errorWidget: Container(
                        color: AppColors.neutral.withOpacity(0.2),
                        child: Center(child: Icon(Icons.menu_book_rounded, size: 40, color: AppColors.neutralText)),
                      ),
                    ),
                  ),
                  if (!canAccess)
                    Container(
                      color: Colors.black.withOpacity(0.5),
                      child: const Center(child: Icon(Icons.lock_rounded, color: Colors.white, size: 36)),
                    ),
                  if (isCompleted)
                     Positioned(
                        top: 8, right: 8,
                        child: Container(
                           padding: const EdgeInsets.all(6),
                           decoration: BoxDecoration(
                             color: AppColors.success,
                             shape: BoxShape.circle,
                             border: Border.all(color: Colors.white, width: 2),
                           ),
                           child: const Icon(Icons.check_rounded, color: Colors.white, size: 16),
                        ),
                     ),
                  if (!isCompleted && isQuizReady)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.quiz_rounded, size: 12, color: Colors.white),
                            const SizedBox(width: 3),
                            Text(
                              'Quiz',
                              style: GoogleFonts.nunito(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  // Demo badge (only when mock mode is on and book has no other badge)
                  if (mockEnabled && !isCompleted && !isQuizReady)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.wasp,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Demo',
                          style: GoogleFonts.nunito(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // Reading progress bar
            if (percentage > 0 && percentage < 100)
              ClipRRect(
                child: LinearProgressIndicator(
                  value: percentage / 100,
                  backgroundColor: AppColors.neutral.withValues(alpha: 0.3),
                  color: AppColors.secondary,
                  minHeight: 3,
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    book.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.nunito(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                      color: AppColors.black,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      book.genre?.toUpperCase() ?? 'GENERAL',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.nunito(
                        fontSize: 9,
                        color: AppColors.neutralText,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 7: Create `_MockBookCard` widget**

Add this new widget class after `_BookShelfItem` (before `_EmptyState`):

```dart
class _MockBookCard extends StatelessWidget {
  final Book book;

  const _MockBookCard({required this.book});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 140,
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.neutral.withOpacity(0.5), width: 2),
        boxShadow: [
          BoxShadow(
            color: AppColors.neutral.withOpacity(0.4),
            offset: const Offset(0, 4),
            blurRadius: 0,
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Base placeholder
                  Container(color: AppColors.neutral.withOpacity(0.15)),
                  // Frosted glass effect
                  BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                    child: Container(color: Colors.white.withOpacity(0.3)),
                  ),
                  // Lock icon
                  Center(
                    child: Icon(
                      Icons.lock_rounded,
                      size: 32,
                      color: AppColors.neutralText.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  book.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.nunito(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                    color: AppColors.black,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    book.genre?.toUpperCase() ?? 'GENERAL',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.nunito(
                      fontSize: 9,
                      color: AppColors.neutralText,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 8: Update `_EmptyState` to account for mock books**

In the `LibraryScreen.build()` method, the empty state check (line 247) currently checks `books.isEmpty`. When mock mode is on and there are no real books but mock books exist, we still want to show the shelves. Update the data branch (lines 246–267) to:

```dart
                data: (books) {
                  final booksByLevel = ref.watch(booksByLevelProvider);

                  if (booksByLevel.isEmpty) {
                    return _EmptyState(isSearchActive: isSearchActive);
                  }

                  return CustomScrollView(
                    physics: const BouncingScrollPhysics(),
                    slivers: [
                      const SliverToBoxAdapter(child: SizedBox(height: 12)),
                      for (final level in booksByLevel.keys)
                        SliverToBoxAdapter(
                          child: _LibraryShelf(
                            level: level,
                            books: booksByLevel[level]!,
                          ),
                        ),
                      const SliverPadding(padding: EdgeInsets.only(bottom: 40)),
                    ],
                  );
                },
```

- [ ] **Step 9: Verify it compiles**

Run: `cd /Users/wonderelt/Desktop/Owlio && dart analyze lib/presentation/screens/library/library_screen.dart`
Expected: No issues found.

- [ ] **Step 10: Commit**

```bash
git add lib/presentation/screens/library/library_screen.dart
git commit -m "feat: integrate mock books into library screen with frosted glass cards and Demo badge"
```

---

### Task 6: Full App Verification

- [ ] **Step 1: Run full analysis**

Run: `cd /Users/wonderelt/Desktop/Owlio && dart analyze lib/`
Expected: No issues found (or only pre-existing warnings unrelated to our changes).

- [ ] **Step 2: Run tests**

Run: `cd /Users/wonderelt/Desktop/Owlio && flutter test`
Expected: All existing tests pass.

- [ ] **Step 3: Manual verification**

1. Open admin panel → Settings → `app` category → verify `mock_library_enabled` toggle appears (labeled "Kütüphane Demo Modu")
2. Toggle OFF → Library screen shows only real books, no Demo badges
3. Toggle ON → Library screen shows real books with "Demo" badge + mock books with frosted glass + lock icon at end of each shelf
4. Search for a mock book title → verify it appears in results
5. Filter by a category that only mock books have → verify mock books shown
6. Tap a mock book → verify nothing happens (no navigation, no dialog)
7. Tap a real book → verify normal navigation to book detail
8. Verify shelf progress (X / Y count) only counts real books

- [ ] **Step 4: Final commit (if any fixes needed)**

```bash
git add -A
git commit -m "fix: address mock library mode verification findings"
```
