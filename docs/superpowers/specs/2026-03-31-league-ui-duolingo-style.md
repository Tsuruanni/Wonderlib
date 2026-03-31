# League UI — Duolingo Style Redesign

## Summary

Redesign the League tab UI to match Duolingo's leaderboard style: tier badge row, flat list (no podium), promotion/demotion zone separators, and countdown timer.

## Scope

UI-only change to `leaderboard_screen.dart`. No provider, data, domain, or database changes.

## Changes

### 1. Replace Podium with Flat List

Remove `_PodiumSection` widget entirely. All entries rendered as flat list items. Top 3 distinguished by colored rank circles (gold/silver/bronze) instead of medal emojis + height blocks.

### 2. Tier Badge Row (Header)

Replace `_WeeklyIndicator` with a new header showing:
- 5 shield icons in a row (bronze → diamond)
- Current tier: larger + colored
- Other tiers: smaller + grey
- Below: "{Tier} League" title
- Below: "Top 5 advance to the next league"
- Below: "{N} days" countdown (days until Sunday 23:59)

### 3. Zone Separators

Replace zone card coloring with Duolingo-style separator lines:
- **Promotion separator:** Green line with "▲ PROMOTION ZONE ▲" text between rank 5 and rank 6
- **Demotion separator:** Red line with "▼ DEMOTION ZONE ▼" text between rank 25 and rank 26 (hidden in Bronze tier)
- No background color changes on cards — all cards are white (except current user highlighted)

### 4. Rank Number Styling

- Rank 1: Gold circle background with white number
- Rank 2: Silver circle background with white number
- Rank 3: Bronze circle background with white number
- Rank 4+: Plain number, no circle

### 5. Remove `_ZonePreviewBanner`

The personal zone banner at the top ("You're in the promotion zone!") is removed — the zone separator in the list makes it obvious.

### 6. Preserved Behaviors

- Bot tap guard (onTap disabled for bots)
- Same-school badge icon
- Rank change indicator (↑↓ arrows)
- Pull-to-refresh
- "Not Joined" card (State 1)
- Class/School tabs unchanged
- Current user row highlighting (secondary color)

## Key Files

- Modify: `lib/presentation/screens/leaderboard/leaderboard_screen.dart`
