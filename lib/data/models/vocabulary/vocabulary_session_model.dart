import '../../../domain/entities/vocabulary_session.dart';

/// Model for VocabularySessionResult - handles JSON serialization
class VocabularySessionModel {

  const VocabularySessionModel({
    required this.id,
    required this.userId,
    required this.wordListId,
    required this.totalQuestions,
    required this.correctCount,
    required this.incorrectCount,
    required this.accuracy,
    required this.maxCombo,
    required this.xpEarned,
    required this.durationSeconds,
    required this.wordsStrong,
    required this.wordsWeak,
    required this.firstTryPerfectCount,
    required this.completedAt,
    this.wordResults = const [],
  });

  factory VocabularySessionModel.fromJson(Map<String, dynamic> json) {
    return VocabularySessionModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      wordListId: json['word_list_id'] as String,
      totalQuestions: json['total_questions'] as int? ?? 0,
      correctCount: json['correct_count'] as int? ?? 0,
      incorrectCount: json['incorrect_count'] as int? ?? 0,
      accuracy: (json['accuracy'] as num?)?.toDouble() ?? 0,
      maxCombo: json['max_combo'] as int? ?? 0,
      xpEarned: json['xp_earned'] as int? ?? 0,
      durationSeconds: json['duration_seconds'] as int? ?? 0,
      wordsStrong: json['words_strong'] as int? ?? 0,
      wordsWeak: json['words_weak'] as int? ?? 0,
      firstTryPerfectCount: json['first_try_perfect_count'] as int? ?? 0,
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at'] as String)
          : DateTime.now(),
    );
  }

  /// Parse from RPC response (complete_vocabulary_session returns session_id + total_xp)
  factory VocabularySessionModel.fromRpcResponse({
    required Map<String, dynamic> rpcResult,
    required String userId,
    required String wordListId,
    required int totalQuestions,
    required int correctCount,
    required int incorrectCount,
    required double accuracy,
    required int maxCombo,
    required int durationSeconds,
    required int wordsStrong,
    required int wordsWeak,
    required int firstTryPerfectCount,
    required List<SessionWordResult> wordResults,
  }) {
    return VocabularySessionModel(
      id: rpcResult['session_id'] as String,
      userId: userId,
      wordListId: wordListId,
      totalQuestions: totalQuestions,
      correctCount: correctCount,
      incorrectCount: incorrectCount,
      accuracy: accuracy,
      maxCombo: maxCombo,
      xpEarned: rpcResult['total_xp'] as int? ?? 0,
      durationSeconds: durationSeconds,
      wordsStrong: wordsStrong,
      wordsWeak: wordsWeak,
      firstTryPerfectCount: firstTryPerfectCount,
      completedAt: DateTime.now(),
      wordResults: wordResults,
    );
  }

  final String id;
  final String userId;
  final String wordListId;
  final int totalQuestions;
  final int correctCount;
  final int incorrectCount;
  final double accuracy;
  final int maxCombo;
  final int xpEarned;
  final int durationSeconds;
  final int wordsStrong;
  final int wordsWeak;
  final int firstTryPerfectCount;
  final DateTime completedAt;
  final List<SessionWordResult> wordResults;

  VocabularySessionResult toEntity() {
    return VocabularySessionResult(
      id: id,
      userId: userId,
      wordListId: wordListId,
      totalQuestions: totalQuestions,
      correctCount: correctCount,
      incorrectCount: incorrectCount,
      accuracy: accuracy,
      maxCombo: maxCombo,
      xpEarned: xpEarned,
      durationSeconds: durationSeconds,
      wordsStrong: wordsStrong,
      wordsWeak: wordsWeak,
      firstTryPerfectCount: firstTryPerfectCount,
      completedAt: completedAt,
      wordResults: wordResults,
    );
  }
}

/// Model for serializing word results to JSON for the RPC call
class SessionWordResultModel {
  static Map<String, dynamic> toRpcJson(SessionWordResult result) {
    return {
      'word_id': result.wordId,
      'correct_count': result.correctCount,
      'incorrect_count': result.incorrectCount,
      'mastery_level': _masteryToString(result.masteryLevel),
      'is_first_try_perfect': result.isFirstTryPerfect,
    };
  }

  static String _masteryToString(WordMasteryLevel level) {
    switch (level) {
      case WordMasteryLevel.unseen:
      case WordMasteryLevel.introduced:
        return 'introduced';
      case WordMasteryLevel.recognized:
        return 'recognized';
      case WordMasteryLevel.bridged:
        return 'bridged';
      case WordMasteryLevel.produced:
        return 'produced';
    }
  }
}
