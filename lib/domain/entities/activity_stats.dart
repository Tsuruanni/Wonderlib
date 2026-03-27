import 'package:equatable/equatable.dart';

class ActivityStats extends Equatable {
  const ActivityStats({
    required this.totalCompleted,
    required this.averageScore,
    required this.perfectScores,
  });

  /// Number of activities the user has completed.
  final int totalCompleted;

  /// Average score as a rounded percentage (0-100).
  final int averageScore;

  /// Number of activities where the user achieved a perfect score.
  final int perfectScores;

  static const empty = ActivityStats(
    totalCompleted: 0,
    averageScore: 0,
    perfectScores: 0,
  );

  @override
  List<Object?> get props => [totalCompleted, averageScore, perfectScores];
}
