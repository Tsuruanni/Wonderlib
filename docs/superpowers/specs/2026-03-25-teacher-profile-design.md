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
- School name (smaller, with school icon)

### 2. Personal Information Card

A `Card` with list tiles:

| Field | Value Source | Editable? | Edit UX |
|-------|-------------|-----------|---------|
| First Name | `user.firstName` | Yes | Tap → inline edit dialog |
| Last Name | `user.lastName` | Yes | Tap → inline edit dialog |
| Email | `user.email` | No (read-only) | Shown greyed out |
| School | school name from `classes` or profile | No (read-only) | Shown greyed out |

**Edit flow:** Tap on editable field → `showDialog` with `TextField` pre-filled → Save → `UPDATE profiles SET first_name/last_name` → invalidate `authStateChangesProvider` to refresh.

### 3. Password Change Section

A `Card` with single list tile:
- "Change Password" with lock icon
- Tap → calls `supabase.auth.resetPasswordForEmail(user.email)`
- Shows success SnackBar: "Password reset link sent to your email"

### 4. Sign Out Button

- Full-width outlined button, red color
- Tap → confirmation dialog → `signOut()`
- Navigates to login screen

## Data Flow

**Read:** `authStateChangesProvider` → `User` entity (already has firstName, lastName, email, role, schoolId)

**Write (name edit):** Direct `profiles` table UPDATE via new usecase:
- `UpdateTeacherProfileUseCase` → `TeacherRepository.updateProfile(firstName, lastName)`
- After success: call `authRepository.refreshCurrentUser()` to update the stream

**Write (password):** `AuthRepository.sendPasswordResetEmail(email)` — already exists.

**Sign out:** `AuthRepository.signOut()` — already exists.

## New Components Needed

### Domain Layer
- `UpdateTeacherProfileUseCase` — calls `TeacherRepository.updateProfile`
- Add `updateProfile` method to `TeacherRepository` interface

### Data Layer
- `SupabaseTeacherRepository.updateProfile` — `UPDATE profiles SET first_name, last_name WHERE id = auth.uid()`
- This uses existing RLS (`"Users can update own profile"` policy: `id = auth.uid()`)

### Provider Layer
- `updateTeacherProfileUseCaseProvider` in `usecase_providers.dart`
- No new feature provider needed — `authStateChangesProvider` already provides the User

### Presentation Layer
- Replace `_buildTeacherFallback()` in `profile_screen.dart` with full teacher profile UI
- All in the existing `profile_screen.dart` file — no new screen file needed

## School Name Resolution

The `User` entity has `schoolId` (UUID) but no school name. Options:
1. Add a simple RPC or direct query to get school name
2. Store school name in `profiles.settings` JSONB at signup time

Simplest: direct `schools` table query. RLS allows `"Users can view their own school"`.

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
