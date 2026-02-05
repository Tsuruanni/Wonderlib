# Unit Test Plan

## Test Prensipleri

### Checklist (Her Test İçin)
- [ ] Tek bir şey mi test ediliyor?
- [ ] Bağımsız mı? (DB, API yok)
- [ ] İsim net mi? `test_methodName_condition_expectedResult`
- [ ] Hızlı mı? (< 1 saniye)
- [ ] Tekrar edilebilir mi?
- [ ] Edge case'ler dahil mi?

### AAA Pattern
```dart
test('getBooks_whenRepositoryReturnsBooks_shouldReturnBookList', () {
  // Arrange
  final mockRepo = MockBookRepository();
  when(mockRepo.getBooks()).thenAnswer((_) async => Right([testBook]));
  final useCase = GetBooksUseCase(mockRepo);

  // Act
  final result = await useCase(NoParams());

  // Assert
  expect(result.isRight(), true);
  expect(result.getOrElse(() => []).length, 1);
});
```

### İsimlendirme Kuralı
```
methodName_condition_expectedResult

Örnekler:
- fromJson_withValidData_shouldCreateModel
- fromJson_withMissingField_shouldUseDefaultValue
- fromJson_withNullData_shouldThrowException
- call_whenRepositoryFails_shouldReturnFailure
- toEntity_always_shouldMapAllFields
```

---

## Test Yapısı

```
test/
├── unit/
│   ├── data/
│   │   └── models/
│   │       ├── auth/
│   │       │   └── user_model_test.dart
│   │       ├── book/
│   │       │   ├── book_model_test.dart
│   │       │   ├── chapter_model_test.dart
│   │       │   └── reading_progress_model_test.dart
│   │       ├── activity/
│   │       │   ├── activity_model_test.dart
│   │       │   └── activity_result_model_test.dart
│   │       ├── vocabulary/
│   │       │   ├── vocabulary_word_model_test.dart
│   │       │   └── word_list_model_test.dart
│   │       ├── badge/
│   │       │   └── badge_model_test.dart
│   │       ├── user/
│   │       │   └── user_model_test.dart
│   │       ├── teacher/
│   │       │   └── teacher_models_test.dart
│   │       └── assignment/
│   │           └── assignment_models_test.dart
│   │
│   └── domain/
│       └── usecases/
│           ├── auth/
│           │   ├── sign_in_with_email_usecase_test.dart
│           │   └── get_current_user_usecase_test.dart
│           ├── book/
│           │   ├── get_books_usecase_test.dart
│           │   └── get_book_by_id_usecase_test.dart
│           ├── vocabulary/
│           │   ├── search_words_usecase_test.dart
│           │   └── update_word_progress_usecase_test.dart
│           └── ... (diğer usecases)
│
├── integration/
│   └── repositories/
│       └── ... (Supabase mock ile)
│
├── widget/
│   └── ... (widget testleri)
│
├── fixtures/
│   ├── book_fixtures.dart
│   ├── user_fixtures.dart
│   └── ... (test verileri)
│
├── mocks/
│   ├── mock_repositories.dart
│   └── mock_usecases.dart
│
└── helpers/
    └── test_helpers.dart
```

---

## Öncelik Sırası

### Faz 1: Model Tests (En Kolay, Temel)
Toplam: ~21 model = ~21 test dosyası

| Model | Test Senaryoları | Öncelik |
|-------|------------------|---------|
| UserModel | fromJson, toJson, toEntity, fromEntity | P1 |
| BookModel | fromJson, toEntity, edge cases | P1 |
| ChapterModel | fromJson, toEntity | P1 |
| ActivityModel | fromJson, toEntity, content parsing | P1 |
| VocabularyWordModel | fromJson, toEntity | P2 |
| BadgeModel | fromJson, toEntity | P2 |
| AssignmentModel | fromJson, toEntity | P2 |
| ... | ... | P3 |

### Faz 2: UseCase Tests (En Değerli)
Toplam: 81 usecase

**Kritik UseCase'ler (P1):**
- Auth: SignInWithEmail, GetCurrentUser, SignOut
- Book: GetBooks, GetBookById, GetChapters
- Reading: SaveReadingProgress, MarkChapterComplete
- Activity: SubmitActivityResult, GetBestResult
- Vocabulary: SearchWords, UpdateWordProgress

**Orta Öncelik (P2):**
- Badge: AwardBadge, CheckEarnableBadges
- User: AddXP, UpdateStreak
- Teacher: GetClasses, GetClassStudents
- Assignment: CreateAssignment, GetAssignments

### Faz 3: Edge Cases & Error Handling
- Empty lists
- Null values
- Invalid JSON
- Network failures (mock)
- Timeout scenarios

---

## Test Senaryoları

### Model Test Template
```dart
// test/unit/data/models/book/book_model_test.dart

void main() {
  group('BookModel', () {
    group('fromJson', () {
      test('withValidData_shouldCreateModel', () {});
      test('withMissingOptionalField_shouldUseDefault', () {});
      test('withNullRequiredField_shouldThrow', () {});
      test('withInvalidDateFormat_shouldThrow', () {});
    });

    group('toJson', () {
      test('always_shouldIncludeAllFields', () {});
      test('withNullOptionalField_shouldOmitField', () {});
    });

    group('toEntity', () {
      test('always_shouldMapAllFieldsCorrectly', () {});
    });

    group('fromEntity', () {
      test('always_shouldMapAllFieldsCorrectly', () {});
    });
  });
}
```

### UseCase Test Template
```dart
// test/unit/domain/usecases/book/get_books_usecase_test.dart

void main() {
  late GetBooksUseCase useCase;
  late MockBookRepository mockRepository;

  setUp(() {
    mockRepository = MockBookRepository();
    useCase = GetBooksUseCase(mockRepository);
  });

  group('GetBooksUseCase', () {
    test('call_whenRepositorySucceeds_shouldReturnBooks', () async {});
    test('call_whenRepositoryFails_shouldReturnFailure', () async {});
    test('call_whenRepositoryReturnsEmpty_shouldReturnEmptyList', () async {});
  });
}
```

---

## Mock Stratejisi

### Repository Mocks (Mockito)
```dart
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
```

### Test Fixtures
```dart
// test/fixtures/book_fixtures.dart
class BookFixtures {
  static Map<String, dynamic> validBookJson() => {
    'id': 'book-1',
    'title': 'Test Book',
    'author': 'Test Author',
    // ...
  };

  static Map<String, dynamic> minimalBookJson() => {
    'id': 'book-1',
    'title': 'Test Book',
  };

  static Book testBook() => Book(
    id: 'book-1',
    title: 'Test Book',
    // ...
  );
}
```

---

## Coverage Hedefi

| Katman | Hedef Coverage |
|--------|---------------|
| Models | 90%+ |
| UseCases | 85%+ |
| Repositories | 70%+ (integration) |
| Providers | 60%+ |
| Widgets | 50%+ |

---

## Komutlar

```bash
# Tüm testleri çalıştır
flutter test

# Belirli klasör
flutter test test/unit/

# Coverage ile
flutter test --coverage

# Coverage raporu
genhtml coverage/lcov.info -o coverage/html
open coverage/html/index.html
```
