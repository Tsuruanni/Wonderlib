import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../domain/repositories/student_assignment_repository.dart';
import 'auth_provider.dart';
import 'student_assignment_provider.dart';

/// Information about library book access restrictions
class BookLockInfo {

  const BookLockInfo({
    required this.allowedBookIds,
    this.hasLock = false,
  });
  /// Set of book IDs that student is allowed to access when locked
  final Set<String> allowedBookIds;

  /// Whether the student has any locked assignments
  final bool hasLock;

  static const empty = BookLockInfo(allowedBookIds: {}, hasLock: false);
}

/// Provider that checks if the current user has library lock restrictions
///
/// Teachers are never locked. Students may have locks if they have active
/// book assignments with lockLibrary=true.
final bookLockProvider = FutureProvider<BookLockInfo>((ref) async {
  final user = ref.watch(authStateChangesProvider).valueOrNull;

  // Teachers/admins are never locked
  if (user == null) {
    return BookLockInfo.empty;
  }

  // Check role - only students have library restrictions
  final isTeacherOrAdmin = user.role == UserRole.teacher ||
      user.role == UserRole.head ||
      user.role == UserRole.admin;
  if (isTeacherOrAdmin) {
    return BookLockInfo.empty;
  }

  // Get active assignments
  final assignments = await ref.watch(activeAssignmentsProvider.future);

  final allowedBooks = <String>{};
  bool hasLock = false;

  for (final assignment in assignments) {
    if (assignment.type == StudentAssignmentType.book) {
      // Check if this assignment has library lock enabled
      final lockLibrary = assignment.contentConfig['lockLibrary'];
      if (lockLibrary == true) {
        hasLock = true;
        // Add this book to allowed list
        final bookId = assignment.contentConfig['bookId'] as String?;
        if (bookId != null) {
          allowedBooks.add(bookId);
        }
      }
    }
  }

  return BookLockInfo(
    allowedBookIds: allowedBooks,
    hasLock: hasLock,
  );
});

/// Provider to check if a specific book is accessible
///
/// Returns true if:
/// - User has no lock restrictions, OR
/// - Book is in the allowed list
final canAccessBookProvider = Provider.family<bool, String>((ref, bookId) {
  final lockInfo = ref.watch(bookLockProvider).valueOrNull;

  // No lock info yet or no lock - allow access
  if (lockInfo == null || !lockInfo.hasLock) {
    return true;
  }

  // Check if book is in allowed list
  return lockInfo.allowedBookIds.contains(bookId);
});

/// Provider to check if library is currently locked
final isLibraryLockedProvider = Provider<bool>((ref) {
  final lockInfo = ref.watch(bookLockProvider).valueOrNull;
  return lockInfo?.hasLock ?? false;
});
