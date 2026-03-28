# Content Blocks

## Audit

### Findings
| # | Category | Issue | Severity | Status |
|---|----------|-------|----------|--------|
| 1 | Dead Code | `ContentBlockType.audio` exists in enum, DB CHECK constraint, and reader switch but is never created — admin UI and JSON import only support text/image/activity. Reader renders it identically to text. | Low | Fixed |

### Checklist Result
- Architecture Compliance: PASS — clean architecture layers respected, shared package enums used, cache-aside repository pattern
- Code Quality: PASS — consistent naming, Either pattern, proper provider lifecycle (autoDispose)
- Dead Code: 1 issue (unreachable `audio` block type)
- Database & Security: PASS — RLS policies restrict writes to teacher/admin, reads to published books or privileged roles, service_role bypass for edge functions
- Edge Cases & UX: PASS — loading placeholders, error states, graceful cache failures, network-offline fallback
- Performance: PASS — indexed by chapter_id + order_index, cache-aside for offline, autoDispose cleanup
- Cross-System Integrity: PASS — activity blocks reference inline_activities via FK with ON DELETE SET NULL, progressive reveal respects activity completion state

---

## Overview

Content Blocks is the structured content system that replaced legacy plain-text chapter content. Each chapter is composed of ordered blocks (text, image, activity) that render sequentially in the reader. Text blocks support word-level audio synchronization for karaoke highlighting. Activity blocks create progressive reveal gates — students must complete each activity before seeing subsequent content. The system includes offline caching via SQLite and admin editing via a drag-and-drop block editor.

## Data Model

### Tables
- **content_blocks** — ordered blocks within a chapter
- **chapters** — `use_content_blocks` boolean flag (migration bridge)
- **inline_activities** — referenced by activity-type blocks (FK: `activity_id`)

### content_blocks Schema

| Column | Type | Description |
|--------|------|-------------|
| id | UUID PK | Block ID |
| chapter_id | UUID FK → chapters | Parent chapter (CASCADE delete) |
| order_index | INTEGER | Display order (UNIQUE per chapter) |
| type | VARCHAR(20) | `text`, `image`, `activity` (also `audio` in CHECK — unused) |
| text | TEXT | Paragraph content (text blocks) |
| audio_url | VARCHAR(500) | Audio file URL (text blocks with audio) |
| word_timings | JSONB | Array of `{word, startIndex, endIndex, startMs, endMs}` |
| audio_start_ms | INTEGER | Block start position in chapter audio |
| audio_end_ms | INTEGER | Block end position in chapter audio |
| image_url | VARCHAR(500) | Image URL (image blocks) |
| caption | TEXT | Image caption (image blocks) |
| activity_id | UUID FK → inline_activities | Linked activity (SET NULL on delete) |

### Indexes
- `idx_content_blocks_chapter` on `(chapter_id)`
- `idx_content_blocks_chapter_order` on `(chapter_id, order_index)`
- `idx_content_blocks_activity` on `(activity_id)` WHERE activity_id IS NOT NULL
- UNIQUE constraint on `(chapter_id, order_index)`

### RLS Policies
- **SELECT**: Authenticated users can read blocks in published books; teacher/head/admin can read all
- **INSERT/UPDATE/DELETE**: teacher/head/admin only
- **service_role**: Full bypass (for edge functions like `generate-chapter-audio`)
- **anon**: Read-only for published books

## Surfaces

### Admin
- **Content Block Editor** (within chapter edit screen):
  - Add blocks: text, image, or activity type
  - Drag-and-drop reorder (batch updates all `order_index` values)
  - Delete with confirmation (cascades to linked inline_activity)
  - **Text block**: Multi-line text editor; green "Ses" badge if audio exists; orange "Bos" badge if empty
  - **Image block**: URL input + optional caption; preview with CachedNetworkImage
  - **Activity block**: Full inline activity editor (4 types: true_false, word_translation, find_words, matching); shows summary when configured
  - **Generate Chapter Audio**: Button calls `generate-chapter-audio` edge function for all text blocks; shows progress count
- **JSON Import**: Validates block structure and activity types during bulk book import
- New chapters automatically set `use_content_blocks = true`

### Student
- **Reader Content Block List**: Renders blocks sequentially with progressive reveal
  - **Text blocks**: Rendered with `ReaderTextBlock` — supports word-level karaoke highlighting, inline play button, vocabulary word underlining
  - **Image blocks**: Rendered with `ReaderImageBlock` — CachedNetworkImage with optional caption
  - **Activity blocks**: Rendered with `ReaderActivityBlock` — delegates to type-specific activity widgets (true_false, word_translation, find_words, matching)
- **Progressive Reveal**: Blocks visible up to and including first incomplete activity; completing an activity reveals the next section
- **Auto-play Chain**: After activity completion → 1s delay → scroll to next block → auto-play audio if available
- **Offline Reading**: Cache-aside pattern with SQLite — reads from cache first, falls back to Supabase, writes successful fetches to cache

### Teacher
N/A — teachers do not interact directly with content blocks. They see reading progress and assignment stats.

## Business Rules

1. **Block types**: 3 types — `text`, `image`, `activity`. Text blocks with `audio_url` handle audio content (no separate audio type).
2. **Order uniqueness**: `(chapter_id, order_index)` has a UNIQUE constraint — no two blocks share the same position.
3. **Progressive reveal**: `_getVisibleBlocks()` iterates blocks in order; stops after the first incomplete activity block. All blocks before it (including the activity) are visible.
4. **Activity completion gate**: An activity block is "complete" when `completedActivities` map contains its `activityId`. This is checked against `inlineActivityStateProvider`.
5. **Legacy bridge**: Chapters with `use_content_blocks = false` render via legacy `ReaderLegacyContent`. New chapters default to `true`.
6. **Activity FK behavior**: `activity_id` uses `ON DELETE SET NULL` — deleting an inline_activity leaves the block as an unconfigured activity placeholder.
7. **Audio generation**: Edge function `generate-chapter-audio` processes text blocks only, populates `audio_url` and `word_timings`.
8. **Word timing format**: JSONB array of `{word, startIndex, endIndex, startMs, endMs}` — character indices into block text, millisecond positions in audio.
9. **Audio segment fields**: `audio_start_ms` and `audio_end_ms` define this block's time slice within chapter-level audio (set by edge function).
10. **Cache strategy**: Cache-aside — local SQLite checked first, Supabase on miss, write-through on success. Cache errors are swallowed (graceful fallback).
11. **Reorder batch**: Admin reorder updates all `order_index` values in a single batch with optimistic UI + rollback on error.
12. **Cascade delete**: Deleting a chapter cascades to all its content_blocks.

## Cross-System Interactions

### Triggers INTO content blocks
- **Chapter creation** (admin) → initial empty block list, `use_content_blocks = true`
- **JSON import** (admin) → bulk block creation with validated structure
- **Audio generation** (edge function) → populates `audio_url`, `word_timings`, `audio_start_ms`, `audio_end_ms`

### Triggers FROM content blocks
- **Activity completion** → XP award (via inline activity system), progressive reveal advances, daily quest progress
- **Audio playback** → word-level highlighting via `AudioSyncController`, scroll-follow behavior
- **Chapter completion** → when all blocks visible and all activities done, chapter can be marked complete

### Data Flow: Reading a Chapter
```
ReaderBody
  → chapterUsesContentBlocksProvider(chapterId)
    → CachedContentBlockRepository.chapterUsesContentBlocks()
      → Try cached chapter row → fall back to Supabase
  → IF true: ReaderContentBlockList
    → contentBlocksProvider(chapterId)
      → CachedContentBlockRepository.getContentBlocks()
        → Try SQLite cache → fall back to Supabase → write to cache
    → _getVisibleBlocks() (progressive reveal filter)
    → _buildBlockWidget() per visible block
      → text/audio → ReaderTextBlock (with karaoke sync)
      → image → ReaderImageBlock
      → activity → ReaderActivityBlock → type-specific widget
  → IF false: ReaderLegacyContent (plain text)
```

## Edge Cases

- **Empty chapter**: No blocks → empty state in reader
- **Activity without inline_activity**: Shows "Not configured" in admin; renders as `ReaderActivityBlock` with null activity (handled gracefully)
- **Offline + cache miss**: Returns `NetworkFailure` → reader shows error state
- **Cache read failure**: Silently falls through to remote fetch (cache is non-critical)
- **Deleted activity FK**: `ON DELETE SET NULL` leaves block as orphaned activity placeholder — admin can re-configure or delete
- **Reorder failure**: Optimistic UI rolled back to previous order on error
- **Audio not ready**: `ReaderTextBlock` falls back to plain text rendering if `AudioService` not initialized
- **Legacy chapters**: `use_content_blocks = false` routes to separate legacy renderer — no block loading attempted

## Test Scenarios

- [ ] Happy path: Create chapter with text → image → activity → text blocks; verify reader renders in order
- [ ] Progressive reveal: Activity block gates content; complete activity → next blocks appear
- [ ] Audio sync: Text block with audio plays with word-level karaoke highlighting
- [ ] Image block: Renders with cached image and caption
- [ ] Activity types: Each of 4 activity types (true_false, word_translation, find_words, matching) renders and completes correctly inline
- [ ] Reorder: Drag blocks in admin → order persists after refresh
- [ ] Delete block: Remove block → confirm dialog → block gone; if activity block, linked activity also deleted
- [ ] Generate audio: Click generate → edge function processes text blocks → audio_url populated
- [ ] Offline: Download book → go offline → reader loads from cache
- [ ] Legacy chapter: Chapter with `use_content_blocks = false` → renders plain text, no block loading
- [ ] Empty chapter: No blocks → reader shows appropriate empty state
- [ ] JSON import: Import book JSON with content blocks → validates structure → creates blocks

## Key Files

### Main App — Domain
- `lib/domain/entities/content/content_block.dart` — ContentBlock + WordTiming entities
- `lib/domain/repositories/content_block_repository.dart` — Repository interface (2 methods)
- `lib/domain/usecases/content/get_content_blocks_usecase.dart` — Load blocks for chapter
- `lib/domain/usecases/content/check_chapter_uses_content_blocks_usecase.dart` — Migration flag check

### Main App — Data
- `lib/data/models/content/content_block_model.dart` — JSON serialization (ContentBlockModel + WordTimingModel)
- `lib/data/repositories/supabase/supabase_content_block_repository.dart` — Remote Supabase queries
- `lib/data/repositories/cached/cached_content_block_repository.dart` — Cache-aside wrapper

### Main App — Presentation
- `lib/presentation/providers/content_block_provider.dart` — 3 providers (blocks, usesBlocks, hasAudio)
- `lib/presentation/widgets/reader/reader_content_block_list.dart` — Main renderer + progressive reveal + audio orchestration
- `lib/presentation/widgets/reader/reader_text_block.dart` — Text rendering with karaoke sync
- `lib/presentation/widgets/reader/reader_image_block.dart` — Image rendering with caption
- `lib/presentation/widgets/reader/reader_activity_block.dart` — Activity type delegation

### Admin
- `owlio_admin/lib/features/books/widgets/content_block_editor.dart` — Block CRUD, reorder, audio generation
- `owlio_admin/lib/features/books/widgets/activity_editor.dart` — Inline activity editor (4 types)

### Shared
- `packages/owlio_shared/lib/src/enums/content_block_type.dart` — ContentBlockType enum

### Database
- `supabase/migrations/20260201000020_create_content_blocks.sql` — Table, indexes, RLS, chapter flag

## Known Issues & Tech Debt

1. ~~**Dead `audio` block type**~~ — Fixed: removed from enum, entity, reader switch, and DB CHECK constraint (migration `20260328900001`).
2. **Legacy dual-render path**: `useContentBlocks` flag means two parallel rendering systems (`ReaderContentBlockList` vs `ReaderLegacyContent`). Legacy path needed until all chapters migrated.
3. **ReaderContentBlockList complexity**: Single widget handles content rendering, progressive reveal, audio sync state, and scroll coordination — candidate for decomposition into focused controllers.
