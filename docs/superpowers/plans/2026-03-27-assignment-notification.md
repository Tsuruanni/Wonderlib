# Assignment Notification Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Show an in-app notification dialog when a student opens the app and has active (uncompleted) assignments.

**Architecture:** Follows the existing event-based notification pattern. A new `assignmentNotificationEventProvider` fires when `activeAssignmentsProvider` resolves with count > 0. `LevelUpCelebrationListener` picks it up and shows an `AssignmentNotificationDialog`. Fires once per app session (guarded by a flag). Admin-toggleable via `notif_assignment` in `system_settings`.

**Tech Stack:** Flutter, Riverpod, Supabase (migration), GoRouter (navigation to assignments screen)

---

## File Structure

| Action | File | Responsibility |
|--------|------|----------------|
| Create | `supabase/migrations/20260327000002_notif_assignment_setting.sql` | Add `notif_assignment` toggle to system_settings |
| Modify | `lib/domain/entities/system_settings.dart` | Add `notifAssignment` field |
| Modify | `lib/data/models/settings/system_settings_model.dart` | Add JSON parsing + toEntity for `notifAssignment` |
| Modify | `lib/presentation/providers/student_assignment_provider.dart` | Add `AssignmentNotificationEvent` class + event provider |
| Modify | `lib/presentation/widgets/common/level_up_celebration.dart` | Listen to assignment event, show dialog, session guard |
| Create | `lib/presentation/widgets/common/assignment_notification_dialog.dart` | Dialog UI with count + "View Assignments" button |
| Modify | `owlio_admin/lib/features/notifications/screens/notification_gallery_screen.dart` | Add Assignment notification card |

---

### Task 1: Database Migration — `notif_assignment` setting

**Files:**
- Create: `supabase/migrations/20260327000002_notif_assignment_setting.sql`

- [ ] **Step 1: Create migration file**

```sql
-- Add assignment notification setting
INSERT INTO system_settings (key, value, category, description, sort_order) VALUES
  ('notif_assignment', '"true"', 'notification', 'Show dialog when student has active assignments on app open', 8)
ON CONFLICT (key) DO NOTHING;
```

- [ ] **Step 2: Dry-run to verify**

Run: `supabase db push --dry-run`
Expected: Migration listed as pending, no errors.

- [ ] **Step 3: Push migration**

Run: `supabase db push`
Expected: Migration applied successfully.

- [ ] **Step 4: Commit**

```bash
git add supabase/migrations/20260327000002_notif_assignment_setting.sql
git commit -m "feat(db): add notif_assignment system setting"
```

---

### Task 2: SystemSettings Entity + Model — Add `notifAssignment`

**Files:**
- Modify: `lib/domain/entities/system_settings.dart`
- Modify: `lib/data/models/settings/system_settings_model.dart`

- [ ] **Step 1: Add field to entity**

In `lib/domain/entities/system_settings.dart`, add `notifAssignment` after the other notification fields:

```dart
// In constructor, after line 34 (this.notifBadgeEarned = true,):
this.notifAssignment = true,

// In field declarations, after line 73 (final bool notifBadgeEarned;):
final bool notifAssignment;

// In props list, after line 109 (notifBadgeEarned,):
notifAssignment,
```

- [ ] **Step 2: Add field to model**

In `lib/data/models/settings/system_settings_model.dart`:

Constructor — add after `required this.notifBadgeEarned,` (line 28):
```dart
required this.notifAssignment,
```

Field declaration — add after `final bool notifBadgeEarned;` (line 56):
```dart
final bool notifAssignment;
```

`fromMap` — add after `notifBadgeEarned` line (line 96):
```dart
notifAssignment: _toBool(m['notif_assignment'], true),
```

`defaults()` factory — add after `notifBadgeEarned: true,` (line 128):
```dart
notifAssignment: true,
```

`toEntity()` — add after `notifBadgeEarned: notifBadgeEarned,` (line 157):
```dart
notifAssignment: notifAssignment,
```

`fromEntity()` — add after `notifBadgeEarned: e.notifBadgeEarned,` (line 189):
```dart
notifAssignment: e.notifAssignment,
```

- [ ] **Step 3: Verify**

Run: `dart analyze lib/domain/entities/system_settings.dart lib/data/models/settings/system_settings_model.dart`
Expected: No issues found.

- [ ] **Step 4: Commit**

```bash
git add lib/domain/entities/system_settings.dart lib/data/models/settings/system_settings_model.dart
git commit -m "feat: add notifAssignment to SystemSettings entity and model"
```

---

### Task 3: Event Provider — `assignmentNotificationEventProvider`

**Files:**
- Modify: `lib/presentation/providers/student_assignment_provider.dart`

- [ ] **Step 1: Add event class and provider**

At the top of the file (after the existing imports), add:

```dart
/// Assignment notification event — fired when student has active assignments on app open
class AssignmentNotificationEvent {
  const AssignmentNotificationEvent({required this.count});
  final int count;
}

/// Provider for assignment notification events — UI listens to show dialog
final assignmentNotificationEventProvider =
    StateProvider<AssignmentNotificationEvent?>((ref) => null);
```

- [ ] **Step 2: Verify**

Run: `dart analyze lib/presentation/providers/student_assignment_provider.dart`
Expected: No issues found.

- [ ] **Step 3: Commit**

```bash
git add lib/presentation/providers/student_assignment_provider.dart
git commit -m "feat: add assignmentNotificationEventProvider"
```

---

### Task 4: Assignment Notification Dialog Widget

**Files:**
- Create: `lib/presentation/widgets/common/assignment_notification_dialog.dart`

- [ ] **Step 1: Create the dialog widget**

Create `lib/presentation/widgets/common/assignment_notification_dialog.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../providers/student_assignment_provider.dart';

class AssignmentNotificationDialog extends StatefulWidget {
  const AssignmentNotificationDialog({super.key, required this.count});

  final int count;

  @override
  State<AssignmentNotificationDialog> createState() =>
      _AssignmentNotificationDialogState();
}

class _AssignmentNotificationDialogState
    extends State<AssignmentNotificationDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isSingle = widget.count == 1;

    return FadeTransition(
      opacity: _fadeAnimation,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.withValues(alpha: 0.3),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.assignment_rounded,
                    size: 48,
                    color: Colors.blue.shade600,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  isSingle ? 'New Assignment!' : '${ widget.count} Assignments Waiting!',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF1A1A2E),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  isSingle
                      ? 'You have an assignment from your teacher.'
                      : 'You have ${widget.count} assignments from your teacher.',
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.grey.shade600,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          side: BorderSide(color: Colors.grey.shade300),
                        ),
                        child: Text(
                          'Later',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          final navContext = rootNavigatorKey.currentContext;
                          if (navContext != null) {
                            GoRouter.of(navContext).go(AppRoutes.studentAssignments);
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade600,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text(
                          'View',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Verify**

Run: `dart analyze lib/presentation/widgets/common/assignment_notification_dialog.dart`
Expected: No issues found.

- [ ] **Step 3: Commit**

```bash
git add lib/presentation/widgets/common/assignment_notification_dialog.dart
git commit -m "feat: add AssignmentNotificationDialog widget"
```

---

### Task 5: Wire Up LevelUpCelebrationListener

**Files:**
- Modify: `lib/presentation/widgets/common/level_up_celebration.dart`

- [ ] **Step 1: Add imports**

Add these imports at the top of `level_up_celebration.dart`:

```dart
import '../../../domain/entities/system_settings.dart';
import '../../providers/auth_provider.dart';
import '../../providers/student_assignment_provider.dart';
import '../../providers/system_settings_provider.dart';
import 'assignment_notification_dialog.dart';
```

- [ ] **Step 2: Add session guard flag**

In `_LevelUpCelebrationListenerState`, add a flag after the existing fields (after line 29):

```dart
bool _hasShownAssignmentNotif = false;
```

- [ ] **Step 3: Add assignment listener in build()**

In the `build()` method, after the `badgeEarnedEventProvider` listener (after line 70), add:

```dart
ref.listen<AssignmentNotificationEvent?>(assignmentNotificationEventProvider,
    (previous, next) {
  if (next != null) {
    _enqueueDialog(() => _showAssignmentNotification(next));
  }
});

// Fire assignment notification on first load (students only)
if (!_hasShownAssignmentNotif) {
  final isTeacher = ref.watch(isTeacherProvider);
  if (!isTeacher) {
    ref.listen<AsyncValue<List<StudentAssignment>>>(
      activeAssignmentsProvider,
      (previous, next) {
        if (_hasShownAssignmentNotif) return;
        next.whenData((assignments) {
          final count = assignments.where((a) =>
            a.status == StudentAssignmentStatus.pending ||
            a.status == StudentAssignmentStatus.inProgress ||
            a.status == StudentAssignmentStatus.overdue,
          ).length;
          if (count > 0) {
            _hasShownAssignmentNotif = true;
            final settings = ref.read(systemSettingsProvider).valueOrNull
                ?? SystemSettings.defaults();
            if (settings.notifAssignment) {
              ref.read(assignmentNotificationEventProvider.notifier).state =
                  AssignmentNotificationEvent(count: count);
            }
          }
        });
      },
      fireImmediately: true,
    );
  }
}
```

- [ ] **Step 4: Add dialog show method**

After the `_showBadgeEarned` method (after line 117), add:

```dart
Future<void> _showAssignmentNotification(AssignmentNotificationEvent event) async {
  final ctx = rootNavigatorKey.currentContext;
  if (ctx == null) return;
  await showDialog(
    context: ctx,
    barrierDismissible: true,
    builder: (context) => AssignmentNotificationDialog(count: event.count),
  );
  ref.read(assignmentNotificationEventProvider.notifier).state = null;
}
```

- [ ] **Step 5: Add missing import for StudentAssignment entity**

The `activeAssignmentsProvider` returns `List<StudentAssignment>`, and we reference `StudentAssignmentStatus`. Add this import:

```dart
import '../../../domain/entities/student_assignment.dart';
```

- [ ] **Step 6: Verify**

Run: `dart analyze lib/presentation/widgets/common/level_up_celebration.dart`
Expected: No issues found.

- [ ] **Step 7: Commit**

```bash
git add lib/presentation/widgets/common/level_up_celebration.dart
git commit -m "feat: wire assignment notification into celebration listener"
```

---

### Task 6: Admin Panel — Add Assignment Notification Card

**Files:**
- Modify: `owlio_admin/lib/features/notifications/screens/notification_gallery_screen.dart`

- [ ] **Step 1: Add card builder method**

After the `_buildBadgeEarnedCard` method (after line 345), add:

```dart
Widget _buildAssignmentCard(
    Map<String, List<Map<String, dynamic>>> grouped) {
  return _NotifCard(
    icon: Icons.assignment_rounded,
    iconColor: Colors.blue.shade600,
    title: 'Assignment',
    description: 'Shown when student opens app with active assignments',
    isEnabled: _getBool(grouped, 'notif_assignment'),
    isSaving: _savingKeys.contains('notif_assignment'),
    onToggle: (v) => _updateSetting('notif_assignment', v.toString()),
    preview: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _previewRow('Single', 'New Assignment!',
            'You have an assignment from your teacher.'),
        const SizedBox(height: 8),
        _previewRow('Multiple', '3 Assignments Waiting!',
            'You have 3 assignments from your teacher.'),
      ],
    ),
  );
}
```

- [ ] **Step 2: Add card to the Column**

In the `build()` method, after `_buildBadgeEarnedCard(grouped),` (line 145), add:

```dart
const SizedBox(height: 16),
_buildAssignmentCard(grouped),
```

- [ ] **Step 3: Verify**

Run: `dart analyze owlio_admin/lib/features/notifications/screens/notification_gallery_screen.dart`
Expected: No issues found.

- [ ] **Step 4: Commit**

```bash
git add owlio_admin/lib/features/notifications/screens/notification_gallery_screen.dart
git commit -m "feat(admin): add Assignment notification card to gallery"
```

---

### Task 7: Final Verification

- [ ] **Step 1: Full analyze**

Run: `dart analyze lib/ owlio_admin/lib/`
Expected: No issues found.

- [ ] **Step 2: Manual test checklist**

1. Login as `active@demo.com` (Test1234) — has active assignments?
   - If yes: dialog should appear on app open with assignment count
   - Tap "View" → navigates to assignments screen
   - Navigate back to home → dialog should NOT reappear (session guard)
2. Login as `teacher@demo.com` — no assignment dialog should appear
3. Login as `fresh@demo.com` (no assignments) — no dialog should appear
4. Admin panel: open Notifications page → "Assignment" card visible with toggle

- [ ] **Step 3: Final commit (if any fixes needed)**

```bash
git add -A
git commit -m "fix: address assignment notification review findings"
```
