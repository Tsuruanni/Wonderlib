---
name: owlio-ui-style
description: Use whenever building, modifying, or styling any UI widget, screen, page, or component in the Owlio Flutter app under lib/presentation/. Covers the Duolingo-inspired design system — font (AppTextStyles), color (AppColors), chip (AppChip), button (GameButton), radius (AppRadius), and opacity (AppOpacity) conventions. Invoke this skill even if the user doesn't explicitly mention "styling" — any new screen, widget refactor, book/quiz/vocab/card/badge/notification/profile UI change should consult it first so the codebase stays consistent. Skip only for non-UI code (data layer, providers, domain logic).
---

# Owlio UI Style

## Overview

Owlio uses a Duolingo-inspired design language implemented through centralized helpers. The core principle: **never hardcode colors, fonts, sizes, or radii when a helper exists**. A one-line change in a helper must propagate everywhere — that only works if every call site uses the helper.

Why this matters: we migrated 80 files / ~561 hard-coded TextStyles and 15 files / ~20 inline chip patterns into central helpers. If new code regresses to hardcoded values, the whole investment erodes.

The design system lives in four files:

| File | What it exports |
|------|-----------------|
| `lib/app/theme.dart` | `AppColors`, `AppRadius`, `AppOpacity`, `AppTheme`, `.disabled()`/`.muted()` extensions |
| `lib/app/text_styles.dart` | `AppTextStyles` — 11 semantic typography methods |
| `lib/presentation/widgets/common/app_chip.dart` | `AppChip`, `AppChipVariant`, `AppChipSize` |
| `lib/presentation/widgets/common/game_button.dart` | `GameButton`, `GameButtonVariant` |

## Quick decision table

| Building... | Reach for | Example |
|-------------|-----------|---------|
| Any text | `AppTextStyles.xxx()` | `AppTextStyles.titleLarge(color: AppColors.primary)` |
| Any brand/semantic color | `AppColors.xxx` | `AppColors.primary`, `AppColors.danger` |
| Small tinted pill label | `AppChip` | `AppChip(label: 'NEW', variant: AppChipVariant.success)` |
| Button (CTA) | `GameButton` | `GameButton(label: 'Save', variant: .primary, onPressed: ...)` |
| Any border radius | `AppRadius.xxx` | `BorderRadius.circular(AppRadius.button)` |
| Disabled/muted state | `AppOpacity` or `.disabled()` ext | `myCard.disabled(isLocked)` |

## Typography — AppTextStyles

Pick by **semantic role**, not pixel size:

| Method | Size / Weight | Use for |
|--------|---------------|---------|
| `display({size = 36})` | 36 default / w900 | Celebration numbers: quiz score %, "YOU WON", streak day count |
| `hero()` | 32 / w900 | Splash/login/onboarding main heading |
| `headlineLarge()` | 28 / w800 | Large section heading ("Session Complete!") |
| `headlineMedium()` | 24 / w800 | Section heading |
| `titleLarge()` | 20 / w800 | Card/panel title |
| `titleMedium()` | 17 / w700 | Subtitle, list item header |
| `bodyLarge()` | 17 / w500 | Primary paragraph text |
| `bodyMedium()` | 15 / w500 | Secondary paragraph, description |
| `bodySmall()` | 13 / w500 | Small supporting text |
| `button()` | 15 / w700 / ls 0.8 | UPPERCASE action labels (GameButton uses this automatically) |
| `caption()` | 12 / w600 / ls 0.5 | Metadata, timestamps, internal chip labels |

**Hierarchy rule**: `display (w900) > headline/title (w800) > body (w500)`. Celebration moments get w900; section headings w800; paragraphs w500.

Overrides via `.copyWith()`:
```dart
AppTextStyles.titleLarge(color: AppColors.primary).copyWith(fontSize: 22, height: 1.1)
```

**Never use `GoogleFonts.nunito(...)` directly.** That's the pattern we centralized away from. The only remaining caller is `text_styles.dart` itself.

## Colors — AppColors

Primary palette (match Duolingo exactly):
- `AppColors.primary` — `#58CC02` green — positive, success, main CTA
- `AppColors.secondary` — `#1CB0F6` blue — info, secondary CTA
- `AppColors.danger` — `#FF4B4B` red — errors, destructive
- `AppColors.wasp` — `#FFC800` gold — premium, XP
- `AppColors.streakOrange` — `#FF9600` — streaks, warnings
- `AppColors.black` — soft `#3C3C3C` — primary text
- `AppColors.white`, `AppColors.background` — surfaces

Each has a `Dark` variant for 3D shadows (`primaryDark`, `secondaryDark`, etc.) and sometimes a `Background` variant (very light tint, e.g., `primaryBackground`).

Gray scale — **two families coexist** (legacy cleanup is an open backlog item):
- Legacy: `AppColors.neutral`, `.neutralDark`, `.neutralText`
- Tailwind: `AppColors.gray100` through `.gray700`

For new code, prefer Tailwind gray unless the surrounding widget already uses legacy. `neutralDark` is still used for 3D shadows — leave those alone.

Gamification aliases:
- `AppColors.xpGold` (= wasp), `AppColors.gemBlue` (= secondary)
- Card rarities: `cardCommon`, `cardRare`, `cardEpic`, `cardLegendary` (+ `Dark` shadow versions)
- Path/terrain: `terrain`, `terrainLight`, `path`, `pathBorder`

## Chips — AppChip

Duolingo-style tinted pill for status labels, counters, category tags.

```dart
AppChip(
  label: 'COMPLETED',
  variant: AppChipVariant.success,
  size: AppChipSize.md,
  icon: Icon(Icons.check_rounded, size: 14, color: AppColors.primary),
  uppercase: true,  // default
)
```

Variant → intent:
- `success` (green) — completed, correct, passed, mastered
- `info` (blue) — in progress, informational, category tag
- `danger` (red) — failed, error, overdue
- `warning` (orange) — due soon, caution, streak
- `premium` (gold) — locked-behind, VIP, XP amount
- `neutral` (gray) — metadata, attempt counter, generic label
- `custom` — pass `customColor: <Color>` for dynamic colors (rarity, score-based)

Size → padding/radius/font:
- `sm` (8×2 padding, radius 6, 11px) — tight inline tags
- `md` default (10×4, radius 10, 12px) — most cases
- `lg` (16×8, radius 20, 14px) — bold hero pills

**Do not** build inline `Container(decoration: BoxDecoration(color: X.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)), child: Text(...))` for tinted labels. That's what `AppChip` replaced.

**Specialized badges that are NOT chips** — leave them alone: `XPBadge`, `CoinBadge`, `LevelBadge`, `LeagueTierBadge`. They have animation or image-based logic AppChip can't replicate.

## Buttons — GameButton

3D tactile button with stacked shadow and press translation. Label is always uppercase (widget handles it).

```dart
GameButton(
  label: 'Save',
  variant: GameButtonVariant.primary,
  onPressed: () => save(),
  fullWidth: false,
  icon: Icon(Icons.check_rounded),
)
```

Variant → use case:
- `primary` (green) — main CTA per screen
- `secondary` (blue) — secondary CTA
- `success` (same green as primary) — quiz/activity correct buttons
- `danger` (red) — destructive: delete, leave session
- `wasp` (gold) — premium / treasure claim
- `neutral` (white + gray border) — cancel, back
- `outline` — flat white bg, green text, gray border — dismiss-style secondary
- `ghost` — **flat text-only, no bg/border/3D** — low-emphasis CTAs ("VIEW ALL", footer links)

Disable by passing `onPressed: null` — swaps to gray (color approach, NOT opacity). Don't wrap disabled buttons in `Opacity`.

`AnimatedGameButton` wraps this with scale bounce + haptic. Use for quiz answer buttons and other "reward" interactions where extra pop helps.

## Radius — AppRadius

Semantic hierarchy (values in px):

```dart
AppRadius.tag      // 8  — small inline tags
AppRadius.button   // 12 — buttons (tighter than cards)
AppRadius.input    // 16 — form inputs
AppRadius.card     // 16 — cards, panels
AppRadius.pill     // 20 — large pills (chip lg size)
AppRadius.sheet    // 24 — bottom sheets, large rounded tops
```

Usage:
```dart
decoration: BoxDecoration(
  borderRadius: BorderRadius.circular(AppRadius.card),
  // ...
)
```

**Don't** write `BorderRadius.circular(12)` magic numbers. Pick the semantic tier. Buttons are 12 (tighter than cards) — this is intentional for Duolingo-style hierarchy.

## Opacity — AppOpacity + extensions

```dart
AppOpacity.disabled  // 0.45 — non-interactive / locked
AppOpacity.muted     // 0.6  — de-emphasized but readable
AppOpacity.subtle    // 0.8  — lightly backgrounded
```

Fluent extensions on `Widget`:
```dart
myWidget.disabled(isLocked)   // wraps in Opacity only when true
myWidget.muted(isInactive)
```

Both are no-ops when the condition is false — safe to chain.

**Note**: GameButton's disabled state uses color swap (gray), not opacity. Don't override it. Use `AppOpacity` for cards, icons, list items, locked content — things without their own disabled styling.

## Common mistakes (don't)

1. `GoogleFonts.nunito(fontSize: X, ...)` → use `AppTextStyles.xxx()`.
2. Inline `Container+BoxDecoration+Text` for a small pill → use `AppChip`.
3. `BorderRadius.circular(12)` / `circular(20)` etc. → use `AppRadius.xxx`.
4. `.withOpacity(0.5)` (deprecated in Flutter 3.27+) → `.withValues(alpha: 0.5)`.
5. Hardcoded hex color → `AppColors.xxx` (every brand color has an entry).
6. Scattered alpha values (`0.1`, `0.12`, `0.15`) for tinted bg → use `AppChipVariant` — it standardizes alpha.
7. `Opacity(opacity: 0.45, child: x)` for disabled → `x.disabled(isDisabled)`.
8. Custom `TextStyle(fontFamily: 'Nunito', fontSize: 16, ...)` — same as #1, different shape.

## Duolingo spec alignment

**Matches exactly** (don't fight these):
- Color palette
- Button 3D mechanic (Stack + hard shadow, no blur, press translateY)
- Card pattern: 2px border + 4px hard offset shadow
- Uppercase button labels with 0.8 letter-spacing
- Chip tinted-bg + solid-text at ~12% alpha

**Intentional divergence**:
- Font: Nunito only (Duolingo's Feather Bold is licensed, not acquired). Single-file swap if we ever find a free alternative.
- Admin panel UI stays in Turkish (teacher/student apps in English). Never translate admin strings.

**Known open gaps** (don't rely on, don't expand): see the live backlog at `memory/project_duolingo_design_backlog.md` — currently includes gray scale consolidation, AppChip border parameter, custom tooltip.

## Workflow for adding/modifying any UI

1. **Identify each visual element** you're adding (text, button, chip, card, input, progress bar, icon container).
2. **For each, pick the helper**: typography → AppTextStyles; label → AppChip; action → GameButton; border radius → AppRadius; color → AppColors; opacity state → AppOpacity.
3. **Use `.copyWith()`** only when no helper variant fits exactly (e.g., unusual fontSize, custom letterSpacing).
4. **Grep before inventing**: if you're about to write a `Container(decoration: ...)`, first search `lib/presentation/widgets/common/` for a similar existing widget.
5. **Run `dart analyze lib/`** after changes — should produce zero new errors/warnings.

When in doubt, find the closest existing screen (book_quiz_result_card.dart, daily_review_screen.dart, streak_sheet.dart, or student_assignments_screen.dart are good exemplars post-refactor) and follow its pattern.
