import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:readeng/core/errors/failures.dart';
import 'package:readeng/domain/entities/book.dart';
import 'package:readeng/domain/usecases/book/get_books_usecase.dart';
import 'package:readeng/domain/usecases/book/get_book_by_id_usecase.dart';
import 'package:readeng/domain/usecases/book/search_books_usecase.dart';

import '../../../../fixtures/book_fixtures.dart';
import '../../../../mocks/mock_repositories.mocks.dart';

void main() {
  late MockBookRepository mockBookRepository;

  setUp(() {
    mockBookRepository = MockBookRepository();
  });

  // ============================================
  // GetBooksUseCase Tests
  // ============================================
  group('GetBooksUseCase', () {
    late GetBooksUseCase usecase;

    setUp(() {
      usecase = GetBooksUseCase(mockBookRepository);
    });

    test('withDefaultParams_shouldReturnBooks', () async {
      // Arrange
      final books = BookFixtures.bookList();
      when(mockBookRepository.getBooks(
        level: null,
        genre: null,
        ageGroup: null,
        page: 1,
        pageSize: 20,
      )).thenAnswer((_) async => Right(books));

      const params = GetBooksParams();

      // Act
      final result = await usecase(params);

      // Assert
      expect(result.isRight(), true);
      result.fold(
        (failure) => fail('Should not return failure'),
        (returnedBooks) {
          expect(returnedBooks.length, books.length);
          expect(returnedBooks[0].id, books[0].id);
        },
      );
      verify(mockBookRepository.getBooks(
        level: null,
        genre: null,
        ageGroup: null,
        page: 1,
        pageSize: 20,
      )).called(1);
    });

    test('withLevelFilter_shouldPassToRepository', () async {
      // Arrange
      final books = [BookFixtures.validBook()];
      when(mockBookRepository.getBooks(
        level: 'B1',
        genre: null,
        ageGroup: null,
        page: 1,
        pageSize: 20,
      )).thenAnswer((_) async => Right(books));

      const params = GetBooksParams(level: 'B1');

      // Act
      final result = await usecase(params);

      // Assert
      expect(result.isRight(), true);
      verify(mockBookRepository.getBooks(
        level: 'B1',
        genre: null,
        ageGroup: null,
        page: 1,
        pageSize: 20,
      )).called(1);
    });

    test('withAllFilters_shouldPassToRepository', () async {
      // Arrange
      final books = <Book>[];
      when(mockBookRepository.getBooks(
        level: 'B1',
        genre: 'adventure',
        ageGroup: '12-15',
        page: 2,
        pageSize: 10,
      )).thenAnswer((_) async => Right(books));

      const params = GetBooksParams(
        level: 'B1',
        genre: 'adventure',
        ageGroup: '12-15',
        page: 2,
        pageSize: 10,
      );

      // Act
      final result = await usecase(params);

      // Assert
      expect(result.isRight(), true);
      result.fold(
        (failure) => fail('Should not return failure'),
        (returnedBooks) => expect(returnedBooks, isEmpty),
      );
    });

    test('withServerError_shouldReturnServerFailure', () async {
      // Arrange
      when(mockBookRepository.getBooks(
        level: null,
        genre: null,
        ageGroup: null,
        page: 1,
        pageSize: 20,
      )).thenAnswer((_) async => const Left(ServerFailure('Database error')));

      const params = GetBooksParams();

      // Act
      final result = await usecase(params);

      // Assert
      expect(result.isLeft(), true);
      result.fold(
        (failure) => expect(failure, isA<ServerFailure>()),
        (books) => fail('Should not return books'),
      );
    });

    test('withNetworkError_shouldReturnNetworkFailure', () async {
      // Arrange
      when(mockBookRepository.getBooks(
        level: null,
        genre: null,
        ageGroup: null,
        page: 1,
        pageSize: 20,
      )).thenAnswer((_) async => const Left(NetworkFailure()));

      const params = GetBooksParams();

      // Act
      final result = await usecase(params);

      // Assert
      expect(result.isLeft(), true);
      result.fold(
        (failure) => expect(failure, isA<NetworkFailure>()),
        (books) => fail('Should not return books'),
      );
    });

    test('params_shouldHaveCorrectDefaults', () {
      // Arrange & Act
      const params = GetBooksParams();

      // Assert
      expect(params.level, isNull);
      expect(params.genre, isNull);
      expect(params.ageGroup, isNull);
      expect(params.page, 1);
      expect(params.pageSize, 20);
    });
  });

  // ============================================
  // GetBookByIdUseCase Tests
  // ============================================
  group('GetBookByIdUseCase', () {
    late GetBookByIdUseCase usecase;

    setUp(() {
      usecase = GetBookByIdUseCase(mockBookRepository);
    });

    test('withValidId_shouldReturnBook', () async {
      // Arrange
      final book = BookFixtures.validBook();
      when(mockBookRepository.getBookById('book-123'))
          .thenAnswer((_) async => Right(book));

      const params = GetBookByIdParams(bookId: 'book-123');

      // Act
      final result = await usecase(params);

      // Assert
      expect(result.isRight(), true);
      result.fold(
        (failure) => fail('Should not return failure'),
        (returnedBook) {
          expect(returnedBook.id, 'book-123');
          expect(returnedBook.title, 'The Great Adventure');
        },
      );
      verify(mockBookRepository.getBookById('book-123')).called(1);
    });

    test('withNonExistentId_shouldReturnNotFoundFailure', () async {
      // Arrange
      when(mockBookRepository.getBookById('non-existent'))
          .thenAnswer((_) async => const Left(NotFoundFailure('Book not found')));

      const params = GetBookByIdParams(bookId: 'non-existent');

      // Act
      final result = await usecase(params);

      // Assert
      expect(result.isLeft(), true);
      result.fold(
        (failure) {
          expect(failure, isA<NotFoundFailure>());
          expect(failure.message, 'Book not found');
        },
        (book) => fail('Should not return book'),
      );
    });

    test('withServerError_shouldReturnServerFailure', () async {
      // Arrange
      when(mockBookRepository.getBookById('book-123'))
          .thenAnswer((_) async => const Left(ServerFailure('Database error')));

      const params = GetBookByIdParams(bookId: 'book-123');

      // Act
      final result = await usecase(params);

      // Assert
      expect(result.isLeft(), true);
      result.fold(
        (failure) => expect(failure, isA<ServerFailure>()),
        (book) => fail('Should not return book'),
      );
    });

    test('params_shouldStoreBookId', () {
      // Arrange & Act
      const params = GetBookByIdParams(bookId: 'test-book-id');

      // Assert
      expect(params.bookId, 'test-book-id');
    });
  });

  // ============================================
  // SearchBooksUseCase Tests
  // ============================================
  group('SearchBooksUseCase', () {
    late SearchBooksUseCase usecase;

    setUp(() {
      usecase = SearchBooksUseCase(mockBookRepository);
    });

    test('withValidQuery_shouldReturnMatchingBooks', () async {
      // Arrange
      final books = [BookFixtures.validBook()];
      when(mockBookRepository.searchBooks('adventure'))
          .thenAnswer((_) async => Right(books));

      const params = SearchBooksParams(query: 'adventure');

      // Act
      final result = await usecase(params);

      // Assert
      expect(result.isRight(), true);
      result.fold(
        (failure) => fail('Should not return failure'),
        (returnedBooks) {
          expect(returnedBooks.length, 1);
          expect(returnedBooks[0].title, 'The Great Adventure');
        },
      );
      verify(mockBookRepository.searchBooks('adventure')).called(1);
    });

    test('withNoMatches_shouldReturnEmptyList', () async {
      // Arrange
      when(mockBookRepository.searchBooks('nonexistent'))
          .thenAnswer((_) async => const Right(<Book>[]));

      const params = SearchBooksParams(query: 'nonexistent');

      // Act
      final result = await usecase(params);

      // Assert
      expect(result.isRight(), true);
      result.fold(
        (failure) => fail('Should not return failure'),
        (returnedBooks) => expect(returnedBooks, isEmpty),
      );
    });

    test('withEmptyQuery_shouldCallRepository', () async {
      // Arrange
      when(mockBookRepository.searchBooks(''))
          .thenAnswer((_) async => const Right(<Book>[]));

      const params = SearchBooksParams(query: '');

      // Act
      final result = await usecase(params);

      // Assert
      expect(result.isRight(), true);
      verify(mockBookRepository.searchBooks('')).called(1);
    });

    test('withServerError_shouldReturnServerFailure', () async {
      // Arrange
      when(mockBookRepository.searchBooks('test'))
          .thenAnswer((_) async => const Left(ServerFailure('Search failed')));

      const params = SearchBooksParams(query: 'test');

      // Act
      final result = await usecase(params);

      // Assert
      expect(result.isLeft(), true);
      result.fold(
        (failure) => expect(failure, isA<ServerFailure>()),
        (books) => fail('Should not return books'),
      );
    });

    test('withSpecialCharacters_shouldPassToRepository', () async {
      // Arrange
      const query = "Book's \"Title\" - Vol. 1";
      when(mockBookRepository.searchBooks(query))
          .thenAnswer((_) async => const Right(<Book>[]));

      final params = SearchBooksParams(query: query);

      // Act
      await usecase(params);

      // Assert
      verify(mockBookRepository.searchBooks(query)).called(1);
    });

    test('params_shouldStoreQuery', () {
      // Arrange & Act
      const params = SearchBooksParams(query: 'test search');

      // Assert
      expect(params.query, 'test search');
    });
  });

  // ============================================
  // Edge Cases
  // ============================================
  group('edgeCases', () {
    test('getBooksWithLargePage_shouldPassToRepository', () async {
      // Arrange
      final usecase = GetBooksUseCase(mockBookRepository);
      when(mockBookRepository.getBooks(
        level: null,
        genre: null,
        ageGroup: null,
        page: 100,
        pageSize: 50,
      )).thenAnswer((_) async => const Right(<Book>[]));

      const params = GetBooksParams(page: 100, pageSize: 50);

      // Act
      final result = await usecase(params);

      // Assert
      expect(result.isRight(), true);
    });

    test('getBookWithUuidId_shouldWork', () async {
      // Arrange
      final usecase = GetBookByIdUseCase(mockBookRepository);
      const uuid = '550e8400-e29b-41d4-a716-446655440000';
      final book = BookFixtures.validBook();
      when(mockBookRepository.getBookById(uuid))
          .thenAnswer((_) async => Right(book));

      const params = GetBookByIdParams(bookId: uuid);

      // Act
      final result = await usecase(params);

      // Assert
      expect(result.isRight(), true);
    });

    test('searchWithUnicodeCharacters_shouldWork', () async {
      // Arrange
      final usecase = SearchBooksUseCase(mockBookRepository);
      const query = '日本語 タイトル';
      when(mockBookRepository.searchBooks(query))
          .thenAnswer((_) async => const Right(<Book>[]));

      final params = SearchBooksParams(query: query);

      // Act
      final result = await usecase(params);

      // Assert
      expect(result.isRight(), true);
      verify(mockBookRepository.searchBooks(query)).called(1);
    });
  });

  // ============================================
  // Multiple Calls Tests
  // ============================================
  group('multipleCalls', () {
    test('getBooks_calledMultipleTimes_shouldCallRepositoryEachTime', () async {
      // Arrange
      final usecase = GetBooksUseCase(mockBookRepository);
      when(mockBookRepository.getBooks(
        level: null,
        genre: null,
        ageGroup: null,
        page: 1,
        pageSize: 20,
      )).thenAnswer((_) async => const Right(<Book>[]));

      // Act
      await usecase(const GetBooksParams());
      await usecase(const GetBooksParams());
      await usecase(const GetBooksParams());

      // Assert
      verify(mockBookRepository.getBooks(
        level: null,
        genre: null,
        ageGroup: null,
        page: 1,
        pageSize: 20,
      )).called(3);
    });

    test('differentUseCases_shouldWorkIndependently', () async {
      // Arrange
      final getBooksUseCase = GetBooksUseCase(mockBookRepository);
      final getBookByIdUseCase = GetBookByIdUseCase(mockBookRepository);
      final searchBooksUseCase = SearchBooksUseCase(mockBookRepository);

      final books = BookFixtures.bookList();
      final book = BookFixtures.validBook();

      when(mockBookRepository.getBooks(
        level: null,
        genre: null,
        ageGroup: null,
        page: 1,
        pageSize: 20,
      )).thenAnswer((_) async => Right(books));
      when(mockBookRepository.getBookById('book-123'))
          .thenAnswer((_) async => Right(book));
      when(mockBookRepository.searchBooks('test'))
          .thenAnswer((_) async => Right(books));

      // Act
      final result1 = await getBooksUseCase(const GetBooksParams());
      final result2 = await getBookByIdUseCase(const GetBookByIdParams(bookId: 'book-123'));
      final result3 = await searchBooksUseCase(const SearchBooksParams(query: 'test'));

      // Assert
      expect(result1.isRight(), true);
      expect(result2.isRight(), true);
      expect(result3.isRight(), true);
    });
  });
}
