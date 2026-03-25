# Class Detail UX v2 + Login Cards PDF — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Improve class management UX (remove email, bottom action buttons) and add PDF login card generation.

**Architecture:** 3 tasks. Task 1: add pdf+printing packages. Task 2: create PDF generator utility. Task 3: update class detail screen (UX fixes + download button).

**Tech Stack:** Flutter, `pdf` package, `printing` package, Riverpod

**Spec:** `docs/superpowers/specs/2026-03-25-class-detail-ux-v2.md`

---

## Task 1: Add pdf + printing Dependencies

**Files:**
- Modify: `pubspec.yaml`

- [ ] **Step 1: Add dependencies**

Run:
```bash
flutter pub add pdf printing
```

- [ ] **Step 2: Verify**

Run: `flutter pub get`

- [ ] **Step 3: Commit**

```
chore: add pdf and printing packages for login card generation
```

---

## Task 2: Create Login Cards PDF Generator

**Files:**
- Create: `lib/presentation/utils/login_cards_pdf.dart`

- [ ] **Step 1: Create the PDF utility**

This is a standalone function — no widget, no provider. Takes data in, returns PDF bytes out.

```dart
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../domain/entities/teacher.dart';

/// Generates a PDF document with student login cards.
///
/// A4 format, 2 columns × 5 rows = 10 cards per page.
/// Each card shows: name, username, password, QR code, download URL.
Future<Uint8List> generateLoginCardsPdf({
  required List<StudentSummary> students,
  required String schoolName,
  required String className,
}) async {
  final pdf = pw.Document();
  const cardsPerPage = 10;
  const columns = 2;
  const rows = 5;
  const downloadUrl = 'owlio.co/download';
  final now = DateTime.now();
  final dateStr = '${_monthName(now.month)} ${now.day}, ${now.year}';

  final totalPages = (students.length / cardsPerPage).ceil();

  for (var page = 0; page < totalPages; page++) {
    final startIdx = page * cardsPerPage;
    final endIdx = (startIdx + cardsPerPage).clamp(0, students.length);
    final pageStudents = students.sublist(startIdx, endIdx);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              _buildHeader(schoolName, className, dateStr),
              pw.SizedBox(height: 12),

              // Cards grid
              pw.Expanded(
                child: pw.Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: pageStudents.map((student) {
                    return _buildCard(
                      student: student,
                      downloadUrl: downloadUrl,
                      cardWidth: (PdfPageFormat.a4.width - 48 - 12) / columns, // margins + spacing
                    );
                  }).toList(),
                ),
              ),

              // Footer
              _buildFooter(schoolName, page + 1, totalPages),
            ],
          );
        },
      ),
    );
  }

  return pdf.save();
}

pw.Widget _buildHeader(String schoolName, String className, String dateStr) {
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                schoolName,
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColor.fromHex('#008080'),
                ),
              ),
              pw.Text(
                'Student Login Cards',
                style: pw.TextStyle(
                  fontSize: 10,
                  color: PdfColor.fromHex('#008080'),
                ),
              ),
            ],
          ),
          pw.Text(
            dateStr,
            style: const pw.TextStyle(fontSize: 10),
          ),
        ],
      ),
      pw.SizedBox(height: 8),
      pw.Divider(color: PdfColor.fromHex('#008080'), thickness: 2),
      pw.SizedBox(height: 8),
      pw.Text(
        className,
        style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
      ),
    ],
  );
}

pw.Widget _buildCard({
  required StudentSummary student,
  required String downloadUrl,
  required double cardWidth,
}) {
  final username = student.username ?? student.studentNumber ?? 'N/A';
  final password = student.passwordPlain ?? 'N/A';

  return pw.Container(
    width: cardWidth,
    padding: const pw.EdgeInsets.all(10),
    decoration: pw.BoxDecoration(
      border: pw.Border.all(color: PdfColors.grey400),
      borderRadius: pw.BorderRadius.circular(4),
    ),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Left: text info
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                student.fullName,
                style: pw.TextStyle(
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                ),
                maxLines: 1,
              ),
              pw.SizedBox(height: 6),
              pw.RichText(
                text: pw.TextSpan(
                  children: [
                    pw.TextSpan(
                      text: 'Username:\n',
                      style: pw.TextStyle(
                        fontSize: 8,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColor.fromHex('#008080'),
                      ),
                    ),
                    pw.TextSpan(
                      text: username,
                      style: const pw.TextStyle(fontSize: 10),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 4),
              pw.RichText(
                text: pw.TextSpan(
                  children: [
                    pw.TextSpan(
                      text: 'Password:\n',
                      style: pw.TextStyle(
                        fontSize: 8,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColor.fromHex('#008080'),
                      ),
                    ),
                    pw.TextSpan(
                      text: password,
                      style: const pw.TextStyle(fontSize: 10),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                downloadUrl,
                style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600),
              ),
            ],
          ),
        ),
        // Right: QR code
        pw.SizedBox(width: 8),
        pw.BarcodeWidget(
          barcode: pw.Barcode.qrCode(),
          data: 'https://$downloadUrl',
          width: 50,
          height: 50,
        ),
      ],
    ),
  );
}

pw.Widget _buildFooter(String schoolName, int currentPage, int totalPages) {
  return pw.Row(
    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
    children: [
      pw.Text(
        schoolName,
        style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
      ),
      pw.Text(
        'Page $currentPage of $totalPages',
        style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
      ),
    ],
  );
}

String _monthName(int month) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return months[month - 1];
}
```

- [ ] **Step 2: Run dart analyze**

Run: `dart analyze lib/presentation/utils/login_cards_pdf.dart`

- [ ] **Step 3: Commit**

```
feat(teacher): add login cards PDF generator utility

A4 format, 2×5 grid per page. Each card shows student name,
username, password, QR code pointing to owlio.co/download.
Uses pdf package for client-side generation.
```

---

## Task 3: Update Class Detail Screen

**Files:**
- Modify: `lib/presentation/screens/teacher/class_detail_screen.dart`

- [ ] **Step 1: Read the current file**

Read the full file to understand current structure.

- [ ] **Step 2: Remove email from _showStudentInfoSheet**

Find the email ListTile (around line 214-228) and delete it entirely:
```dart
// DELETE THIS BLOCK:
if (student.email != null)
  ListTile(
    leading: const Icon(Icons.email_outlined),
    ...
  ),
```

- [ ] **Step 3: Remove AppBar select button**

In the `build` method, remove the `actions` list from AppBar:
```dart
// Before
actions: [
  if (isManagement)
    _isSelectMode
        ? TextButton.icon(...)
        : TextButton.icon(...),
],

// After
// No actions
```

- [ ] **Step 4: Change ListView bottom padding for action buttons**

The ListView currently adds bottom padding of 80 in select mode. Change to always add 140 in management mode (space for 2 buttons):

```dart
padding: EdgeInsets.fromLTRB(
  16, 16, 16,
  isManagement ? (_isSelectMode ? 80 : 140) : 16,
),
```

- [ ] **Step 5: Add bottom action buttons + download button**

In the `Stack` children, after the `_MoveBar` Positioned, add:

```dart
// Bottom action buttons (management mode, not select mode)
if (isManagement && !_isSelectMode)
  Positioned(
    left: 16,
    right: 16,
    bottom: 16,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _toggleSelectMode,
            icon: const Icon(Icons.swap_horiz),
            label: const Text('Select & Move Students'),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => _downloadLoginCards(context, students),
            icon: const Icon(Icons.download),
            label: const Text('Download Login Cards'),
          ),
        ),
      ],
    ),
  ),
```

Note: `students` variable needs to be accessible here — it's already in scope from the `data: (students)` callback.

- [ ] **Step 6: Implement _downloadLoginCards method**

Add to `_ClassDetailScreenState`:

```dart
Future<void> _downloadLoginCards(BuildContext context, List<StudentSummary> students) async {
  final profileContext = ref.read(profileContextProvider).valueOrNull;
  final schoolName = profileContext?.schoolName ?? 'School';

  // TODO: get class name — for now use "Class" as placeholder
  // ClassesProvider returns TeacherClass which has .name, but we only have classId
  final classesAsync = ref.read(currentTeacherClassesProvider).valueOrNull;
  final className = classesAsync?.firstWhere(
    (c) => c.id == widget.classId,
    orElse: () => classesAsync!.first,
  ).name ?? 'Class';

  final pdfBytes = await generateLoginCardsPdf(
    students: students,
    schoolName: schoolName,
    className: className,
  );

  if (!context.mounted) return;

  await Printing.layoutPdf(
    onLayout: (_) => pdfBytes,
    name: 'login_cards_$className',
  );
}
```

- [ ] **Step 7: Add imports**

```dart
import 'package:printing/printing.dart';
import '../../utils/login_cards_pdf.dart';
import '../../providers/profile_context_provider.dart';
```

- [ ] **Step 8: Run dart analyze**

Run: `dart analyze lib/presentation/screens/teacher/class_detail_screen.dart`

- [ ] **Step 9: Commit**

```
feat(teacher): class detail bottom actions + login cards download

- Remove email from student info sheet
- Move select/move to bottom action area (clearer UX)
- Add "Download Login Cards" button — generates A4 PDF with
  student credentials (name, username, password, QR code)
```

---

## Pre-flight Checklist
- [ ] On `main` branch
- [ ] `flutter pub get` runs clean
- [ ] `dart analyze lib/` has 0 errors
