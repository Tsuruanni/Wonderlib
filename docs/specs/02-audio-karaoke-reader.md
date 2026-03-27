# Audio/Karaoke Reader

## Audit

### Findings

| # | Category | Issue | Severity | Status |
|---|----------|-------|----------|--------|
| 1 | Dead Code | `showDropCap` param in `ReaderTextBlock` — accepted but never used | Low | Fixed |
| 2 | Dead Code | `textBlocksProvider`, `activityBlocksProvider`, `audioBlocksProvider` in `content_block_provider.dart` — defined but never consumed | Low | Fixed |
| 3 | Edge Case | `AudioSyncState.error` was set on audio load failure but never rendered — user got silent failure | Medium | Fixed |
| 4 | Code Quality | `WordPronunciationService` contained 9 `debugPrint` statements — excessive for production | Low | Fixed |
| 5 | Dead Code | `WordTiming.isActiveAt()` and `WordTiming.durationMs` — entity helper methods not called anywhere | Low | Fixed |

### Checklist Result

- **Architecture Compliance**: PASS — Clean architecture layers fully respected. Screen -> Provider -> UseCase -> Repository chain intact. No business logic in widgets. JSON handled in Model layer. `DbTables.contentBlocks` used in main app. Shared package `ContentBlockType` enum used.
- **Code Quality**: PASS — Either pattern used. Naming consistent. Provider lifecycle correct (`autoDispose`). Debug prints cleaned up.
- **Dead Code**: PASS — All unused providers, parameters, and entity methods removed.
- **Database & Security**: PASS — RLS policies exist (published book read access, teacher/admin write). Cascading delete on `chapter_id`. Indexes on `chapter_id` and `(chapter_id, order_index)`. No RPC functions involved in audio playback.
- **Edge Cases & UX**: PASS — Audio load error now surfaces via error pill in controls area. Loading state shown (spinner). Empty state handled (no audio icon if no audio). Web fallback for TTS.
- **Performance**: PASS — Binary search O(log n) for word sync. Audio URL reload optimization (`needsReload` check). File cache for offline. Family providers prevent unnecessary rebuilds.
- **Cross-System Integrity**: PASS — Audio completion does NOT trigger XP (correct). Audio stops before all navigation events. TTS ducks main audio volume. Activity completion triggers auto-play only in listening mode.

---

## Overview

The Audio/Karaoke Reader provides word-level synchronized audio playback within the book reader. Students hear chapter text read aloud while individual words highlight in real-time (karaoke-style). The system supports two audio models: per-block audio (separate file per paragraph) and chapter-level audio (single file with segment boundaries). Features include listening mode (continuous auto-play across blocks), scroll following, speed control, and offline playback via file caching.

## Data Model

### `content_blocks` table (audio-relevant columns)

| Column | Type | Purpose |
|--------|------|---------|
| `audio_url` | VARCHAR(500) | URL to MP3/WAV file (per-block or chapter-level) |
| `word_timings` | JSONB | Array of `{word, startIndex, endIndex, startMs, endMs}` |
| `audio_start_ms` | INTEGER | Segment start position within chapter audio (null for per-block) |
| `audio_end_ms` | INTEGER | Segment end position within chapter audio (null for per-block) |

### `vocabulary_words` table (audio-relevant columns)

| Column | Type | Purpose |
|--------|------|---------|
| `audio_url` | VARCHAR | URL to batch vocab audio file |
| `audio_start_ms` | INTEGER | Word segment start |
| `audio_end_ms` | INTEGER | Word segment end |

### `cached_files` table (sqflite, local)

| Column | Type | Purpose |
|--------|------|---------|
| `url` | TEXT | Remote URL (key) |
| `book_id` | TEXT | Organizes files per book |
| `local_path` | TEXT | Downloaded file path |
| `file_type` | TEXT | `'audio'` or `'image'` |
| `file_size` | INTEGER | File size in bytes |

### Key relationships

- `content_blocks.chapter_id` -> `chapters.id` (CASCADE delete)
- `chapters.use_content_blocks` flag determines if reader uses content blocks or legacy `content` field
- Audio files stored in Supabase Storage, URLs in `audio_url`

## Two Audio Models

**Per-block audio**: Each content block has its own audio file.
- `audio_url` points to individual MP3
- `word_timings` timestamps are relative to this file
- `audio_start_ms` / `audio_end_ms` are NULL

**Chapter-level (segment) audio**: One audio file for entire chapter.
- All blocks share the same `audio_url` (chapter audio file)
- `audio_start_ms` / `audio_end_ms` define each block's segment
- `word_timings` have absolute timestamps within the chapter file
- Optimization: audio source only reloaded when URL changes between blocks

## Surfaces

### Admin

- **Content block editor** (`content_block_editor.dart`): Admin edits `audio_url` and `word_timings` per block
- **Chapter audio generation**: Admin triggers ElevenLabs TTS via Supabase Edge Functions (`generate-chapter-audio`, `generate-audio-sync`)
  - `generate-chapter-audio`: Generates audio from block text via ElevenLabs API, uploads to Supabase Storage
  - `generate-audio-sync`: Generates word-level timing data, writes to `word_timings` JSONB
  - `migrate-audio-to-storage`: Migration utility for moving audio files to Supabase Storage
- **Vocabulary audio**: Admin can set `audio_url` + segment bounds for vocab words

### Student

**User flow:**

1. Open chapter in reader
2. Text blocks render with inline headphone icon (if audio available)
3. Student taps headphone icon -> audio loads and plays
4. Words highlight in yellow (karaoke-style) as audio plays
5. Floating audio controls appear (speed, play/pause, close)
6. Reader auto-scrolls to keep active word visible
7. When audio block completes:
   - If next block is text with audio: auto-plays after 500ms delay
   - If next block is activity: activity must be completed first
   - After activity completion (if in listening mode): auto-plays next audio after 1000ms delay
8. Student can tap any word for TTS pronunciation (main audio ducks to 20% volume)
9. Student can manually scroll (disables auto-scroll follow, audio continues)
10. Pressing play again re-enables scroll follow

**Key screens:**
- `reader_screen.dart` — Screen lifecycle, audio stop on navigation
- `reader_body.dart` — Scroll detection (user drag disables follow)
- `reader_content_block_list.dart` — Progressive reveal, auto-scroll, activity completion detection
- `reader_text_block.dart` — Inline play icon, block-level audio state
- `reader_word_highlight.dart` — Karaoke word highlighting, vocabulary underlines
- `reader_audio_controls.dart` — Floating pill controls (speed/play/close)

### Teacher

N/A — Teachers have no audio-specific views.

## Business Rules

1. **Never auto-play on chapter load** — User must manually press play to start first audio block.
2. **Listening mode gates auto-play** — Auto-play between blocks only triggers when `_isInListeningMode == true`. This flag is set on play, stays true on audio completion, resets on pause/stop.
3. **Pause exits listening mode** — Pressing pause stops auto-play chain (unlike a natural audio completion).
4. **Scroll follow enables on play, disables on user drag** — Programmatic scroll (`Scrollable.ensureVisible`) does not disable follow; user finger drag (`dragDetails != null`) does.
5. **Progressive reveal blocks audio** — Activity blocks must be completed before subsequent content is visible. Auto-play respects this: it only plays blocks within the visible set.
6. **Segment end buffer** — Chapter-level audio adds 300ms buffer past `audio_end_ms` to allow natural TTS decay before cutting to next block.
7. **Audio URL reload optimization** — When switching between blocks that share the same chapter audio URL, the audio source is not reloaded; only a seek is performed.
8. **TTS ducks main audio** — Word pronunciation via TTS reduces main audio volume to 0.2 and restores to 1.0 after speech completes (web fallback: 1500ms timer).
9. **Audio stops on all navigation** — Leaving the chapter (next chapter, back to book, close, take quiz) always calls `audioSyncController.stop()` first.
10. **Playback speeds** — Cycles through `[0.75, 1.0, 1.25, 1.5, 2.0]`.
11. **Offline audio** — `FileCacheService.resolveUrl()` checks local cache first; if file exists on disk, plays from local path instead of remote URL.

## Cross-System Interactions

- **Audio completion -> NO XP** — Audio playback itself does not award XP. XP is only earned through activity completion or chapter completion.
- **Activity completion -> auto-play** — When student completes an inline activity, `onActivityCompleted()` triggers next audio block if in listening mode.
- **Word tap -> TTS pronunciation** — `WordPronunciationService.speak()` ducks main audio, speaks word, restores volume. Separate from main audio pipeline.
- **Offline caching** — `BookDownloadService` pre-downloads audio files via `FileCacheService.getOrDownload()`. Reader uses `resolveUrl()` to prefer local path.
- **Audio session** — `AudioSession` configured for speech; handles OS interruptions (duck on music, pause on phone call).

## Edge Cases

- **No audio on any block**: Play icons don't render. Audio controls never appear. Reader works as pure text.
- **Audio load failure**: Error stored in `AudioSyncState.error` but **not displayed to user** (finding #3). Controls remain hidden since no block is loaded.
- **User scrolls during playback**: Auto-scroll follow disabled, audio continues playing, word highlighting continues. Re-pressing play re-enables follow.
- **Chapter with mixed audio/non-audio blocks**: Only blocks with `hasAudio == true` show play icons. Auto-play skips non-audio blocks to find next audio block.
- **Activity interrupts listening flow**: Auto-play pauses at activity blocks. If student was in listening mode, auto-play resumes after activity completion.
- **Web TTS unreliable**: Completion callback may not fire on web. 1500ms fallback timer restores main audio volume.
- **Legacy chapters** (no content blocks): `chapter.useContentBlocks == false` renders via `ReaderLegacyContent` — no audio features available.
- **Rapid block switching**: `loadBlock()` cancels previous state by overwriting `currentBlockId` and resetting position.

## Test Scenarios

- [ ] Happy path: Tap play on text block -> audio plays, words highlight, controls appear
- [ ] Karaoke sync: Word highlighting follows audio position accurately
- [ ] Auto-play: Audio completes -> next audio block plays after 500ms delay
- [ ] Activity break: Audio auto-plays up to activity, pauses, resumes after completion
- [ ] Listening mode: Play -> audio completes -> auto-play continues. Pause -> auto-play stops.
- [ ] Scroll follow: Play enables follow. User drag disables follow. Play again re-enables.
- [ ] Speed control: Cycle through 0.75x/1.0x/1.25x/1.5x/2.0x
- [ ] Close button: Stop audio, hide controls
- [ ] Chapter navigation: Audio stops when navigating to next chapter or back to book
- [ ] Word tap: Tap word during playback -> TTS speaks word, main audio ducks then restores
- [ ] Offline: Download book, go offline, play audio from cached files
- [ ] Error: Audio URL returns 404 -> loading state clears (no user-visible error currently)
- [ ] No audio: Chapter with no audio blocks -> no play icons, no controls
- [ ] Chapter-level audio: Multiple blocks sharing same audio URL -> seek between segments without reload
- [ ] Per-block audio: Each block has separate audio URL -> loads new source per block

## Key Files

**Core services:**
- `lib/core/services/audio_service.dart` — `just_audio` AudioPlayer wrapper, interruption handling
- `lib/core/services/word_audio_player.dart` — Lightweight player for vocab word segments
- `lib/core/services/word_pronunciation_service.dart` — TTS pronunciation with audio ducking
- `lib/core/services/file_cache_service.dart` — Audio/image file download and caching

**Providers:**
- `lib/presentation/providers/audio_sync_provider.dart` — Core orchestrator: `AudioSyncController`, karaoke sync, auto-play, listening mode
- `lib/presentation/providers/content_block_provider.dart` — Content block loading and filtering

**Reader widgets:**
- `lib/presentation/widgets/reader/reader_text_block.dart` — Text block with inline play icon
- `lib/presentation/widgets/reader/reader_word_highlight.dart` — Karaoke word highlighting + auto-scroll
- `lib/presentation/widgets/reader/reader_content_block_list.dart` — Block orchestration, progressive reveal, scroll management
- `lib/presentation/widgets/reader/reader_audio_controls.dart` — Floating audio player controls
- `lib/presentation/widgets/reader/reader_body.dart` — User scroll detection

**Admin:**
- `owlio_admin/lib/features/books/widgets/content_block_editor.dart` — Audio URL and word timing editor

**Edge Functions:**
- `supabase/functions/generate-chapter-audio/` — ElevenLabs TTS generation
- `supabase/functions/generate-audio-sync/` — Word-level timing generation

## Known Issues & Tech Debt

1. **Edge Functions use hardcoded `"content_blocks"` table name** — Expected since `DbTables` is Dart-only. Not actionable unless Edge Functions adopt a shared constant file.
