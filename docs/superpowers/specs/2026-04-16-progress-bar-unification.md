# Progress Bar Unification + Daily Quest Island Redesign

**Date:** 2026-04-16  
**Scope:** Visual consistency pass — all progress bars adopt the badges-page style; daily quest cards adopt the badges island layout.

---

## Goal

Replace every `LinearProgressIndicator`, `ProProgressBar`, and one-off custom bar with a single `AppProgressBar` widget that matches the established design language from the badges screen. Simultaneously redesign the daily quest layout to use the same island-row pattern.

---

## Reference: The Badges Design Language

Source: `lib/presentation/widgets/badges/achievement_group_row.dart`

**Progress bar (`_ProgressBar`):**
- Height: 12px
- Background: `AppColors.gray200`
- Fill: customizable `fillColor`
- Depth: 3px bottom `BorderSide` as shadow (no blur — sharp, tactile)
- Shape: `BorderRadius.circular(999)` (fully rounded)
- Pattern: `ClipRRect` → background `Container` → `Align(left)` → `FractionallySizedBox` → fill `Container`

**Island row (`AchievementGroupRow`):**
- Left: 80×80 colored tile, `BorderRadius.circular(18)`, `BoxShadow` offset (0,4) blurRadius 0, border 1.5px shadow color
- Tile content: icon (emoji or asset) + optional LEVEL label
- Right: title (w900, 17px) + progress bar + description (gray600, 13px)
- Progress label top-right: "X/Y" or "MAX"

---

## Part 1 — `AppProgressBar` Widget

**File:** `lib/presentation/widgets/common/app_progress_bar.dart`

Replaces `ProProgressBar` and all inline `LinearProgressIndicator` usages.

```
AppProgressBar({
  required double progress,       // 0.0–1.0
  Color? fillColor,               // default AppColors.primary
  Color? fillShadow,              // default AppColors.primaryDark
  Color? backgroundColor,         // default AppColors.gray200
  double height,                  // default 12.0
  Duration duration,              // default Duration.zero (no animation)
  Curve curve,                    // default Curves.easeOutCubic
})
```

- When `duration > Duration.zero`, wraps `FractionallySizedBox` in `AnimatedFractionallySizedBox`.
- `fillShadow` drives the 3px bottom `BorderSide`. If null, falls back to a darker shade of `fillColor`.
- `ProProgressBar` is deleted; its one caller (`daily_review_screen.dart`) migrates to `AppProgressBar`.

---

## Part 2 — Progress Bar Replacements (12 locations)

| File | Change |
|------|--------|
| `achievement_group_row.dart` | Extract `_ProgressBar` → use `AppProgressBar` |
| `daily_review_screen.dart` | `ProProgressBar` → `AppProgressBar(duration: 500ms, color: streakOrange)` |
| `vocab_session_progress_bar.dart` | Rewrite using `AppProgressBar(duration: 500ms, curve: easeOutCubic)`. Combo state: `fillColor: streakOrange`. Remove gradient + glow. |
| `book_quiz_progress_bar.dart` | Rewrite using `AppProgressBar(duration: 500ms, curve: fastOutSlowIn)`. Remove shimmer + glow. Keep entry `fadeIn` animation. |
| `collection_progress_widget.dart` | `LinearProgressIndicator` → `AppProgressBar` with tier-based `fillColor` (primary/rare/epic/legendary) |
| `collection_progress_card.dart` | Main bar + 4 rarity bars → `AppProgressBar` with respective rarity colors |
| `reader_collapsible_header.dart` | `LinearProgressIndicator` (3px scroll) → `AppProgressBar(height: 4, fillColor: primary, backgroundColor: gray200)` |
| `reader_sidebar.dart` | Same as above |
| `vocabulary_hub_screen.dart` | `LinearProgressIndicator` → `AppProgressBar` |
| `library_screen.dart` | 3× `LinearProgressIndicator` → `AppProgressBar` (level bar + 2× book reading progress) |
| `word_list_detail_screen.dart` | `LinearProgressIndicator` (accuracy) → `AppProgressBar(fillColor: white, backgroundColor: white30)` — white-on-gradient context, keep white |
| `right_info_panel.dart` `_MonthlyQuestSidebarCard` | `LinearProgressIndicator` → `AppProgressBar(fillColor: white, backgroundColor: white30, height: 8)` — white on orange context |

---

## Part 3 — Daily Quest Island Redesign

### Mobile: `daily_quest_list.dart`

**Current:** One big white card, dividers between rows, small 44px circle icon, progress bar with text inside.

**New:** List of island rows (no outer card). Each `_QuestRow` becomes a standalone horizontal row matching `AchievementGroupRow`:

- **Left tile:** 64×64, `BorderRadius.circular(16)`, colored bg + bottom shadow (4px offset, 0 blur). Color per quest type (see table below). Contains quest emoji icon (24px) centered. Completed state: wasp/gold tile + checkmark.
- **Right column:**
  - Title: w800, 15px, `AppColors.black` (completed: `neutralText`)
  - Progress bar: `AppProgressBar(height: 12, fillColor: questColor, fillShadow: questShadow)`
  - Below bar: `"X / Y"` label (w700, 12px, `gray500`) + reward badge (existing pill) in a `Row` with `MainAxisAlignment.spaceBetween`
- **Spacing:** 12px between rows (no dividers, no outer card border)
- **All complete banner:** Kept as a standalone pill/row at top, same green style

**Quest type colors:**

| questType | tile color | shadow |
|-----------|-----------|--------|
| `earn_xp` | `primary` | `primaryDark` |
| `earn_combo_xp` | `cardLegendary` | `Color(0xFFB8860B)` |
| `spend_time` | `secondary` | `secondaryDark` |
| `complete_chapters` / `read_chapters` | `secondary` | `secondaryDark` |
| `review_words` / `vocab_session` | `cardEpic` | `Color(0xFF6A0080)` |
| fallback | `neutralText` | `gray500` |

### Desktop Sidebar: `_DailyQuestsCard` in `right_info_panel.dart`

**Current:** White card wrapper, each `_QuestRow` has a circle icon + `LinearProgressIndicator`.

**New:** Same island style as mobile but more compact (sidebar is 330px):
- Outer card wrapper removed (or kept as a subtle section container with no border, just spacing)
- Left tile: **52×52**, `BorderRadius.circular(14)`
- Icon: 20px
- Title: 13px w700
- Progress bar: `AppProgressBar(height: 10)`
- `"X / Y"` below bar + reward badge in a row

---

## Affected Files Summary

| File | Change type |
|------|-------------|
| `lib/presentation/widgets/common/app_progress_bar.dart` | **NEW** |
| `lib/presentation/widgets/common/pro_progress_bar.dart` | **DELETE** |
| `lib/presentation/widgets/badges/achievement_group_row.dart` | Minor: use `AppProgressBar` |
| `lib/presentation/widgets/home/daily_quest_list.dart` | **REWRITE** |
| `lib/presentation/widgets/shell/right_info_panel.dart` | `_DailyQuestsCard` + `_MonthlyQuestSidebarCard` |
| `lib/presentation/widgets/vocabulary/session/vocab_session_progress_bar.dart` | Rewrite |
| `lib/presentation/widgets/book_quiz/book_quiz_progress_bar.dart` | Rewrite |
| `lib/presentation/widgets/cards/collection_progress_widget.dart` | Bar swap |
| `lib/presentation/widgets/cards/collection_progress_card.dart` | Bar swap ×5 |
| `lib/presentation/widgets/reader/reader_collapsible_header.dart` | Bar swap |
| `lib/presentation/widgets/reader/reader_sidebar.dart` | Bar swap |
| `lib/presentation/screens/vocabulary/vocabulary_hub_screen.dart` | Bar swap |
| `lib/presentation/screens/library/library_screen.dart` | Bar swap ×3 |
| `lib/presentation/screens/vocabulary/word_list_detail_screen.dart` | Bar swap |
| `lib/presentation/screens/vocabulary/daily_review_screen.dart` | Bar swap |

---

## Out of Scope

- Circular progress indicators (e.g. `CircularProgressIndicator` in loading states) — untouched
- Admin panel — stays as-is
- Streak/XP level bars in profile screen — separate feature
