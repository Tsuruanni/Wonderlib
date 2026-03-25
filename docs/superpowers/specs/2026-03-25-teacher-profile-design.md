# Teacher Profile Page — Design Spec

## Goal

Replace the empty "Teacher Profile" placeholder with a functional profile management page where teachers can view/edit their personal info, change password, and sign out.

## Scope

- Profile viewing and editing (name only — email and school are read-only)
- Password reset via email
- Sign out
- No avatar, no preferences/settings, no stats/dashboard duplication

## User Roles Affected

`teacher`, `head`, `admin` — all see the same profile page. Role is displayed as a badge but doesn't change functionality.

## Screen Layout

Single `Scaffold` with `SingleChildScrollView`:

### 1. Header Section

- Large circle with user initials (first letter of firstName + lastName), colored background based on role
- Full name (large, bold)
- Email (smaller, grey)
- Role badge chip: "Teacher" / "Head Teacher" / "Admin"
- School name (smaller, with school icon) — resolved via existing `profileContextProvider`

### 2. Personal Information Card

A `Card` with list tiles:

| Field | Value Source | Editable? | Edit UX |
|-------|-------------|-----------|---------|
| First Name | `user.firstName` | Yes | Tap → inline edit dialog |
| Last Name | `user.lastName` | Yes | Tap → inline edit dialog |
| Email | `user.email` | No (read-only) | Shown greyed out |
| School | `profileContextProvider` school name | No (read-only) | Shown greyed out |

**Edit flow:** Tap on editable field → `showDialog` with `AlertDialog` + `TextFormField` pre-filled (same pattern as `_showCreateClassDialog`) → Save via `updateTeacherProfileUseCaseProvider` → call `refreshCurrentUser()` to update auth stream.

### 3. Password Change Section

A `Card` with single list tile:
- "Change Password" with lock icon
- Tap → calls `sendPasswordResetEmailUseCaseProvider` (existing — lives on `TeacherRepository`, NOT `AuthRepository`)
- Shows success SnackBar: "Password reset link sent to your email"

### 4. Sign Out Button

- Full-width outlined button, red color
- Tap → confirmation dialog → `authControllerProvider.notifier.signOut()` (existing pattern from current fallback)
- Navigates to login screen

## Data Flow

**Read:** `userControllerProvider` → `User` entity (consistent with student profile, already watched at line 32 of `profile_screen.dart`). School name via `profileContextProvider` (already used by student profile).

**Write (name edit):** New usecase chain:
- `UpdateTeacherProfileUseCase` → `TeacherRepository.updateProfile(firstName, lastName)`
- After success: call `RefreshCurrentUserUseCase` to update the auth stream
- Note: `RefreshCurrentUserUseCase` class exists but provider is NOT registered — must be added

**Write (password):** `sendPasswordResetEmailUseCaseProvider` → `TeacherRepository.sendPasswordResetEmail(email)` — already exists with full usecase + provider chain.

**Sign out:** `authControllerProvider.notifier.signOut()` — already exists.

## New Components Needed

### Domain Layer
- `UpdateTeacherProfileUseCase` — calls `TeacherRepository.updateProfile`
- Add `updateProfile(String firstName, String lastName)` method to `TeacherRepository` interface

### Data Layer
- `SupabaseTeacherRepository.updateProfile` — `UPDATE profiles SET first_name, last_name WHERE id = auth.uid()`
- This uses existing RLS (`"Users can update own profile"` policy: `id = auth.uid()`)

### Provider Layer
- `updateTeacherProfileUseCaseProvider` in `usecase_providers.dart`
- `refreshCurrentUserUseCaseProvider` in `usecase_providers.dart` (class exists at `lib/domain/usecases/auth/refresh_current_user_usecase.dart` but provider is not registered)

### Presentation Layer
- Replace `_buildTeacherFallback()` (lines 65-103 of `profile_screen.dart`) with full teacher profile UI
- All in the existing `profile_screen.dart` file — no new screen file needed

## School Name Resolution

Reuse existing `profileContextProvider` which already resolves school name and class name from UUIDs. The student profile already uses it (line 159 of profile_screen.dart). No new query needed.

## Role Display Mapping

| `UserRole` | Display Text | Badge Color |
|------------|-------------|-------------|
| `teacher` | "Teacher" | Blue |
| `head` | "Head Teacher" | Purple |
| `admin` | "Admin" | Amber |

## Error Handling

- Name update failure → SnackBar error
- Password reset failure → SnackBar error
- Network error on load → `ErrorStateWidget` with retry

## Out of Scope

- Avatar upload
- Email change (requires Supabase auth flow)
- Theme/language preferences
- Stats or dashboard metrics on profile
- Different UI per role
