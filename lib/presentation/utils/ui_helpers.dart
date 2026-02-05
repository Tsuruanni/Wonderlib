import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../domain/entities/student_assignment.dart';
import '../../domain/entities/word_list.dart';
import '../../domain/repositories/teacher_repository.dart';

/// Centralized color helpers for assignment UI elements (Teacher side)
abstract class AssignmentColors {
  static Color getTypeColor(AssignmentType type) {
    switch (type) {
      case AssignmentType.book:
        return Colors.blue;
      case AssignmentType.vocabulary:
        return Colors.purple;
      case AssignmentType.mixed:
        return Colors.teal;
    }
  }

  static IconData getTypeIcon(AssignmentType type) {
    switch (type) {
      case AssignmentType.book:
        return Icons.menu_book;
      case AssignmentType.vocabulary:
        return Icons.abc;
      case AssignmentType.mixed:
        return Icons.library_books;
    }
  }

  static Color getStatusColor(AssignmentStatus status) {
    switch (status) {
      case AssignmentStatus.pending:
        return Colors.grey;
      case AssignmentStatus.inProgress:
        return Colors.blue;
      case AssignmentStatus.completed:
        return Colors.green;
      case AssignmentStatus.overdue:
        return Colors.red;
    }
  }

  static IconData getStatusIcon(AssignmentStatus status) {
    switch (status) {
      case AssignmentStatus.pending:
        return Icons.schedule;
      case AssignmentStatus.inProgress:
        return Icons.play_circle;
      case AssignmentStatus.completed:
        return Icons.check_circle;
      case AssignmentStatus.overdue:
        return Icons.warning;
    }
  }
}

/// Centralized color helpers for student assignment UI elements
abstract class StudentAssignmentColors {
  static Color getTypeColor(StudentAssignmentType type) {
    switch (type) {
      case StudentAssignmentType.book:
        return Colors.blue;
      case StudentAssignmentType.vocabulary:
        return Colors.purple;
      case StudentAssignmentType.mixed:
        return Colors.teal;
    }
  }

  static IconData getTypeIcon(StudentAssignmentType type) {
    switch (type) {
      case StudentAssignmentType.book:
        return Icons.menu_book;
      case StudentAssignmentType.vocabulary:
        return Icons.abc;
      case StudentAssignmentType.mixed:
        return Icons.library_books;
    }
  }

  static Color getStatusColor(StudentAssignmentStatus status) {
    switch (status) {
      case StudentAssignmentStatus.pending:
        return Colors.grey;
      case StudentAssignmentStatus.inProgress:
        return Colors.blue;
      case StudentAssignmentStatus.completed:
        return Colors.green;
      case StudentAssignmentStatus.overdue:
        return Colors.red;
    }
  }

  static IconData getStatusIcon(StudentAssignmentStatus status) {
    switch (status) {
      case StudentAssignmentStatus.pending:
        return Icons.schedule;
      case StudentAssignmentStatus.inProgress:
        return Icons.play_circle;
      case StudentAssignmentStatus.completed:
        return Icons.check_circle;
      case StudentAssignmentStatus.overdue:
        return Icons.warning;
    }
  }
}

/// Centralized color helpers for vocabulary UI elements
abstract class VocabularyColors {
  static Color getCategoryColor(WordListCategory category) {
    switch (category) {
      case WordListCategory.commonWords:
        return AppColors.gemBlue;
      case WordListCategory.gradeLevel:
        return AppColors.primary;
      case WordListCategory.testPrep:
        return AppColors.streakOrange;
      case WordListCategory.thematic:
        return AppColors.secondary;
      case WordListCategory.storyVocab:
        return Colors.pink;
    }
  }
}

/// Centralized color helpers for score display
abstract class ScoreColors {
  static Color getScoreColor(double score) {
    if (score >= 80) return Colors.green;
    if (score >= 60) return Colors.orange;
    return Colors.red;
  }

  static Color getProgressColor(double progress) {
    if (progress >= 100) return Colors.green;
    if (progress >= 50) return Colors.orange;
    return Colors.blue;
  }

  static Color getCompletionColor(double rate) {
    if (rate >= 80) return Colors.green;
    if (rate >= 50) return Colors.orange;
    return Colors.red;
  }
}

/// Time formatting utilities
abstract class TimeFormatter {
  static String formatReadingTime(int seconds) {
    if (seconds < 60) return '${seconds}s';
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    if (remainingSeconds == 0) return '${minutes}m';
    return '${minutes}m ${remainingSeconds}s';
  }

  static String formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    if (hours > 0) return '${hours}h ${minutes}m';
    return '${minutes}m';
  }
}

/// Time-based greeting helper
abstract class GreetingHelper {
  static String getGreeting([DateTime? time]) {
    final hour = (time ?? DateTime.now()).hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }
}
