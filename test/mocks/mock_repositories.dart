import 'package:mockito/annotations.dart';
import 'package:readeng/domain/repositories/auth_repository.dart';
import 'package:readeng/domain/repositories/book_repository.dart';
import 'package:readeng/domain/repositories/user_repository.dart';
import 'package:readeng/domain/repositories/vocabulary_repository.dart';
import 'package:readeng/domain/repositories/activity_repository.dart';
import 'package:readeng/domain/repositories/badge_repository.dart';
import 'package:readeng/domain/repositories/word_list_repository.dart';
import 'package:readeng/domain/repositories/teacher_repository.dart';
import 'package:readeng/domain/repositories/student_assignment_repository.dart';

/// Generate mocks for all repositories
/// Run: dart run build_runner build
@GenerateMocks([
  AuthRepository,
  BookRepository,
  UserRepository,
  VocabularyRepository,
  ActivityRepository,
  BadgeRepository,
  WordListRepository,
  TeacherRepository,
  StudentAssignmentRepository,
])
void main() {}
