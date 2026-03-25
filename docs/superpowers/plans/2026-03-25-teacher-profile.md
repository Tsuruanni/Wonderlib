# Teacher Profile Page — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the empty teacher profile placeholder with a functional profile page showing personal info, name editing, password reset, and sign out.

**Architecture:** 3 tasks. Task 1 adds the backend chain (repo method + usecase + provider). Task 2 registers the missing `refreshCurrentUserUseCaseProvider`. Task 3 replaces the UI. No migrations needed — uses existing RLS.

**Tech Stack:** Flutter, Riverpod, Supabase (direct table UPDATE via RLS)

**Spec:** `docs/superpowers/specs/2026-03-25-teacher-profile-design.md`

---

## File Map

| File | Action | Responsibility |
|------|--------|----------------|
| `lib/domain/repositories/teacher_repository.dart` | Modify | Add `updateProfile` method to interface |
| `lib/data/repositories/supabase/supabase_teacher_repository.dart` | Modify | Implement `updateProfile` |
| `lib/domain/usecases/teacher/update_teacher_profile_usecase.dart` | Create | UseCase for profile update |
| `lib/presentation/providers/usecase_providers.dart` | Modify | Register 2 new providers |
| `lib/presentation/screens/profile/profile_screen.dart` | Modify | Replace `_buildTeacherFallback` |

---

## Task 1: Add updateProfile Backend Chain

**Files:**
- Modify: `lib/domain/repositories/teacher_repository.dart`
- Modify: `lib/data/repositories/supabase/supabase_teacher_repository.dart`
- Create: `lib/domain/usecases/teacher/update_teacher_profile_usecase.dart`
- Modify: `lib/presentation/providers/usecase_providers.dart`

- [ ] **Step 1: Add method to repository interface**

In `lib/domain/repositories/teacher_repository.dart`, add before the closing `}`:

```dart
  // =============================================
  // PROFILE METHODS
  // =============================================

  /// Update teacher's own profile (first name, last name)
  Future<Either<Failure, void>> updateProfile({
    required String firstName,
    required String lastName,
  });
```

- [ ] **Step 2: Implement in Supabase repository**

In `lib/data/repositories/supabase/supabase_teacher_repository.dart`, add before the closing `}` of the class:

```dart
  // =============================================
  // PROFILE METHODS
  // =============================================

  @override
  Future<Either<Failure, void>> updateProfile({
    required String firstName,
    required String lastName,
  }) async {
    try {
      await _supabase.from(DbTables.profiles).update({
        'first_name': firstName,
        'last_name': lastName,
      }).eq('id', _supabase.auth.currentUser!.id);

      return const Right(null);
    } on PostgrestException catch (e) {
      return Left(ServerFailure(e.message, code: e.code));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
```

Note: This uses RLS policy `"Users can update own profile"` (`id = auth.uid()`).

- [ ] **Step 3: Create usecase**

Create `lib/domain/usecases/teacher/update_teacher_profile_usecase.dart`:

```dart
import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../repositories/teacher_repository.dart';
import '../usecase.dart';

class UpdateTeacherProfileUseCase implements UseCase<void, UpdateTeacherProfileParams> {
  const UpdateTeacherProfileUseCase(this._repository);
  final TeacherRepository _repository;

  @override
  Future<Either<Failure, void>> call(UpdateTeacherProfileParams params) {
    return _repository.updateProfile(
      firstName: params.firstName,
      lastName: params.lastName,
    );
  }
}

class UpdateTeacherProfileParams {
  const UpdateTeacherProfileParams({
    required this.firstName,
    required this.lastName,
  });
  final String firstName;
  final String lastName;
}
```

- [ ] **Step 4: Register providers**

In `lib/presentation/providers/usecase_providers.dart`, add in the teacher section:

```dart
final updateTeacherProfileUseCaseProvider = Provider((ref) {
  return UpdateTeacherProfileUseCase(ref.watch(teacherRepositoryProvider));
});
```

Also add the missing `refreshCurrentUserUseCaseProvider` in the auth section:

```dart
final refreshCurrentUserUseCaseProvider = Provider((ref) {
  return RefreshCurrentUserUseCase(ref.watch(authRepositoryProvider));
});
```

Add imports:
```dart
import '../../domain/usecases/teacher/update_teacher_profile_usecase.dart';
import '../../domain/usecases/auth/refresh_current_user_usecase.dart';
```

- [ ] **Step 5: Run dart analyze**

Run: `dart analyze lib/domain/repositories/teacher_repository.dart lib/data/repositories/supabase/supabase_teacher_repository.dart lib/domain/usecases/teacher/update_teacher_profile_usecase.dart lib/presentation/providers/usecase_providers.dart`

- [ ] **Step 6: Commit**

```
feat(teacher): add updateProfile usecase chain

New TeacherRepository.updateProfile method + UpdateTeacherProfileUseCase.
Also registers missing refreshCurrentUserUseCaseProvider.
```

---

## Task 2: Build Teacher Profile UI

**Files:**
- Modify: `lib/presentation/screens/profile/profile_screen.dart` (replace `_buildTeacherFallback` method, lines 65-103)

- [ ] **Step 1: Read the current profile_screen.dart**

Read the full file to understand imports and existing patterns. Key things to note:
- Line 32: `ref.watch(userControllerProvider)` — use this for teacher profile too
- Line 20: `profileContextProvider` already imported
- Line 16: `authProvider` already imported (has `authControllerProvider`)
- Lines 65-103: `_buildTeacherFallback` — this is what we replace
- The file uses `AppColors`, `GoogleFonts.nunito`, `GameButton`, `showConfirmDialog`, `showAppSnackBar`

- [ ] **Step 2: Replace `_buildTeacherFallback` with full teacher profile**

Replace the `_buildTeacherFallback` method (lines 65-103) with a new `_TeacherProfileBody` widget. Also update the call site at line 57 from `return _buildTeacherFallback(context, ref);` to `return _TeacherProfileBody(user: user);`.

First, change line 57:
```dart
// Before
return _buildTeacherFallback(context, ref);
// After
return _TeacherProfileBody(user: user);
```

Then delete the `_buildTeacherFallback` method entirely (lines 65-103) and add this new widget class after the `ProfileScreen` class (before `_StudentProfileBody`):

```dart
class _TeacherProfileBody extends ConsumerWidget {
  const _TeacherProfileBody({required this.user});
  final User user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileContext = ref.watch(profileContextProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const SizedBox(height: 16),
          // Header: initials circle + name + email + role + school
          _TeacherHeader(
            user: user,
            schoolName: profileContext.valueOrNull?.schoolName,
          ),
          const SizedBox(height: 24),
          // Personal info card
          _PersonalInfoCard(user: user),
          const SizedBox(height: 16),
          // Password card
          _PasswordCard(email: user.email),
          const SizedBox(height: 24),
          // Sign out
          GameButton(
            label: 'SIGN OUT',
            onPressed: () async {
              final confirmed = await context.showConfirmDialog(
                title: 'Sign Out',
                message: 'Are you sure you want to sign out?',
                confirmText: 'Sign Out',
                isDestructive: true,
              );
              if (confirmed ?? false) {
                await ref.read(authControllerProvider.notifier).signOut();
              }
            },
            variant: GameButtonVariant.outline,
            fullWidth: true,
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _TeacherHeader extends StatelessWidget {
  const _TeacherHeader({required this.user, this.schoolName});
  final User user;
  final String? schoolName;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Initials circle
        CircleAvatar(
          radius: 40,
          backgroundColor: _getRoleColor(user.role),
          child: Text(
            user.initials,
            style: GoogleFonts.nunito(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 12),
        // Full name
        Text(
          user.fullName,
          style: GoogleFonts.nunito(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: AppColors.black,
          ),
        ),
        if (user.email != null) ...[
          const SizedBox(height: 4),
          Text(
            user.email!,
            style: GoogleFonts.nunito(
              fontSize: 14,
              color: AppColors.neutralText,
            ),
          ),
        ],
        const SizedBox(height: 8),
        // Role badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: _getRoleColor(user.role).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            _getRoleDisplayName(user.role),
            style: GoogleFonts.nunito(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: _getRoleColor(user.role),
            ),
          ),
        ),
        if (schoolName != null) ...[
          const SizedBox(height: 8),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.school_outlined, size: 16, color: AppColors.neutralText),
              const SizedBox(width: 4),
              Text(
                schoolName!,
                style: GoogleFonts.nunito(
                  fontSize: 14,
                  color: AppColors.neutralText,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Color _getRoleColor(UserRole role) {
    switch (role) {
      case UserRole.teacher:
        return Colors.blue;
      case UserRole.head:
        return Colors.purple;
      case UserRole.admin:
        return Colors.amber.shade700;
      default:
        return Colors.grey;
    }
  }

  String _getRoleDisplayName(UserRole role) {
    switch (role) {
      case UserRole.teacher:
        return 'Teacher';
      case UserRole.head:
        return 'Head Teacher';
      case UserRole.admin:
        return 'Admin';
      default:
        return role.name;
    }
  }
}

class _PersonalInfoCard extends ConsumerWidget {
  const _PersonalInfoCard({required this.user});
  final User user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'Personal Information',
              style: GoogleFonts.nunito(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.black,
              ),
            ),
          ),
          _InfoTile(
            icon: Icons.person_outline,
            label: 'First Name',
            value: user.firstName,
            onTap: () => _editField(context, ref, 'First Name', user.firstName, isFirstName: true),
          ),
          _InfoTile(
            icon: Icons.person_outline,
            label: 'Last Name',
            value: user.lastName,
            onTap: () => _editField(context, ref, 'Last Name', user.lastName, isFirstName: false),
          ),
          _InfoTile(
            icon: Icons.email_outlined,
            label: 'Email',
            value: user.email ?? '—',
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Future<void> _editField(
    BuildContext context,
    WidgetRef ref,
    String fieldName,
    String currentValue, {
    required bool isFirstName,
  }) async {
    final controller = TextEditingController(text: currentValue);
    final formKey = GlobalKey<FormState>();

    final newValue = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit $fieldName'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText: fieldName,
              border: const OutlineInputBorder(),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return '$fieldName cannot be empty';
              }
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(context, controller.text.trim());
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (newValue == null || newValue == currentValue) return;
    if (!context.mounted) return;

    final firstName = isFirstName ? newValue : user.firstName;
    final lastName = isFirstName ? user.lastName : newValue;

    final useCase = ref.read(updateTeacherProfileUseCaseProvider);
    final result = await useCase(UpdateTeacherProfileParams(
      firstName: firstName,
      lastName: lastName,
    ));

    if (!context.mounted) return;

    result.fold(
      (failure) {
        showAppSnackBar(context, 'Error: ${failure.message}', type: SnackBarType.error);
      },
      (_) async {
        showAppSnackBar(context, '$fieldName updated', type: SnackBarType.success);
        // Refresh user data
        final refreshUseCase = ref.read(refreshCurrentUserUseCaseProvider);
        await refreshUseCase(const NoParams());
      },
    );
  }
}

class _PasswordCard extends ConsumerWidget {
  const _PasswordCard({this.email});
  final String? email;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: const Icon(Icons.lock_outline),
        title: Text(
          'Change Password',
          style: GoogleFonts.nunito(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          'Send a password reset link to your email',
          style: GoogleFonts.nunito(fontSize: 12, color: AppColors.neutralText),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: email == null
            ? null
            : () async {
                final useCase = ref.read(sendPasswordResetEmailUseCaseProvider);
                final result = await useCase(SendPasswordResetEmailParams(email: email!));

                if (!context.mounted) return;

                result.fold(
                  (failure) {
                    showAppSnackBar(context, 'Error: ${failure.message}', type: SnackBarType.error);
                  },
                  (_) {
                    showAppSnackBar(context, 'Password reset link sent to $email', type: SnackBarType.success);
                  },
                );
              },
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
    this.onTap,
  });
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppColors.neutralText),
      title: Text(
        label,
        style: GoogleFonts.nunito(fontSize: 12, color: AppColors.neutralText),
      ),
      subtitle: Text(
        value,
        style: GoogleFonts.nunito(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: AppColors.black,
        ),
      ),
      trailing: onTap != null
          ? Icon(Icons.edit_outlined, size: 18, color: AppColors.neutralText)
          : null,
      onTap: onTap,
    );
  }
}
```

- [ ] **Step 3: Add missing imports**

At the top of `profile_screen.dart`, add these imports if not already present:

```dart
import '../../providers/usecase_providers.dart';
import '../../../domain/usecases/teacher/update_teacher_profile_usecase.dart';
import '../../../domain/usecases/auth/refresh_current_user_usecase.dart';
import '../../../domain/usecases/usecase.dart'; // for NoParams
import '../../../domain/usecases/teacher/send_password_reset_email_usecase.dart';
```

Check existing imports first — some may already be present.

- [ ] **Step 4: Run dart analyze**

Run: `dart analyze lib/presentation/screens/profile/profile_screen.dart`
Expected: No errors.

- [ ] **Step 5: Commit**

```
feat(teacher): implement teacher profile page

Replace empty placeholder with full profile UI:
- Header with initials, name, email, role badge, school name
- Editable first/last name with inline dialog
- Password reset via email link
- Sign out with confirmation

Uses existing profileContextProvider for school name,
sendPasswordResetEmailUseCaseProvider for password reset,
and new updateTeacherProfileUseCaseProvider for name edits.
```

---

## Pre-flight Checklist

Before starting:
- [ ] On `main` branch
- [ ] `dart analyze lib/` has 0 errors
