# Admin Panel Sidebar Refactor — Design Spec

**Date:** 2026-04-19
**Scope:** Owlio Admin Panel (`/Users/wonderelt/Desktop/Owlio/owlio_admin`)
**Status:** Design approved, awaiting implementation plan

---

## Problem

The current admin dashboard (`/`) renders a 15-tile grid. Each tile performs `context.go('/schools')` style full-page navigation. Target screens each carry their own `Scaffold` + `AppBar` and there is no persistent shell. Users who want to switch sections must rely on browser back or re-navigate via the dashboard. The router is a flat `GoRoute` list with no `ShellRoute`.

## Goal

Convert the admin panel to a persistent left-sidebar layout:

- Sidebar is visible on every authenticated screen (list screens and edit/form screens).
- Clicking a sidebar item swaps the content area; the sidebar stays in place.
- Each section preserves its own navigation stack and state when user tabs away and returns.
- The current "dashboard" becomes a stats-only "Overview" accessible via the first sidebar item.

## Decisions (locked in during brainstorming)

| # | Decision | Choice |
|---|----------|--------|
| 1 | Sidebar scope | **Everywhere**, including edit/form screens |
| 2 | Dashboard fate | **Keep as "Overview"** — strip the 15 cards, retain stats tiles |
| 3 | Sidebar structure | **Grouped** (6 groups) |
| 4 | Existing per-screen AppBars | **Keep as-is** — minimum churn; logout moves to sidebar footer |

## Architecture

### Shell structure

```
AdminShell (Row, fixed layout)
├── AdminSidebar (260px, fixed width)
│   ├── Header: Owlio Admin logo + title
│   ├── Scrollable nav groups
│   └── Footer: user email + logout icon
└── Expanded(child)  ← branch Navigator
    └── [existing screen Scaffold + AppBar]
```

### Router pattern

`StatefulShellRoute.indexedStack` wraps all authenticated routes (16 branches). `/login` stays outside the shell.

Why `StatefulShellRoute.indexedStack` (not plain `ShellRoute`):

- Each branch has its own `Navigator` → independent back stack per section.
- Switching sections preserves the Navigator state of the previous section (user can edit a book, switch to Users, return, and still be on the same chapter-edit page).
- The shell widget receives a `navigationShell` and drives tab switching via `navigationShell.goBranch(index)`.

### Branches (16 total)

Each branch owns its root route + all descendant routes related to that section. The active sidebar item is determined by the current branch index.

| # | Branch | Root route | Descendant routes |
|---|--------|-----------|-------------------|
| 0 | Overview | `/` | — |
| 1 | Books | `/books` | `/books/new`, `/books/import`, `/books/:bookId`, `/books/:bookId/chapters/new`, `/books/:bookId/chapters/:chapterId`, `/books/:bookId/quiz`, `/books/:bookId/quiz/questions/new`, `/books/:bookId/quiz/questions/:questionId` |
| 2 | Vocabulary | `/vocabulary` | `/vocabulary/import`, `/vocabulary/new`, `/vocabulary/:wordId`, `/wordlists/new`, `/wordlists/:listId` |
| 3 | Units | `/units` | `/units/new`, `/units/:unitId` |
| 4 | Schools | `/schools` | `/schools/new`, `/schools/:schoolId` |
| 5 | Classes | `/classes` | `/classes/new`, `/classes/:classId` |
| 6 | Users | `/users` | `/users/create`, `/users/:userId` |
| 7 | Recent Activity | `/recent-activity` | `/recent-activity/:sectionKey` |
| 8 | Learning Paths | `/learning-paths` | `/templates`, `/templates/new`, `/templates/:templateId`, `/learning-path-assignments/new`, `/assignments`, `/assignments/:assignmentId` |
| 9 | Collectibles | `/collectibles` | `/badges`, `/badges/new`, `/badges/:badgeId`, `/cards`, `/cards/new`, `/cards/:cardId` |
| 10 | Quests | `/quests` | — |
| 11 | Treasure Wheel | `/treasure-wheel` | — |
| 12 | Avatars | `/avatars` | `/avatars/bases/new`, `/avatars/bases/:id`, `/avatars/items/new`, `/avatars/items/:id`, `/avatars/categories/new`, `/avatars/categories/:id` |
| 13 | Tiles | `/tiles` | `/tiles/new`, `/tiles/:themeId` |
| 14 | Notifications | `/notifications` | — |
| 15 | Settings | `/settings` | — |

Deep-link entry to any descendant route (e.g., `/books/abc-123`) must resolve to its parent branch so the correct sidebar item is highlighted. `go_router` handles this automatically when descendant routes are declared inside the correct branch.

## Sidebar UI

### Layout

```
┌─────────────────────┐
│ 🦉 Owlio Admin      │  header — 64px, border-bottom
├─────────────────────┤
│                     │
│ 📊 Genel Bakış      │  standalone item (branch 0)
│                     │
│ İÇERİK              │  group header (11px uppercase)
│   📖 Kitaplar       │
│   🔤 Kelime Havuzu  │
│   🎛  Üniteler      │
│                     │
│ KULLANICILAR        │
│   🏫 Okullar        │
│   👥 Sınıflar       │
│   👤 Kullanıcılar   │
│   📈 Son Etkinlikler│
│                     │
│ ÖĞRENME             │
│   🛣  Öğrenme Yolları│
│                     │
│ OYUNLAŞTIRMA        │
│   🏆 Koleksiyon     │
│   ⚡ Daily Quests   │
│   🎡 Hazine Çarkı   │
│   😀 Avatar         │
│   🗺  Tile Temaları │
│                     │
│ SİSTEM              │
│   🔔 Notifications  │
│   🔧 Ayarlar        │
│                     │
│  (scrollable)       │
├─────────────────────┤
│ admin@demo.com  ⎋   │  footer — email + logout button
└─────────────────────┘
```

Icons: Use existing `Icons.xxx` constants that match the current dashboard card icons (not emoji).

### Active state

- Background: `AppColors.primary.withValues(alpha: 0.1)` (indigo tint)
- Left border: 3px solid indigo accent
- Icon + label color: indigo
- Non-active: default text, no background; hover → light grey background

### Group header

- 11px, uppercase, letter-spaced, grey-600
- Non-interactive (always expanded, no collapse toggle — spec simplicity)
- Horizontal padding 20px, vertical 8px

### Dimensions

- Width: 260px (fixed; admin is desktop-only, no responsive collapse)
- Item height: 40px
- Header: 64px (matches typical AppBar height)
- Footer: 56px

## Overview Screen (ex-Dashboard)

Replaces `DashboardScreen`'s 15-card grid.

### Content

1. **Title row** — "Owlio Yönetim Paneline Hoş Geldiniz" (headlineMedium, bold) + greeting subtitle (current copy kept).
2. **Stats grid** — 5 columns × 2 rows of stat tiles (or responsive: 4 on narrower viewports). Each tile:
   - Large number (28px bold)
   - Label (12px grey)
   - Accent dot or thin left border in a color matching the section
   - Non-clickable

Stat data comes from the existing `dashboardStatsProvider` (no changes needed). The 10 metrics displayed: books, schools, classes, users, badges, words, wordlists, templates, assignments, quests.

### Removed

- 15 `_DashboardCard` widgets
- AppBar's `PopupMenuButton` logout (moves to sidebar footer)
- Dashboard's own AppBar title "Kontrol Paneli" (Overview screen keeps its Scaffold + AppBar with the title, same as other sections)

## Files

### New

- `lib/core/widgets/admin_shell.dart` — shell wrapper; accepts `StatefulNavigationShell` and renders `Row([AdminSidebar, Expanded(navigationShell)])`.
- `lib/core/widgets/admin_sidebar.dart` — sidebar widget; receives current branch index, branch-switch callback, and user info; renders groups + footer.

### Modified

- `lib/core/router.dart` — wrap all authenticated routes in `StatefulShellRoute.indexedStack`; organise into 16 branches. `/login` stays outside.
- `lib/features/dashboard/screens/dashboard_screen.dart` — remove cards, remove logout PopupMenuButton, replace body with stats grid, keep provider.

## Risk Notes

| Risk | Mitigation |
|------|------------|
| Existing `context.go('/some-path')` calls inside screens may cause cross-branch jumps that confuse users | Audit `context.go(` usages in admin panel before implementation; decide per call whether it should be `context.push` (stays in current branch) or `context.go` (explicit branch switch) |
| `Navigator.of(context).pop()` / `context.pop()` inside edit screens must still work | `StatefulShellRoute` gives each branch its own Navigator; `pop()` pops within that branch — should Just Work, but spot-check after integration |
| Deep link to `/books/abc-123` on first load must activate Books branch | Handled automatically by `go_router` when the route is declared inside the correct branch |
| Login redirect flow | `/login` stays outside the shell route; `isAuthenticated` + `isAuthorized` redirects in the top-level `GoRouter` still apply |
| 16 branches × nested routes → `router.dart` becomes long | Acceptable — one flat declaration file is clearer than splitting. Can group branches with `//` section comments for readability |

## Success Criteria

1. Login redirects to `/` which shows Overview inside the shell (sidebar visible left, stats visible right).
2. Clicking any sidebar item swaps the content area; sidebar stays put; active item visually highlighted.
3. Editing a book (`/books/:id`), switching to Users tab, switching back to Books → returns to the same book-edit screen with form state intact.
4. Deep-linking to `/vocabulary/word-xyz` from a browser refresh lands inside the shell with Vocabulary branch active.
5. Logout button in sidebar footer signs out and routes to `/login` (shell no longer wraps the login screen).
6. Overview screen shows the 10 stats; no cards remain.
7. All 16 section routes (Overview + 15 content sections, with nested edit screens) render correctly with sidebar visible.
8. `dart analyze lib/` passes with zero new warnings introduced by the refactor.

## Out of Scope

- Responsive/mobile sidebar (admin is desktop-only)
- Collapsible sidebar (icon-only mode)
- Breadcrumbs / unified top bar
- Sidebar search
- Re-ordering or renaming sidebar items via settings
- Role-based sidebar filtering (head vs admin)
