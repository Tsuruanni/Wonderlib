import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'auth_provider.dart';

/// True when the current user is a teacher, meaning the reader/quiz/activities
/// should run in "preview mode": correct answers revealed, no progress saved,
/// all access gates bypassed.
///
/// Role-derived rather than flag-driven because teachers never consume book
/// content as learners — if they're in the reader, they're previewing.
final isTeacherPreviewModeProvider = Provider<bool>((ref) {
  return ref.watch(isTeacherProvider);
});
