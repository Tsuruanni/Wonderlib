# Reader Sidebar Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a dedicated Reader Sidebar (300px left column) with chapters list and audio player, fix font not being applied to reader body text, and consolidate audio controls to prevent duplication.

**Architecture:** Reader sidebar is a new widget that only appears on reader routes at ≥1000px. The shell detects the reader route and inserts the sidebar between the main nav sidebar and reader content. Right panel loses all reader-specific widgets (chapters, audio, settings stay only in right panel at ≥1200px). Font fix adds `GoogleFonts.getFont()` calls to all reader text styles.

**Tech Stack:** Flutter, Riverpod, GoRouter, GoogleFonts

---

### Task 1: Add `ReaderFont` → `GoogleFonts` TextStyle Helper

**Files:**
- Modify: `lib/presentation/providers/reader_provider.dart:47-58`

- [ ] **Step 1: Add extension on ReaderFont enum**

After the `ReaderFont` enum definition (line 58), add:

```dart
import 'package:google_fonts/google_fonts.dart';

extension ReaderFontX on ReaderFont {
  TextStyle textStyle({
    double? fontSize,
    double? height,
    Color? color,
    FontWeight? fontWeight,
    TextDecoration? decoration,
    Color? decorationColor,
    TextDecorationStyle? decorationStyle,
  }) {
    return GoogleFonts.getFont(
      displayName,
      fontSize: fontSize,
      height: height,
      color: color,
      fontWeight: fontWeight,
      decoration: decoration,
      decorationColor: decorationColor,
      decorationStyle: decorationStyle,
    );
  }
}
```

- [ ] **Step 2: Add import**

Add at top of file:

```dart
import 'package:google_fonts/google_fonts.dart';
```

- [ ] **Step 3: Verify**

Run: `dart analyze lib/presentation/providers/reader_provider.dart`
Expected: No errors

---

### Task 2: Apply Font to Reader Text Widgets

**Files:**
- Modify: `lib/presentation/widgets/reader/reader_word_highlight.dart:176-180`
- Modify: `lib/presentation/widgets/reader/reader_paragraph.dart` (lines 33, 49, 102, 188)
- Modify: `lib/presentation/widgets/reader/reader_text_block.dart:40`

- [ ] **Step 1: Fix `reader_word_highlight.dart` — `_baseTextStyle`**

Replace line 176-180:

```dart
TextStyle get _baseTextStyle => widget.settings.font.textStyle(
      fontSize: widget.settings.fontSize,
      height: widget.settings.lineHeight,
      color: widget.settings.theme.text,
    );
```

Also fix `_buildRegularWordSpan` (line 259-265) — replace the inline TextStyle:

```dart
child: Text(
  word,
  style: widget.settings.font.textStyle(
    fontSize: widget.settings.fontSize,
    height: widget.settings.lineHeight,
    color: widget.settings.theme.text,
    fontWeight: isActive ? FontWeight.bold : null,
  ),
),
```

Also fix `_buildVocabularyWordSpan` (line 324-331):

```dart
child: Text(
  word,
  style: widget.settings.font.textStyle(
    fontSize: widget.settings.fontSize,
    height: widget.settings.lineHeight,
    color: widget.settings.theme.text,
    fontWeight: isActive ? FontWeight.bold : null,
    decoration: TextDecoration.underline,
    decorationColor: const Color(0xFF4F46E5).withValues(alpha: 0.5),
    decorationStyle: TextDecorationStyle.dotted,
  ),
),
```

Also fix `_buildSimpleWordSpans` Text widget (line 159-162):

```dart
child: Text(
  word,
  style: _baseTextStyle,
),
```

- [ ] **Step 2: Fix `reader_paragraph.dart`**

Line 32-35 (onWordTap branch TextStyle):

```dart
style: settings.font.textStyle(
  fontSize: settings.fontSize,
  height: settings.lineHeight,
  color: settings.theme.text,
),
```

Line 49-52 (legacy SelectableText.rich style):

```dart
style: settings.font.textStyle(
  fontSize: settings.fontSize,
  height: settings.lineHeight,
  color: settings.theme.text,
),
```

Line 101-104 (`_buildTappableWordSpan` Text style):

```dart
child: Text(
  word,
  style: settings.font.textStyle(
    fontSize: settings.fontSize,
    height: settings.lineHeight,
    color: settings.theme.text,
  ),
),
```

Line 185-191 (`_buildVocabularySpan` Text style):

```dart
child: Text(
  displayText,
  style: settings.font.textStyle(
    fontSize: settings.fontSize,
    height: settings.lineHeight,
    color: settings.theme.text,
    decoration: TextDecoration.underline,
    decorationColor: const Color(0xFF4F46E5).withValues(alpha: 0.5),
    decorationStyle: TextDecorationStyle.dotted,
  ),
),
```

- [ ] **Step 3: Fix `reader_text_block.dart`**

Line 40 (fallback when audio not ready):

```dart
child: Text(text, style: settings.font.textStyle(fontSize: settings.fontSize)),
```

- [ ] **Step 4: Verify**

Run: `dart analyze lib/presentation/widgets/reader/`
Expected: No errors

- [ ] **Step 5: Commit**

```bash
git add lib/presentation/providers/reader_provider.dart lib/presentation/widgets/reader/reader_word_highlight.dart lib/presentation/widgets/reader/reader_paragraph.dart lib/presentation/widgets/reader/reader_text_block.dart
git commit -m "fix: apply selected font family to reader body text via GoogleFonts"
```

---

### Task 3: Create Reader Sidebar Widget

**Files:**
- Create: `lib/presentation/widgets/reader/reader_sidebar.dart`

- [ ] **Step 1: Create the sidebar widget**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/router.dart';
import '../../../app/theme.dart';
import '../../../core/services/audio_service.dart';
import '../../../domain/entities/chapter.dart';
import '../../providers/audio_sync_provider.dart';
import '../../providers/book_provider.dart';
import '../../providers/reader_provider.dart';

/// Reader sidebar shown on wide screens (≥1000px) during reader routes.
/// Top: scrollable chapters list. Bottom: sticky audio player.
class ReaderSidebar extends ConsumerWidget {
  const ReaderSidebar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = GoRouterState.of(context).uri.path;
    final segments = location.split('/');
    final bookId = segments.length > 2 ? segments[2] : '';
    final currentChapterId = segments.length > 3 ? segments[3] : '';

    return Container(
      width: 300,
      decoration: const BoxDecoration(
        color: AppColors.white,
        border: Border(
          right: BorderSide(color: AppColors.neutral, width: 2),
        ),
      ),
      child: Column(
        children: [
          // Chapters list (scrollable, takes remaining space)
          Expanded(
            child: _ChaptersList(
              bookId: bookId,
              currentChapterId: currentChapterId,
            ),
          ),
          // Audio player (sticky bottom)
          const _SidebarAudioPlayer(),
        ],
      ),
    );
  }
}

// ─── Chapters List ───

class _ChaptersList extends ConsumerWidget {
  const _ChaptersList({
    required this.bookId,
    required this.currentChapterId,
  });

  final String bookId;
  final String currentChapterId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chaptersAsync = ref.watch(chaptersProvider(bookId));
    final bookAsync = ref.watch(bookByIdProvider(bookId));

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Book title
          bookAsync.when(
            data: (book) => Text(
              book?.title ?? 'Chapters',
              style: GoogleFonts.nunito(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.black,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => Text(
              'Chapters',
              style: GoogleFonts.nunito(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.black,
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Chapter list
          chaptersAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
            error: (_, __) => Text(
              'Could not load chapters',
              style: GoogleFonts.nunito(color: AppColors.neutralText),
            ),
            data: (chapters) {
              final completedIds = ref.watch(
                readingProgressProvider(bookId)
                    .select((v) => v.valueOrNull?.completedChapterIds ?? []),
              );
              final currentIdx =
                  chapters.indexWhere((c) => c.id == currentChapterId);

              return Column(
                children: [
                  for (int i = 0; i < chapters.length; i++) ...[
                    if (i > 0) const SizedBox(height: 4),
                    _ChapterTile(
                      chapter: chapters[i],
                      index: i,
                      isCurrent: chapters[i].id == currentChapterId,
                      isCompleted: completedIds.contains(chapters[i].id),
                      isLocked: !completedIds.contains(chapters[i].id) &&
                          i > currentIdx,
                      onTap: () => context.go(
                        AppRoutes.readerPath(bookId, chapters[i].id),
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ChapterTile extends StatelessWidget {
  const _ChapterTile({
    required this.chapter,
    required this.index,
    required this.isCurrent,
    required this.isCompleted,
    required this.onTap,
    this.isLocked = false,
  });

  final Chapter chapter;
  final int index;
  final bool isCurrent;
  final bool isCompleted;
  final bool isLocked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isLocked ? null : onTap,
      child: Opacity(
        opacity: isLocked ? 0.4 : 1.0,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: isCurrent
                ? AppColors.secondary.withValues(alpha: 0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: isCurrent
                ? Border.all(
                    color: AppColors.secondary.withValues(alpha: 0.3),
                    width: 2)
                : null,
          ),
          child: Row(
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: isCurrent
                      ? AppColors.secondary
                      : isCompleted
                          ? AppColors.primary
                          : AppColors.neutral.withValues(alpha: 0.5),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: isCompleted && !isCurrent
                      ? const Icon(Icons.check_rounded,
                          color: Colors.white, size: 14)
                      : Text(
                          '${index + 1}',
                          style: GoogleFonts.nunito(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: isCurrent || isCompleted
                                ? Colors.white
                                : AppColors.neutralText,
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  chapter.title,
                  style: GoogleFonts.nunito(
                    fontSize: 13,
                    fontWeight: isCurrent ? FontWeight.w800 : FontWeight.w600,
                    color: isCurrent ? AppColors.secondary : AppColors.black,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Sidebar Audio Player (Sticky Bottom) ───

class _SidebarAudioPlayer extends ConsumerWidget {
  const _SidebarAudioPlayer();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final audioReady = ref.watch(audioServiceProvider).hasValue;
    if (!audioReady) return const SizedBox.shrink();

    final AudioSyncState audioState;
    try {
      audioState = ref.watch(audioSyncControllerProvider);
    } catch (_) {
      return const SizedBox.shrink();
    }

    // Show nothing if no audio loaded
    if (audioState.currentBlockId == null) {
      return _EmptyAudioPlaceholder();
    }

    final isPlaying = audioState.isPlaying;
    final progress = audioState.progress;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.white,
        border: Border(
          top: BorderSide(color: AppColors.neutral, width: 2),
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Play/pause + progress
          Row(
            children: [
              GestureDetector(
                onTap: () {
                  final controller =
                      ref.read(audioSyncControllerProvider.notifier);
                  if (isPlaying) {
                    controller.pause();
                  } else {
                    controller.play();
                  }
                },
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    color: AppColors.secondary,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isPlaying
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: progress,
                        backgroundColor: AppColors.neutral,
                        color: AppColors.secondary,
                        minHeight: 6,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          audioState.positionFormatted,
                          style: GoogleFonts.nunito(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.neutralText,
                          ),
                        ),
                        Text(
                          audioState.durationFormatted,
                          style: GoogleFonts.nunito(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.neutralText,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Speed + listening mode row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Speed button
              GestureDetector(
                onTap: () {
                  ref.read(audioSyncControllerProvider.notifier).cycleSpeed();
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.neutral, width: 2),
                  ),
                  child: Text(
                    '${audioState.playbackSpeed}x',
                    style: GoogleFonts.nunito(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.black,
                    ),
                  ),
                ),
              ),
              // Close button
              GestureDetector(
                onTap: () {
                  ref.read(audioSyncControllerProvider.notifier).stop();
                },
                child: Icon(
                  Icons.close_rounded,
                  color: AppColors.neutralText,
                  size: 22,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptyAudioPlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.white,
        border: Border(
          top: BorderSide(color: AppColors.neutral, width: 2),
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.neutral.withValues(alpha: 0.5),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.headphones_rounded,
              color: AppColors.neutralText,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Tap a paragraph to play audio',
              style: GoogleFonts.nunito(
                fontSize: 13,
                color: AppColors.neutralText,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Verify**

Run: `dart analyze lib/presentation/widgets/reader/reader_sidebar.dart`
Expected: No errors

---

### Task 4: Integrate Reader Sidebar into Shell

**Files:**
- Modify: `lib/presentation/widgets/shell/main_shell_scaffold.dart`

- [ ] **Step 1: Add import**

```dart
import '../../widgets/reader/reader_sidebar.dart';
```

- [ ] **Step 2: Update the wide-screen layout in `build()` method**

Replace lines 119-151 (the `Expanded` content + right panel block) with:

```dart
Expanded(
  child: Builder(
    builder: (context) {
      final location = GoRouterState.of(context).uri.path;
      final isFullWidth = location.startsWith(AppRoutes.vocabulary);
      final isReader = location.startsWith('/reader');
      final showReaderSidebar = isReader && screenWidth >= 1000;
      final showRightPanel = screenWidth >= 1000 && !isReader ||
          screenWidth >= 1200 && isReader;

      if (isFullWidth) {
        return Row(
          children: [
            Expanded(child: navigationShell),
            if (showRightPanel) const RightInfoPanel(),
          ],
        );
      }

      return Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: showRightPanel ? 1060 : 800,
          ),
          child: Row(
            children: [
              if (showReaderSidebar) const ReaderSidebar(),
              Expanded(child: navigationShell),
              if (showRightPanel) const RightInfoPanel(),
            ],
          ),
        ),
      );
    },
  ),
),
```

Also remove the old `showRightPanel` variable from the top of build() (line 59) since the logic is now inside the Builder.

- [ ] **Step 3: Verify**

Run: `dart analyze lib/presentation/widgets/shell/main_shell_scaffold.dart`
Expected: No errors

---

### Task 5: Clean Up Right Info Panel (Remove Reader-Specific Widgets)

**Files:**
- Modify: `lib/presentation/widgets/shell/right_info_panel.dart`

- [ ] **Step 1: Update `RightInfoPanel.build()` to remove reader panel branch**

Replace lines 28-64 with:

```dart
@override
Widget build(BuildContext context, WidgetRef ref) {
  final location = GoRouterState.of(context).uri.path;
  final isReader = location.startsWith('/reader');
  final showPackCard = location.startsWith(AppRoutes.cards);

  return SizedBox(
    width: 330,
    child: Column(
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 12, 20, 0),
          child: _StatsBar(),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              children: [
                if (showPackCard) ...[
                  const _OpenPackCard(),
                  const SizedBox(height: 16),
                ],
                if (isReader) ...[
                  const _ReaderSettingsCard(),
                  const SizedBox(height: 16),
                ],
                const _LeagueCard(),
                const SizedBox(height: 16),
                const _DailyQuestsCard(),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}
```

- [ ] **Step 2: Remove `_ReaderPanel` class (lines 533-574)**

Delete the entire `_ReaderPanel` class.

- [ ] **Step 3: Remove `_AudioControlBar` class (lines 978-1071)**

Delete the entire `_AudioControlBar` class.

- [ ] **Step 4: Remove `_ChaptersCard` and `_ChapterTile` classes (lines 801-973)**

Delete `_ChaptersCard` and `_ChapterTile` classes entirely (they now live in `reader_sidebar.dart`).

- [ ] **Step 5: Clean up unused imports**

Remove imports that are no longer needed:
- `'../../providers/audio_sync_provider.dart'` (if only used by removed audio bar)

Keep: `'../../providers/reader_provider.dart'` (used by `_ReaderSettingsCard`)

- [ ] **Step 6: Verify**

Run: `dart analyze lib/presentation/widgets/shell/right_info_panel.dart`
Expected: No errors

---

### Task 6: Hide Floating Audio Controls on Wide Screens

**Files:**
- Modify: `lib/presentation/screens/reader/reader_screen.dart:314-320`

- [ ] **Step 1: Wrap floating audio controls with width check**

Replace lines 314-320:

```dart
// Floating audio player controls — only on narrow screens
// (wide screens use the reader sidebar's audio player)
Builder(
  builder: (context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    if (screenWidth >= 1000) return const SizedBox.shrink();
    return Positioned(
      left: 0,
      right: 0,
      top: MediaQuery.of(context).padding.top + 44,
      child: ReaderAudioControls(settings: settings),
    );
  },
),
```

- [ ] **Step 2: Verify**

Run: `dart analyze lib/presentation/screens/reader/reader_screen.dart`
Expected: No errors

- [ ] **Step 3: Commit all changes**

```bash
git add -A
git commit -m "feat: reader sidebar with chapters + audio, font fix, audio consolidation"
```

---

### Task 7: Verify Full Build

- [ ] **Step 1: Run full analysis**

Run: `dart analyze lib/`
Expected: No errors related to our changes

- [ ] **Step 2: Run web build**

Run: `flutter build web --release`
Expected: Successful build
