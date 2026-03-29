# Reader Sidebar — Design Spec

## Overview

Add a dedicated Reader Sidebar (left column) visible only on reader routes at ≥1000px. Consolidates chapters and audio controls into a persistent sidebar. Also fixes font not being applied to reader body text.

## Layout Breakpoints (Reader Route Only)

| Width | Layout |
|-------|--------|
| `<600px` | Mobile: reader content only, gear icon for settings |
| `600–999px` | Main sidebar (250px) + reader content |
| `≥1000px` | Main sidebar (250px) + **reader sidebar (300px)** + reader content |
| `≥1200px` | Main sidebar (250px) + **reader sidebar (300px)** + reader content + right panel (330px) |

Non-reader routes: existing breakpoints unchanged (right panel at ≥1000px).

## Reader Sidebar Structure

```
┌─────────────────────────┐
│  Chapters (scrollable)  │
│  ● Ch 1  ✓  completed   │
│  ● Ch 2  ●  current     │
│  ○ Ch 3  🔒 locked      │
│  ○ Ch 4  🔒 locked      │
│                         │
│      (flex space)       │
│                         │
├─────────────────────────┤
│  Audio Player (sticky)  │
│  [▶] ━━━━━●━━━ 2:14    │
│  Listening Mode toggle  │
└─────────────────────────┘
```

- Width: 300px fixed
- Background: surface color with right border
- Chapters: reuse existing chapter list logic from `_ChaptersCard`
- Audio player: reuse `audioSyncControllerProvider` — play/pause, seek bar, duration, listening mode toggle

## Right Panel Changes (Reader Route)

- **Remove**: `_ReaderPanel`, `_AudioControlBar`, `_ChaptersCard`
- **Keep**: `_ReaderSettingsCard` (only at ≥1200px when right panel is visible)
- At ≥1200px reader route shows: Settings + League + Quests (no chapters, no audio)

## Audio Controls Consolidation

| Width | Audio Location |
|-------|---------------|
| `<1000px` | Floating `ReaderAudioControls` (existing, in reader_screen.dart) |
| `≥1000px` | Reader sidebar bottom (sticky) — floating controls hidden |

Single audio source of truth: `audioSyncControllerProvider`. No duplicate controls visible at any breakpoint.

## Font Application Fix

Currently: `ReaderFont` enum exists, settings persist, UI picker works — but font family is never applied to reader text.

Fix: Add `fontFamily` from `GoogleFonts` to `TextStyle` in:
- `reader_word_highlight.dart` → `_baseTextStyle`
- `reader_paragraph.dart` → text styles
- `reader_text_block.dart` → text style

Helper in `reader_provider.dart`:
```dart
extension ReaderFontX on ReaderFont {
  TextStyle textStyle({...}) => GoogleFonts.getFont(displayName, ...);
}
```

## File Changes

| File | Change |
|------|--------|
| **NEW** `lib/presentation/widgets/reader/reader_sidebar.dart` | Reader sidebar widget (chapters + audio) |
| `lib/presentation/widgets/shell/main_shell_scaffold.dart` | Detect reader route → insert reader sidebar column |
| `lib/presentation/widgets/shell/right_info_panel.dart` | Remove `_ReaderPanel`, `_AudioControlBar`, `_ChaptersCard`; reader route shows Settings + League + Quests |
| `lib/presentation/screens/reader/reader_screen.dart` | Hide floating audio controls at ≥1000px |
| `lib/presentation/widgets/reader/reader_word_highlight.dart` | Add `fontFamily` to `_baseTextStyle` |
| `lib/presentation/widgets/reader/reader_paragraph.dart` | Add `fontFamily` to text styles |
| `lib/presentation/widgets/reader/reader_text_block.dart` | Add `fontFamily` to text styles |
| `lib/presentation/providers/reader_provider.dart` | Add `ReaderFontX` extension with `textStyle()` helper |

## Out of Scope

- Mobile reader layout changes (stays as-is)
- Vocabulary session audio coordination (separate task)
- Learning path redesign (separate plan exists)
