# Book JSON Import — Design Spec

**Date:** 2026-03-10
**Status:** Approved

## Summary

Admin panele JSON formatında kitap import özelliği eklenmesi. Üretim sistemi tarafından oluşturulan JSON dosyalarını admin panel üzerinden Supabase'e aktarma.

## Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Input method | File upload + paste (both) | Flexibility for different workflows |
| Post-import flow | Navigate to book edit page | Immediate review/editing |
| Error handling | Validate-first (two-phase) | Full validation before any DB writes |
| Slug conflict | Error — block import | No accidental overwrites |
| Audio/word_timings | Optional, not included initially | Production system generates text + activities only |
| UI approach | 3-step Stepper/Wizard | Natural fit for validate-first flow |

## Architecture

### New Files

```
owlio_admin/lib/features/books/
├── screens/
│   └── book_json_import_screen.dart   ← Stepper UI (ConsumerStatefulWidget)
└── services/
    └── book_json_validator.dart        ← Validation + parsing (pure Dart, no UI)
```

### Modified Files

```
owlio_admin/lib/features/books/screens/book_list_screen.dart  ← "Import JSON" button
owlio_admin/lib/core/router.dart                               ← /books/import route
```

## User Flow

### Step 1: JSON Input

- Two input options side by side: file upload (.json) OR textarea paste
- File upload uses `FilePicker` (same as existing CSV imports)
- Textarea shows JSON with monospace font
- When file is selected, its content populates the textarea
- "Validate" button advances to step 2

### Step 2: Validation & Preview

- JSON is parsed and validated against the expected schema
- **If valid:** Green success banner + content summary (book title, level, chapter count, content block count, inline activity count, quiz question count). "Import" button enabled.
- **If invalid:** Red error banner + error list with paths (e.g., `chapters[2].content_blocks[1]: type "video" not supported`). "Import" button disabled. User goes back to step 1 to fix.
- **Slug conflict:** Treated as validation error — "Book with slug 'x' already exists"

### Step 3: Import

- Sequential DB inserts with progress indicator:
  1. Create book record
  2. Create chapters (ordered)
  3. Create inline activities (with chapter_id from parent context)
  4. Create content blocks (links activity_id for activity-type blocks)
  5. Create book quiz + questions (if book_quiz present)
- Progress shown as checklist with status icons
- On completion: navigate to `/books/:id` (book edit screen)
- On failure: show error, offer retry

## JSON Schema

```json
{
  "book": {
    "title": "string (required)",
    "slug": "string (required)",
    "level": "A1|A2|B1|B2|C1|C2 (required)",
    "description": "string?",
    "cover_url": "string?",
    "genre": "string?",
    "age_group": "string?",
    "estimated_minutes": "int?",
    "word_count": "int?",
    "lexile_score": "int?",
    "status": "string? (default: 'draft')",
    "metadata": "object?"
  },
  "chapters": [
    {
      "title": "string (required)",
      "order_index": "int (required)",
      "word_count": "int?",
      "estimated_minutes": "int?",
      "vocabulary": [
        { "word": "string", "meaning": "string?", "phonetic": "string?", "startIndex": "int?", "endIndex": "int?" }
      ],
      "content_blocks": [
        {
          "order_index": "int (required)",
          "type": "text|image|activity (required)",
          "text": "string? (required if type=text)",
          "image_url": "string? (required if type=image)",
          "caption": "string?",
          "audio_url": "string?",
          "audio_start_ms": "int?",
          "audio_end_ms": "int?",
          "word_timings": "WordTiming[]? (optional, for future use)",
          "inline_activity": {
            "type": "true_false|word_translation|find_words|matching (required)",
            "after_paragraph_index": "int (default: 0)",
            "xp_reward": "int (default: 5)",
            "vocabulary_words": "string[]",
            "content": "object (type-dependent, required)"
          }
        }
      ]
    }
  ],
  "book_quiz": "object? (optional — book can be imported without quiz)",
  "book_quiz.structure": {
    "title": "string (required)",
    "instructions": "string?",
    "passing_score": "float (default: 70.0)",
    "total_points": "int (default: 10)",
    "is_published": "bool (default: false)",
    "questions": [
      {
        "type": "multiple_choice|fill_blank|event_sequencing|matching|who_says_what (required)",
        "order_index": "int (default: 0)",
        "question": "string (required)",
        "points": "int (default: 1)",
        "explanation": "string?",
        "content": "object (type-dependent, required)"
      }
    ]
  }
}
```

## Validation Rules

### Book
- `title`: non-empty string
- `slug`: non-empty, lowercase, alphanumeric + hyphens only, unique (DB check)
- `level`: must be one of A1, A2, B1, B2, C1, C2
- `status`: if provided, must be one of draft, published, archived

### Chapters
- `chapters`: non-empty array
- Each chapter: `title` non-empty, `order_index` unique within chapters
- `content_blocks`: at least one per chapter

### Content Blocks
- `type`: must be text, image, or activity
- If `type=text`: `text` required, non-empty
- If `type=image`: `image_url` required
- If `type=activity`: `inline_activity` required with valid structure
- Note: `audio` type blocks are not accepted during import (audio added separately via admin panel)

### Inline Activities
- `type`: must be one of true_false, word_translation, find_words, matching
- Content validated per type:
  - `true_false`: `statement` (string), `correct_answer` (bool)
  - `word_translation`: `word`, `correct_answer` (strings), `options` (array, min 2)
  - `find_words`: `instruction` (string), `options` (array), `correct_answers` (subset of options)
  - `matching`: `instruction` (string), `pairs` (array of {left, right}, min 2)

### Book Quiz
- `book_quiz`: optional (null or absent = no quiz imported)
- `title`: non-empty
- `questions`: non-empty array
- DB constraint: one quiz per book (UNIQUE on book_id). Validation must check no existing quiz for this book.
- Each question `type`: must be valid BookQuizQuestionType
- Content validated per type:
  - `multiple_choice`: `options` (non-empty array, min 2), `correct_answer` (must match one option)
  - `fill_blank`: `sentence` (contains ___), `correct_answer` (string), `accept_alternatives` (string[]?, optional)
  - `event_sequencing`: `events` (array, min 2), `correct_order` (array of indices, same length as events)
  - `matching`: `left`, `right` (arrays, same length, min 2), `correct_pairs` (valid index mapping)
  - `who_says_what`: `characters`, `quotes` (arrays, same length, min 2), `correct_pairs` (valid index mapping)

## DB Insert Order

```
1. books              → generates book_id
2. chapters           → uses book_id, generates chapter_ids
3. inline_activities  → uses chapter_id (from parent chapter context), generates activity_ids
4. content_blocks     → uses chapter_id, links activity_id for type=activity blocks
5. book_quizzes       → uses book_id, generates quiz_id (only if book_quiz provided)
6. book_quiz_questions → uses quiz_id
```

Note: inline_activities are created BEFORE content_blocks because content_blocks reference activity_id. The chapter_id for each inline_activity is derived from the parent chapter in the JSON nesting.

## Technical Notes

- All IDs generated with `Uuid().v4()`
- All table access via `DbTables.*` constants
- `book_json_validator.dart` is pure Dart (no Flutter/UI imports) for testability
- Validator returns a result object with either parsed data or error list
- Import uses individual inserts (not batch) for granular progress tracking
- `status` defaults to `draft` — user publishes manually after review
- `book_quiz` is optional — books can be imported without a quiz
- Audio fields (`audio_url`, `word_timings`, `audio_start_ms`, `audio_end_ms`) are accepted but optional — to be populated later
