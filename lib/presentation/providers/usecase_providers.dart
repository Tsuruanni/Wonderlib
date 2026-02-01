import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/usecases/assignment/create_assignment_usecase.dart';
import '../../domain/usecases/auth/get_current_user_usecase.dart';
import '../../domain/usecases/auth/sign_in_with_email_usecase.dart';
import '../../domain/usecases/auth/sign_in_with_student_number_usecase.dart';
import '../../domain/usecases/auth/sign_out_usecase.dart';
import '../../domain/usecases/reading/save_reading_progress_usecase.dart';
import '../../domain/usecases/teacher/change_student_class_usecase.dart';
import '../../domain/usecases/teacher/reset_student_password_usecase.dart';
import 'repository_providers.dart';

// ============================================
// AUTH USE CASES
// ============================================

final signInWithEmailUseCaseProvider = Provider((ref) {
  return SignInWithEmailUseCase(ref.watch(authRepositoryProvider));
});

final signInWithStudentNumberUseCaseProvider = Provider((ref) {
  return SignInWithStudentNumberUseCase(ref.watch(authRepositoryProvider));
});

final signOutUseCaseProvider = Provider((ref) {
  return SignOutUseCase(ref.watch(authRepositoryProvider));
});

final getCurrentUserUseCaseProvider = Provider((ref) {
  return GetCurrentUserUseCase(ref.watch(authRepositoryProvider));
});

// ============================================
// TEACHER USE CASES
// ============================================

final resetStudentPasswordUseCaseProvider = Provider((ref) {
  return ResetStudentPasswordUseCase(ref.watch(teacherRepositoryProvider));
});

final changeStudentClassUseCaseProvider = Provider((ref) {
  return ChangeStudentClassUseCase(ref.watch(teacherRepositoryProvider));
});

// ============================================
// ASSIGNMENT USE CASES
// ============================================

final createAssignmentUseCaseProvider = Provider((ref) {
  return CreateAssignmentUseCase(ref.watch(teacherRepositoryProvider));
});

// ============================================
// READING USE CASES
// ============================================

final saveReadingProgressUseCaseProvider = Provider((ref) {
  return SaveReadingProgressUseCase(ref.watch(bookRepositoryProvider));
});
