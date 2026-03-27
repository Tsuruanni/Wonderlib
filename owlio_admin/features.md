# Owlio Admin Panel — Feature Map

## Content Management

| # | Feature | Description | Complexity | Doc Priority | Doc Status |
|---|---------|-------------|------------|--------------|------------|
| 1 | **Book CRUD** | Create/edit books (title, author, CEFR level, status), chapter management, content block editor | Medium | Medium | - |
| 2 | **Book JSON Import** | 3-step wizard: file upload → validation → batch import (books, chapters, content blocks, activities, quizzes) | High | Medium | - |
| 3 | **Chapter Editor** | Chapter content editing with content blocks (text, image, audio) and inline activity placement | Medium | Low | - |
| 4 | **Inline Activity Editor** | Create/edit in-chapter activities (true_false, word_translation, find_words, matching) | High | Medium | - |
| 5 | **Book Quiz Editor** | Quiz creation with 5 question types (multiple_choice, fill_blank, event_sequencing, matching, who_says_what), pass threshold, point system | High | Medium | - |
| 6 | **Vocabulary CRUD** | Word management with pagination, search, audio/image filters | Medium | Low | - |
| 7 | **Vocabulary CSV Import** | CSV upload with header validation, row-level error reporting, batch upsert | High | Low | - |
| 8 | **Word List Editor** | Create/edit word lists with word picker, drag-and-drop reordering | Medium | Low | - |

## User & School Management

| # | Feature | Description | Complexity | Doc Priority | Doc Status |
|---|---------|-------------|------------|--------------|------------|
| 9 | **School Management** | School CRUD + nested class management + student roster assignment | High | Low | - |
| 10 | **User Management** | User list with school/class/role filters, create users, tabbed detail view (profile, reading progress, badges, cards, quiz results) | High | Low | - |

## Gamification Management

| # | Feature | Description | Complexity | Doc Priority | Doc Status |
|---|---------|-------------|------------|--------------|------------|
| 11 | **Badge Editor** | Create/edit badges with condition types (xp_total, streak_days, books_completed, etc.), threshold values, XP rewards, categories | High | Medium | - |
| 12 | **Card Editor** | Mythology card management with image upload, auto-increment card numbers, rarity tiers, categories | Medium | Low | - |
| 13 | **Quest Management** | Daily quest list with inline editing (title, goal, reward), toggle active status, completion statistics via RPC | High | Medium | - |
| 14 | **Avatar Management** | 3-tab interface: avatar bases (image upload), categories, items (image upload, rarity) | Medium | Low | - |

## Learning Paths

| # | Feature | Description | Complexity | Doc Priority | Doc Status |
|---|---------|-------------|------------|--------------|------------|
| 15 | **Learning Path Templates** | Hierarchical template editor (template → units → items), tree-view UI, sequential lock config | High | **High** | - |
| 16 | **Learning Path Assignments** | Scope-based assignment (school/grade/class), template application, dynamic tree-view editing | Very High | **High** | - |
| 17 | **Teacher Assignments (Read-Only)** | View teacher-created assignments with type filter, student submissions, grades | Simple | Low | - |

## System & Analytics

| # | Feature | Description | Complexity | Doc Priority | Doc Status |
|---|---------|-------------|------------|--------------|------------|
| 18 | **System Settings** | Multi-category settings editor (xp_reading, xp_vocab, progression, game, app) with inline editing | High | Medium | - |
| 19 | **Notification Gallery** | Preview all notification types, toggle on/off, edit settings per type | High | Low | - |
| 20 | **Recent Activity** | Multi-section analytics dashboard (active users, recent books/chapters/words/activities/users) | High | Low | - |
| 21 | **Dashboard** | Overview stats with quick-access cards to all sections | Simple | Low | - |
| 22 | **Auth** | Email/password login with admin/head-teacher role verification | Medium | Low | - |

## Doc Priority Guide

- **High**: Complex business logic, hierarchical data, cross-system interactions — Claude can't infer from code alone
- **Medium**: Non-trivial but patterns are partially visible in code
- **Low**: Standard CRUD or read-only — code is self-documenting

## Supabase Tables Touched (27 tables)

**Core:** books, chapters, content_blocks, schools, classes, profiles
**Academic:** vocabulary_words, word_lists, word_list_items, vocabulary_units
**Learning Paths:** learning_path_templates, learning_path_template_units, learning_path_template_items, scope_learning_paths, scope_learning_path_units, scope_unit_items
**Assessments:** book_quizzes, book_quiz_questions, book_quiz_results, inline_activities, inline_activity_results
**Gamification:** badges, user_badges, daily_quests, myth_cards, user_cards
**Avatar:** avatar_bases, avatar_items, avatar_item_categories
**System:** system_settings, assignments, xp_logs, reading_progress
