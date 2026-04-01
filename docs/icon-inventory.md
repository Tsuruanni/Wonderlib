# Owlio Icon Inventory

> Total: **262 unique Material Icons** across main app + admin panel
> Strategy: Replace with colorful SVG icons, starting from Priority 1

---

## PRIORITY 1 — Always Visible (Replace First)

These icons appear on every screen or on the most-used screens. Students see them daily.

### Bottom Navigation / Sidebar (main_shell_scaffold.dart)

| Semantic Name | Current Icon (unselected) | Current Icon (selected) | Where |
|---------------|--------------------------|------------------------|-------|
| Learning Path tab | `Icons.route_outlined` | `Icons.route_rounded` | Bottom nav + sidebar |
| Home tab | `Icons.home_outlined` | `Icons.home_rounded` | Bottom nav + sidebar |
| Library tab | `Icons.local_library_outlined` | `Icons.local_library_rounded` | Bottom nav + sidebar |
| Card Collection tab | `Icons.collections_bookmark_outlined` | `Icons.collections_bookmark_rounded` | Bottom nav + sidebar |
| Leaderboards tab | `Icons.emoji_events_outlined` | `Icons.emoji_events_rounded` | Bottom nav + sidebar |
| Profile button | `Icons.person_outline_rounded` | `Icons.person_rounded` | Sidebar |

### Top Navbar Stats (top_navbar.dart, right_info_panel.dart)

| Semantic Name | Current Icon | Where |
|---------------|-------------|-------|
| Streak (fire) | `Icons.local_fire_department` | Top bar, right panel, feedback |
| Coins | `Icons.monetization_on_rounded` | Top bar, right panel, XP badge |
| XP / Energy | `Icons.bolt_rounded` | Home screen, daily review, quests |

### Learning Path Nodes (path_node.dart)

| Semantic Name | Current Icon | Where |
|---------------|-------------|-------|
| Word List node | `Icons.menu_book_rounded` | Learning path tile |
| Book node | `Icons.auto_stories_rounded` | Learning path tile |
| Game node | `Icons.sports_esports_rounded` | Learning path tile |
| Treasure node | `Icons.card_giftcard_rounded` | Learning path tile |
| Review node | `Icons.style_rounded` | Learning path tile |
| Locked node | `Icons.lock_rounded` | Learning path tile (locked state) |
| Completed node | `Icons.check_rounded` | Learning path tile (done state) |
| Star rating | `Icons.star_rounded` / `Icons.star_outline_rounded` | Learning path tile stars |

### League Tier Icons (right_info_panel.dart)

| Semantic Name | Current Icon | Where |
|---------------|-------------|-------|
| Bronze tier | `Icons.shield_outlined` | League card |
| Silver tier | `Icons.shield_rounded` | League card |
| Gold tier | `Icons.emoji_events_rounded` | League card |
| Platinum tier | `Icons.workspace_premium_rounded` | League card |
| Diamond tier | `Icons.diamond_rounded` | League card |

---

## PRIORITY 2 — Frequently Seen (Replace Second)

### Home Screen (home_screen.dart)

| Semantic Name | Current Icon | Where |
|---------------|-------------|-------|
| Daily review ready | `Icons.bolt_rounded` | Review card |
| Review completed | `Icons.check_rounded` | Review card |
| Play button | `Icons.play_arrow_rounded` | Review card CTA |
| Empty state | `Icons.auto_stories` | No content placeholder |
| Error state | `Icons.cloud_off` | Network error |

### Daily Quests (daily_quest_list.dart, right_info_panel.dart)

| Semantic Name | Current Icon | Where |
|---------------|-------------|-------|
| Quest: earn XP | `Icons.bolt_rounded` | Quest row |
| Quest: spend time | `Icons.timer_rounded` | Quest row |
| Quest: chapters | `Icons.menu_book_rounded` | Quest row |
| Quest: review words | `Icons.translate_rounded` | Quest row |
| Quest: default | `Icons.star_rounded` | Quest row |
| Quest completed | `Icons.check_rounded` | Quest row checkmark |
| Quest bonus locked | `Icons.lock_rounded` | Bonus section |
| Assignment: book | `Icons.auto_stories_rounded` | Assignment quest |
| Assignment: vocab | `Icons.abc_rounded` | Assignment quest |
| Assignment: unit | `Icons.route` | Assignment quest |

### Reader (reader_sidebar.dart)

| Semantic Name | Current Icon | Where |
|---------------|-------------|-------|
| Chapter completed | `Icons.check_rounded` | Chapter list |
| Book quiz | `Icons.quiz_rounded` | Quiz entry |
| Audio play | `Icons.play_arrow_rounded` | Audio controls |
| Audio pause | `Icons.pause_rounded` | Audio controls |
| Audio close | `Icons.close_rounded` | Audio panel |
| Listen mode | `Icons.headphones_rounded` | Listen button |

### Gamification Feedback (vocab_question_feedback.dart)

| Semantic Name | Current Icon | Where |
|---------------|-------------|-------|
| Nice streak (5) | `Icons.local_fire_department` | Combo feedback |
| Unstoppable (10) | `Icons.bolt` | Combo feedback |
| Legendary (15) | `Icons.stars` | Combo feedback |
| Coin earned | `Icons.monetization_on` | XP badge floating |

### Card Pack (right_info_panel.dart)

| Semantic Name | Current Icon | Where |
|---------------|-------------|-------|
| Card pack | `Icons.style_rounded` | Pack display |
| Buy pack | `Icons.monetization_on_rounded` | Buy button |

---

## PRIORITY 3 — Teacher Dashboard

### Teacher Navigation (teacher_shell_scaffold.dart)

| Semantic Name | Current Icon (unselected) | Current Icon (selected) | Where |
|---------------|--------------------------|------------------------|-------|
| Dashboard tab | `Icons.dashboard_outlined` | `Icons.dashboard` | Bottom nav + sidebar |
| Classes tab | `Icons.groups_outlined` | `Icons.groups` | Bottom nav + sidebar |
| Assignments tab | `Icons.assignment_outlined` | `Icons.assignment` | Bottom nav + sidebar |
| Reports tab | `Icons.analytics_outlined` | `Icons.analytics` | Bottom nav + sidebar |
| Profile | `Icons.person_outline` | `Icons.person` | Sidebar |

### Teacher Dashboard Stats (dashboard_screen.dart)

| Semantic Name | Current Icon | Where |
|---------------|-------------|-------|
| School | `Icons.school` | Welcome header |
| Total students | `Icons.groups` | Stat card |
| Manage classes | `Icons.class_` | Stat card |
| Active assignments | `Icons.assignment` | Stat card |
| Average progress | `Icons.trending_up` | Stat card |
| New assignment | `Icons.add_circle_outline` | Action button |
| Reports | `Icons.bar_chart` | Action button |
| Leaderboard | `Icons.leaderboard` | Action button |
| Recent activity | `Icons.history` | Activity section |
| Activity XP | `Icons.star` | Activity row |

---

## PRIORITY 4 — Secondary UI (Can Stay Material or Replace Later)

### Status & Feedback Icons (used inline across many screens)

| Icon | Usage Count (app) | Context |
|------|:-:|---------|
| `Icons.check_circle` | 12 | Success states |
| `Icons.check_circle_rounded` | 11 | Completion badges |
| `Icons.error_outline` | 6 | Error messages |
| `Icons.warning_rounded` | 3 | Warning states |
| `Icons.warning_amber_rounded` | 2 | Caution messages |
| `Icons.info_outline` | 1 | Info tooltips |
| `Icons.cancel_rounded` | 2 | Cancel/dismiss |

### Content & Education Icons

| Icon | Usage Count (app) | Context |
|------|:-:|---------|
| `Icons.abc` | 10 | Vocabulary |
| `Icons.menu_book` | 17 | Books/reading |
| `Icons.book` | 9 | Books |
| `Icons.quiz_rounded` | 7 | Quizzes |
| `Icons.translate_rounded` | 3 | Translation/review |
| `Icons.format_quote_rounded` | 2 | Quotes |
| `Icons.text_fields` | 2 | Text content |
| `Icons.record_voice_over_outlined` | 1 | Voice/pronunciation |

### Gamification Icons

| Icon | Usage Count (app) | Context |
|------|:-:|---------|
| `Icons.star_rounded` | 12 | Ratings, achievements |
| `Icons.bolt_rounded` | 13 | XP/energy |
| `Icons.local_fire_department_rounded` | 8 | Streak |
| `Icons.emoji_events_rounded` | 8 | Trophies/awards |
| `Icons.monetization_on` | 8 | Coins |
| `Icons.military_tech` | 2 | Badges |
| `Icons.celebration_rounded` | 1 | Celebration |
| `Icons.sports_esports_rounded` | 2 | Games |
| `Icons.card_giftcard_rounded` | 2 | Treasure/gifts |

### Media & Audio Icons

| Icon | Usage Count (app) | Context |
|------|:-:|---------|
| `Icons.play_arrow_rounded` | 5 | Play audio/video |
| `Icons.pause_rounded` | 3 | Pause |
| `Icons.replay_rounded` | 3 | Replay |
| `Icons.volume_up_rounded` | 3 | Volume/sound |
| `Icons.headphones_rounded` | 2 | Listening mode |
| `Icons.mic` | 1 | Microphone |
| `Icons.music_note` | 1 | Music (admin) |
| `Icons.stop` | 1 | Stop playback |

### Navigation & Action (Generic — keep Material)

| Icon | Usage Count (app) | Context |
|------|:-:|---------|
| `Icons.arrow_back` / variants | 9 | Back navigation |
| `Icons.chevron_right` / variants | 18 | Forward/expand |
| `Icons.close` / `close_rounded` | 12 | Close/dismiss |
| `Icons.add` / `add_rounded` | 7 | Add action |
| `Icons.more_vert` | 3 | Overflow menu |
| `Icons.expand_more_rounded` | 3 | Expand |
| `Icons.refresh` / `refresh_rounded` | 7 | Refresh |
| `Icons.search_rounded` | 2 | Search |
| `Icons.settings` | 1 | Settings |

### User & Social Icons

| Icon | Usage Count (app) | Context |
|------|:-:|---------|
| `Icons.person_rounded` | 3 | User/profile |
| `Icons.people` | 5 | Groups |
| `Icons.groups` | 5 | Classes |
| `Icons.class_` | 3 | Classroom |
| `Icons.school` / variants | 4 | School |

### Management Icons

| Icon | Usage Count (app) | Context |
|------|:-:|---------|
| `Icons.lock_rounded` | 9 | Locked content |
| `Icons.lock_outline` | 4 | Lock variant |
| `Icons.lock_open` | 1 | Unlocked |
| `Icons.assignment` / variants | 8 | Assignments |
| `Icons.route` / variants | 8 | Learning path |
| `Icons.schedule` | 5 | Schedule/time |
| `Icons.calendar_today` | 5 | Calendar |
| `Icons.download` / variants | 3 | Download |
| `Icons.swap_horiz` | 3 | Swap/switch |

---

## PRIORITY 5 — Admin Panel Only

> Admin panel stays in Turkish and is internal. Lower priority for stylization.
> Full list of admin-specific icons for reference.

| Icon | Usage Count (admin) | Context |
|------|:-:|---------|
| `Icons.add` | 45 | Add buttons |
| `Icons.arrow_back` | 44 | Navigation |
| `Icons.delete_outline` | 17 | Delete |
| `Icons.check_circle` | 17 | Success |
| `Icons.error_outline` | 16 | Error |
| `Icons.chevron_right` | 11 | Navigation |
| `Icons.info_outline` | 10 | Info |
| `Icons.upload` | 7 | Upload |
| `Icons.school` | 7 | School mgmt |
| `Icons.edit` | 7 | Edit |
| `Icons.clear` | 7 | Clear/reset |
| `Icons.bolt` | 7 | XP config |
| `Icons.quiz` | 8 | Quiz mgmt |
| `Icons.menu_book` | 8 | Book mgmt |
| `Icons.cancel` | 8 | Cancel |
| `Icons.class_` / variants | 9 | Class mgmt |
| `Icons.abc` | 6 | Vocab mgmt |
| `Icons.account_tree` / variants | 6 | Tree/hierarchy |
| `Icons.cloud_upload` | 4 | Upload |
| `Icons.drag_handle` | 4 | Drag reorder |
| `Icons.pets` | 3 | Avatar animals |
| `Icons.checkroom` | 2 | Avatar accessories |
| `Icons.casino` | 1 | Card pack rarity |
| `Icons.category` | 1 | Categories |
| `Icons.auto_fix_high` | 1 | Auto-generate |

---

## Migration Status (2026-04-01)

| Category | Replaced | Remaining | Notes |
|----------|:--------:|:---------:|-------|
| Bottom Nav | 5/5 | 0 | All tabs use PNG |
| Top Navbar Stats | 3/3 | 0 | Fire, gem, UK flag |
| Streak Sheet | 3/3 | 0 | Fire, fire blue |
| Learning Path Nodes | 18/18 | 0 | 4 types × 4 states + unit × 2 |
| League Tier Icons | 5/5 | 0 | All 5 tiers |
| Coin Icons | 13/13 | 0 | All → gem_outline |
| XP Icons | 6/13 | 7 | Partial (widget constraints) |
| Assignment Badge | 1/1 | 0 | Quest PNG on nodes |
| High Visibility (Tier 1) | 0/6 | 6 | check_circle, quiz, etc. |
| Medium (Tier 2-4) | 0/~44 | ~44 | Secondary screens |
| Low (Tier 5) | 0/~15 | ~15 | File mgmt, auth, teacher |

**Total: 30+ PNG assets, 64 Material Icons remaining (94 usages)**

### Remaining high-priority icons for next session:
- check_circle_rounded (5x) — quest completion, quiz, profile
- check_rounded (3x) — daily quests, library
- quiz_rounded (3x) — reader, library, book detail
- lock_rounded (4x) — login, quests, library, cards
- menu_book_rounded (4x) — quiz, profile, library
- Icons.bolt_rounded (7x remaining) — widget constraints need asset support
