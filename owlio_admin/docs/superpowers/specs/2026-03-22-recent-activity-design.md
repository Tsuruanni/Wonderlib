# Recent Activity Page — Design Spec

**Date:** 2026-03-22
**Scope:** Admin panel — new "Son Etkinlikler" page showing recent data across all major tables

---

## Overview

A new read-only page accessible from the dashboard that shows recent activity across the platform: recently added content, user activity, student progress, and summary statistics.

**Route:** `/recent-activity`
**Dashboard:** New navigation card with `Icons.timeline` icon

---

## Layout

### Top: Summary Cards (2, side by side)

| Card | Query | Display |
|------|-------|---------|
| Today's Active Users | `xp_logs` WHERE `created_at >= today`, COUNT DISTINCT `user_id` | Number |
| This Week's Total XP | `xp_logs` WHERE `created_at >= 7 days ago`, SUM `xp_amount` | Number |

### Bottom: 2-Column Grid (10 section cards)

Each card: title + 10-row list + "Tümünü Gör" link (navigates to relevant page if exists)

**Left Column (Content):**

1. **Son Eklenen Kitaplar** — `books` ORDER BY `created_at` DESC LIMIT 10
   - Display: title · level · created_at
   - Link: `/books`

2. **Son Eklenen Bölümler** — `chapters` JOIN `books` ORDER BY `chapters.created_at` DESC LIMIT 10
   - Display: chapter title · book title · created_at
   - Link: none (no standalone chapters page)

3. **Son Eklenen Kelimeler** — `vocabulary_words` ORDER BY `created_at` DESC LIMIT 10
   - Display: word · meaning_tr · source badge · created_at
   - Link: `/vocabulary`

4. **Son Eklenen Aktiviteler** — `inline_activities` JOIN `chapters` ORDER BY `inline_activities.created_at` DESC LIMIT 10
   - Display: type badge · chapter title · created_at
   - Link: none

5. **Son Ödevler** — `scope_learning_paths` JOIN `learning_path_templates` ORDER BY `scope_learning_paths.created_at` DESC LIMIT 10
   - Display: template name · created_at
   - Link: `/learning-paths`

**Right Column (Users & Progress):**

6. **Son Eklenen Kullanıcılar** — `profiles` ORDER BY `created_at` DESC LIMIT 10
   - Display: display_name · role badge · created_at
   - Link: `/users`

7. **Son Aktif Kullanıcılar** — `profiles` ORDER BY `last_sign_in_at` DESC NULLS LAST LIMIT 10
   - Display: display_name · last_sign_in_at
   - Link: `/users`

8. **Son Tamamlanan Aktiviteler** — `inline_activity_results` JOIN `profiles` JOIN `inline_activities` ORDER BY `answered_at` DESC LIMIT 10
   - Display: student name · activity type · correct/wrong icon · answered_at
   - Link: none

9. **Son Okuma İlerlemeleri** — `reading_progress` JOIN `profiles` JOIN `chapters` ORDER BY `updated_at` DESC LIMIT 10
   - Display: student name · chapter title · updated_at
   - Link: none

10. **Son XP Kazanımları** — `xp_logs` JOIN `profiles` ORDER BY `created_at` DESC LIMIT 10
    - Display: student name · xp_amount · source · created_at
    - Link: none

---

## Files

| File | Action |
|------|--------|
| `lib/features/recent_activity/screens/recent_activity_screen.dart` | Create |
| `lib/features/dashboard/screens/dashboard_screen.dart` | Modify (add card) |
| `lib/core/router.dart` | Modify (add route) |

## No DB changes required.
