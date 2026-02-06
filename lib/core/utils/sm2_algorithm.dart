/// User's response to a flashcard
enum SM2Response {
  dontKnow,  // "I don't know!" - failed, reset
  gotIt,     // "Got it!" - correct, normal progression
  veryEasy,  // "Very EASY!" - correct, accelerated progression
}

extension SM2ResponseExtension on SM2Response {
  String get displayText {
    switch (this) {
      case SM2Response.dontKnow:
        return "I don't know!";
      case SM2Response.gotIt:
        return 'Got it!';
      case SM2Response.veryEasy:
        return 'Very EASY!';
    }
  }

  String get emoji {
    switch (this) {
      case SM2Response.dontKnow:
        return '😕';
      case SM2Response.gotIt:
        return '😊';
      case SM2Response.veryEasy:
        return '🚀';
    }
  }

  /// Convert SM2Response to quality score (0-5) for VocabularyProgress.calculateNextReview
  int toQuality() {
    switch (this) {
      case SM2Response.dontKnow:
        return 1; // Failed
      case SM2Response.gotIt:
        return 4; // Correct with some difficulty
      case SM2Response.veryEasy:
        return 5; // Perfect recall
    }
  }
}
