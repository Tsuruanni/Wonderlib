import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:readeng/core/errors/failures.dart';
import 'package:readeng/domain/entities/activity.dart';
import 'package:readeng/domain/usecases/activity/get_activities_by_chapter_usecase.dart';
import 'package:readeng/domain/usecases/activity/submit_activity_result_usecase.dart';
import 'package:readeng/domain/usecases/activity/get_user_activity_results_usecase.dart';

import '../../../../fixtures/activity_fixtures.dart';
import '../../../../mocks/mock_repositories.mocks.dart';

void main() {
  late MockActivityRepository mockActivityRepository;

  setUp(() {
    mockActivityRepository = MockActivityRepository();
  });

  // ============================================
  // GetActivitiesByChapterUseCase Tests
  // ============================================
  group('GetActivitiesByChapterUseCase', () {
    late GetActivitiesByChapterUseCase usecase;

    setUp(() {
      usecase = GetActivitiesByChapterUseCase(mockActivityRepository);
    });

    test('withValidChapterId_shouldReturnActivities', () async {
      // Arrange
      final activities = [ActivityFixtures.validActivity()];
      when(mockActivityRepository.getActivitiesByChapter('chapter-1'))
          .thenAnswer((_) async => Right(activities));

      const params = GetActivitiesByChapterParams(chapterId: 'chapter-1');

      // Act
      final result = await usecase(params);

      // Assert
      expect(result.isRight(), true);
      result.fold(
        (failure) => fail('Should not return failure'),
        (returnedActivities) {
          expect(returnedActivities.length, 1);
          expect(returnedActivities[0].chapterId, 'chapter-1');
          expect(returnedActivities[0].type, ActivityType.multipleChoice);
        },
      );
      verify(mockActivityRepository.getActivitiesByChapter('chapter-1')).called(1);
    });

    test('withNoActivities_shouldReturnEmptyList', () async {
      // Arrange
      when(mockActivityRepository.getActivitiesByChapter('chapter-empty'))
          .thenAnswer((_) async => const Right(<Activity>[]));

      const params = GetActivitiesByChapterParams(chapterId: 'chapter-empty');

      // Act
      final result = await usecase(params);

      // Assert
      expect(result.isRight(), true);
      result.fold(
        (failure) => fail('Should not return failure'),
        (returnedActivities) => expect(returnedActivities, isEmpty),
      );
    });

    test('withMultipleActivities_shouldReturnAll', () async {
      // Arrange
      final activities = [
        ActivityFixtures.validActivity(),
        Activity(
          id: 'activity-2',
          chapterId: 'chapter-1',
          type: ActivityType.trueFalse,
          orderIndex: 2,
          questions: const [],
          settings: const <String, dynamic>{},
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ];
      when(mockActivityRepository.getActivitiesByChapter('chapter-1'))
          .thenAnswer((_) async => Right(activities));

      const params = GetActivitiesByChapterParams(chapterId: 'chapter-1');

      // Act
      final result = await usecase(params);

      // Assert
      expect(result.isRight(), true);
      result.fold(
        (failure) => fail('Should not return failure'),
        (returnedActivities) {
          expect(returnedActivities.length, 2);
          expect(returnedActivities[0].type, ActivityType.multipleChoice);
          expect(returnedActivities[1].type, ActivityType.trueFalse);
        },
      );
    });

    test('withNotFoundChapter_shouldReturnNotFoundFailure', () async {
      // Arrange
      when(mockActivityRepository.getActivitiesByChapter('nonexistent'))
          .thenAnswer((_) async => const Left(NotFoundFailure('Chapter not found')));

      const params = GetActivitiesByChapterParams(chapterId: 'nonexistent');

      // Act
      final result = await usecase(params);

      // Assert
      expect(result.isLeft(), true);
      result.fold(
        (failure) => expect(failure, isA<NotFoundFailure>()),
        (activities) => fail('Should not return activities'),
      );
    });

    test('withServerError_shouldReturnServerFailure', () async {
      // Arrange
      when(mockActivityRepository.getActivitiesByChapter('chapter-1'))
          .thenAnswer((_) async => const Left(ServerFailure('Database error')));

      const params = GetActivitiesByChapterParams(chapterId: 'chapter-1');

      // Act
      final result = await usecase(params);

      // Assert
      expect(result.isLeft(), true);
      result.fold(
        (failure) => expect(failure, isA<ServerFailure>()),
        (activities) => fail('Should not return activities'),
      );
    });

    test('params_shouldStoreChapterId', () {
      // Arrange & Act
      const params = GetActivitiesByChapterParams(chapterId: 'test-chapter');

      // Assert
      expect(params.chapterId, 'test-chapter');
    });
  });

  // ============================================
  // SubmitActivityResultUseCase Tests
  // ============================================
  group('SubmitActivityResultUseCase', () {
    late SubmitActivityResultUseCase usecase;

    setUp(() {
      usecase = SubmitActivityResultUseCase(mockActivityRepository);
    });

    test('withValidResult_shouldReturnSavedResult', () async {
      // Arrange
      final result = ActivityResultFixtures.validResult();
      when(mockActivityRepository.submitActivityResult(result))
          .thenAnswer((_) async => Right(result));

      final params = SubmitActivityResultParams(result: result);

      // Act
      final response = await usecase(params);

      // Assert
      expect(response.isRight(), true);
      response.fold(
        (failure) => fail('Should not return failure'),
        (returnedResult) {
          expect(returnedResult.id, result.id);
          expect(returnedResult.score, 80.0);
          expect(returnedResult.maxScore, 100.0);
        },
      );
      verify(mockActivityRepository.submitActivityResult(result)).called(1);
    });

    test('withPerfectScore_shouldReturnResult', () async {
      // Arrange
      final result = ActivityResult(
        id: 'result-perfect',
        userId: 'user-123',
        activityId: 'activity-123',
        score: 100.0,
        maxScore: 100.0,
        answers: const {'q-1': 'correct', 'q-2': 'correct'},
        timeSpent: 60,
        attemptNumber: 1,
        completedAt: DateTime.now(),
      );
      when(mockActivityRepository.submitActivityResult(result))
          .thenAnswer((_) async => Right(result));

      final params = SubmitActivityResultParams(result: result);

      // Act
      final response = await usecase(params);

      // Assert
      expect(response.isRight(), true);
      response.fold(
        (failure) => fail('Should not return failure'),
        (returnedResult) {
          expect(returnedResult.score, 100.0);
          expect(returnedResult.score / returnedResult.maxScore, 1.0);
        },
      );
    });

    test('withZeroScore_shouldReturnResult', () async {
      // Arrange
      final result = ActivityResult(
        id: 'result-zero',
        userId: 'user-123',
        activityId: 'activity-123',
        score: 0.0,
        maxScore: 100.0,
        answers: const <String, dynamic>{},
        timeSpent: 300,
        attemptNumber: 1,
        completedAt: DateTime.now(),
      );
      when(mockActivityRepository.submitActivityResult(result))
          .thenAnswer((_) async => Right(result));

      final params = SubmitActivityResultParams(result: result);

      // Act
      final response = await usecase(params);

      // Assert
      expect(response.isRight(), true);
      response.fold(
        (failure) => fail('Should not return failure'),
        (returnedResult) {
          expect(returnedResult.score, 0.0);
        },
      );
    });

    test('withServerError_shouldReturnServerFailure', () async {
      // Arrange
      final result = ActivityResultFixtures.validResult();
      when(mockActivityRepository.submitActivityResult(result))
          .thenAnswer((_) async => const Left(ServerFailure('Save failed')));

      final params = SubmitActivityResultParams(result: result);

      // Act
      final response = await usecase(params);

      // Assert
      expect(response.isLeft(), true);
      response.fold(
        (failure) => expect(failure, isA<ServerFailure>()),
        (result) => fail('Should not return result'),
      );
    });

    test('withNetworkError_shouldReturnNetworkFailure', () async {
      // Arrange
      final result = ActivityResultFixtures.validResult();
      when(mockActivityRepository.submitActivityResult(result))
          .thenAnswer((_) async => const Left(NetworkFailure()));

      final params = SubmitActivityResultParams(result: result);

      // Act
      final response = await usecase(params);

      // Assert
      expect(response.isLeft(), true);
      response.fold(
        (failure) => expect(failure, isA<NetworkFailure>()),
        (result) => fail('Should not return result'),
      );
    });

    test('params_shouldStoreResult', () {
      // Arrange
      final result = ActivityResultFixtures.validResult();

      // Act
      final params = SubmitActivityResultParams(result: result);

      // Assert
      expect(params.result, result);
      expect(params.result.id, 'result-123');
    });
  });

  // ============================================
  // GetUserActivityResultsUseCase Tests
  // ============================================
  group('GetUserActivityResultsUseCase', () {
    late GetUserActivityResultsUseCase usecase;

    setUp(() {
      usecase = GetUserActivityResultsUseCase(mockActivityRepository);
    });

    test('withUserIdOnly_shouldReturnAllUserResults', () async {
      // Arrange
      final results = [
        ActivityResult(
          id: 'result-123',
          userId: 'user-123',
          activityId: 'activity-789',
          score: 80.0,
          maxScore: 100.0,
          answers: const {'q-1': 'Paris'},
          attemptNumber: 1,
          completedAt: DateTime.parse('2024-01-15T10:30:00Z'),
        ),
      ];
      when(mockActivityRepository.getUserActivityResults(
        userId: 'user-123',
        activityId: null,
      )).thenAnswer((_) async => Right(results));

      const params = GetUserActivityResultsParams(userId: 'user-123');

      // Act
      final result = await usecase(params);

      // Assert
      expect(result.isRight(), true);
      result.fold(
        (failure) => fail('Should not return failure'),
        (returnedResults) {
          expect(returnedResults.length, 1);
          expect(returnedResults[0].userId, 'user-123');
        },
      );
      verify(mockActivityRepository.getUserActivityResults(
        userId: 'user-123',
        activityId: null,
      )).called(1);
    });

    test('withUserIdAndActivityId_shouldReturnFilteredResults', () async {
      // Arrange
      final results = [ActivityResultFixtures.validResult()];
      when(mockActivityRepository.getUserActivityResults(
        userId: 'user-123',
        activityId: 'activity-789',
      )).thenAnswer((_) async => Right(results));

      const params = GetUserActivityResultsParams(
        userId: 'user-123',
        activityId: 'activity-789',
      );

      // Act
      final result = await usecase(params);

      // Assert
      expect(result.isRight(), true);
      result.fold(
        (failure) => fail('Should not return failure'),
        (returnedResults) {
          expect(returnedResults.length, 1);
          expect(returnedResults[0].activityId, 'activity-789');
        },
      );
    });

    test('withNoResults_shouldReturnEmptyList', () async {
      // Arrange
      when(mockActivityRepository.getUserActivityResults(
        userId: 'new-user',
        activityId: null,
      )).thenAnswer((_) async => const Right(<ActivityResult>[]));

      const params = GetUserActivityResultsParams(userId: 'new-user');

      // Act
      final result = await usecase(params);

      // Assert
      expect(result.isRight(), true);
      result.fold(
        (failure) => fail('Should not return failure'),
        (returnedResults) => expect(returnedResults, isEmpty),
      );
    });

    test('withMultipleAttempts_shouldReturnAllAttempts', () async {
      // Arrange
      final results = [
        ActivityResult(
          id: 'result-1',
          userId: 'user-123',
          activityId: 'activity-123',
          score: 60.0,
          maxScore: 100.0,
          answers: const <String, dynamic>{},
          attemptNumber: 1,
          completedAt: DateTime.parse('2024-01-01T10:00:00Z'),
        ),
        ActivityResult(
          id: 'result-2',
          userId: 'user-123',
          activityId: 'activity-123',
          score: 80.0,
          maxScore: 100.0,
          answers: const <String, dynamic>{},
          attemptNumber: 2,
          completedAt: DateTime.parse('2024-01-01T11:00:00Z'),
        ),
        ActivityResult(
          id: 'result-3',
          userId: 'user-123',
          activityId: 'activity-123',
          score: 100.0,
          maxScore: 100.0,
          answers: const <String, dynamic>{},
          attemptNumber: 3,
          completedAt: DateTime.parse('2024-01-01T12:00:00Z'),
        ),
      ];
      when(mockActivityRepository.getUserActivityResults(
        userId: 'user-123',
        activityId: 'activity-123',
      )).thenAnswer((_) async => Right(results));

      const params = GetUserActivityResultsParams(
        userId: 'user-123',
        activityId: 'activity-123',
      );

      // Act
      final result = await usecase(params);

      // Assert
      expect(result.isRight(), true);
      result.fold(
        (failure) => fail('Should not return failure'),
        (returnedResults) {
          expect(returnedResults.length, 3);
          expect(returnedResults[0].attemptNumber, 1);
          expect(returnedResults[1].attemptNumber, 2);
          expect(returnedResults[2].attemptNumber, 3);
          // Verify improvement over attempts
          expect(returnedResults[2].score, greaterThan(returnedResults[0].score));
        },
      );
    });

    test('withServerError_shouldReturnServerFailure', () async {
      // Arrange
      when(mockActivityRepository.getUserActivityResults(
        userId: 'user-123',
        activityId: null,
      )).thenAnswer((_) async => const Left(ServerFailure('Database error')));

      const params = GetUserActivityResultsParams(userId: 'user-123');

      // Act
      final result = await usecase(params);

      // Assert
      expect(result.isLeft(), true);
      result.fold(
        (failure) => expect(failure, isA<ServerFailure>()),
        (results) => fail('Should not return results'),
      );
    });

    test('params_shouldStoreUserIdAndOptionalActivityId', () {
      // Arrange & Act
      const params = GetUserActivityResultsParams(
        userId: 'test-user',
        activityId: 'test-activity',
      );

      // Assert
      expect(params.userId, 'test-user');
      expect(params.activityId, 'test-activity');
    });

    test('params_withoutActivityId_shouldHaveNullActivityId', () {
      // Arrange & Act
      const params = GetUserActivityResultsParams(userId: 'test-user');

      // Assert
      expect(params.userId, 'test-user');
      expect(params.activityId, isNull);
    });
  });

  // ============================================
  // Edge Cases
  // ============================================
  group('edgeCases', () {
    test('submitResultWithComplexAnswers_shouldWork', () async {
      // Arrange
      final usecase = SubmitActivityResultUseCase(mockActivityRepository);
      final result = ActivityResult(
        id: 'result-complex',
        userId: 'user-123',
        activityId: 'activity-123',
        score: 75.0,
        maxScore: 100.0,
        answers: const {
          'q-1': 'text answer',
          'q-2': true,
          'q-3': 42,
          'q-4': ['option1', 'option2'],
        },
        timeSpent: 180,
        attemptNumber: 1,
        completedAt: DateTime.now(),
      );
      when(mockActivityRepository.submitActivityResult(result))
          .thenAnswer((_) async => Right(result));

      final params = SubmitActivityResultParams(result: result);

      // Act
      final response = await usecase(params);

      // Assert
      expect(response.isRight(), true);
    });

    test('getActivitiesWithUuidChapterId_shouldWork', () async {
      // Arrange
      final usecase = GetActivitiesByChapterUseCase(mockActivityRepository);
      const uuid = '550e8400-e29b-41d4-a716-446655440000';
      when(mockActivityRepository.getActivitiesByChapter(uuid))
          .thenAnswer((_) async => const Right(<Activity>[]));

      const params = GetActivitiesByChapterParams(chapterId: uuid);

      // Act
      final result = await usecase(params);

      // Assert
      expect(result.isRight(), true);
    });
  });

  // ============================================
  // Multiple Calls Tests
  // ============================================
  group('multipleCalls', () {
    test('submitResult_calledMultipleTimes_shouldCallRepositoryEachTime', () async {
      // Arrange
      final usecase = SubmitActivityResultUseCase(mockActivityRepository);
      final result = ActivityResultFixtures.validResult();
      when(mockActivityRepository.submitActivityResult(result))
          .thenAnswer((_) async => Right(result));

      final params = SubmitActivityResultParams(result: result);

      // Act
      await usecase(params);
      await usecase(params);
      await usecase(params);

      // Assert
      verify(mockActivityRepository.submitActivityResult(result)).called(3);
    });

    test('activityFlow_getActivitiesThenSubmitResult_shouldWork', () async {
      // Arrange
      final getActivitiesUseCase = GetActivitiesByChapterUseCase(mockActivityRepository);
      final submitResultUseCase = SubmitActivityResultUseCase(mockActivityRepository);

      final activities = [ActivityFixtures.validActivity()];
      final result = ActivityResultFixtures.validResult();

      when(mockActivityRepository.getActivitiesByChapter('chapter-1'))
          .thenAnswer((_) async => Right(activities));
      when(mockActivityRepository.submitActivityResult(result))
          .thenAnswer((_) async => Right(result));

      // Act - simulate quiz flow
      final getResult = await getActivitiesUseCase(
        const GetActivitiesByChapterParams(chapterId: 'chapter-1'),
      );
      final submitResponse = await submitResultUseCase(
        SubmitActivityResultParams(result: result),
      );

      // Assert
      expect(getResult.isRight(), true);
      expect(submitResponse.isRight(), true);
    });
  });
}
