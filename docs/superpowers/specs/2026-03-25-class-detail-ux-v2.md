# Class Detail UX v2 + Login Cards PDF — Design Spec

## Goal

Improve class management UX: remove email from info sheet, move select/move to bottom action area, and add PDF login card generation for printing student credentials.

## Scope

1. Student info sheet: remove email
2. AppBar "Select" → bottom action buttons ("Select & Move Students" + "Download Login Cards")
3. Client-side PDF generation with student login cards (A4, 2×5 grid, QR code)

## Changes to Class Detail Screen (Management Mode)

### Student Info Sheet
- **Remove** email ListTile
- Keep: name header, student number, password (with copy), move to class, view profile

### Bottom Action Area
Remove AppBar "Select/Cancel" TextButton. Add persistent bottom action area (only in management mode, not in select mode):

```
┌──────────────────────────────────────────┐
│  [📋 Select & Move Students]             │
│  [📥 Download Login Cards]               │
└──────────────────────────────────────────┘
```

- Two full-width `OutlinedButton.icon` stacked vertically in a `Column` with padding
- Visible only when `!_isSelectMode`
- During select mode: the floating `_MoveBar` replaces them

### Select Mode Flow (unchanged)
Checkbox + floating bar + move to sheet — same as current.

## Login Cards PDF Feature

### Trigger
"Download Login Cards" button → generates PDF → opens print/save dialog via `printing` package.

### PDF Layout (per page)
```
┌─────────────────────────────────────────────────┐
│ 🦉 [School Name]                    Mar 25, 2026│
│    Student Login Cards                           │
│                                                  │
│ [Class Name]                                     │
│                                                  │
│ ┌──────────────────┐  ┌──────────────────┐      │
│ │ Student Name     │  │ Student Name     │      │
│ │ Username: XX123  │  │ Username: YY456  │      │
│ │ Password: abc12  │  │ Password: def34  │      │
│ │ owlio.co/download│  │ owlio.co/download│      │
│ │          [QR]    │  │          [QR]    │      │
│ └──────────────────┘  └──────────────────┘      │
│ ┌──────────────────┐  ┌──────────────────┐      │
│ │ ...              │  │ ...              │      │
│ └──────────────────┘  └──────────────────┘      │
│ ... (5 rows × 2 cols = 10 per page)             │
│                                                  │
│ [School Name]                        Page 1 of 2│
└─────────────────────────────────────────────────┘
```

### Card Content
- **Student name** (bold, larger)
- **Username:** `student.username` (fallback: `student.studentNumber`, fallback: "N/A")
- **Password:** `student.passwordPlain` (fallback: "N/A")
- **QR code** encoding `https://owlio.co/download`
- **URL text** `owlio.co/download` below QR
- Bordered box with slight padding

### PDF Header
- Owlio logo/icon (optional — text "Owlio" is fine if logo asset is hard to embed)
- School name (bold)
- "Student Login Cards" subtitle
- Date (formatted: "Mar 25, 2026")
- Class name below header

### PDF Footer
- School name (left)
- Page X of Y (right)

### Technical Approach

**Packages needed:**
- `pdf: ^3.x` — Dart-native PDF generation (no Flutter dependency)
- `printing: ^5.x` — Platform print/save dialog (works on web + mobile)

QR code: `pdf` package has built-in barcode support including QR via `Barcode.qr()` — no separate QR package needed.

**Data flow:**
1. Button tap → get students from `classStudentsProvider`
2. Get school name from `profileContextProvider`
3. Build PDF document using `pdf` package
4. Call `Printing.layoutPdf()` to show print/save dialog

**File structure:**
- New utility: `lib/presentation/utils/login_cards_pdf.dart` — standalone function that takes student list + school name + class name → returns PDF bytes
- Called from class detail screen

### Colors/Branding
- Header bar: teal/primary color matching Owlio theme
- Card border: grey (#CCCCCC)
- Username/Password labels: teal/bold
- Student name: black/bold
- QR code: black on white

## Files to Change

| File | Change |
|------|--------|
| `lib/presentation/screens/teacher/class_detail_screen.dart` | Remove email from sheet, move select to bottom, add download button |
| `lib/presentation/utils/login_cards_pdf.dart` | New — PDF generation utility |
| `pubspec.yaml` | Add `pdf` and `printing` dependencies |

## Out of Scope
- Custom logo embedding (use text "Owlio" for now)
- Per-student QR codes (all point to same download URL)
- Editing credentials from the PDF view
