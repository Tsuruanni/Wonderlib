import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/vocabulary.dart';
import '../../domain/entities/vocabulary_session.dart';

// =============================================
// SESSION STATE
// =============================================

class VocabularySessionState {
  const VocabularySessionState({
    this.phase = SessionPhase.explore,
    this.words = const [],
    this.currentQuestion,
    this.questionIndex = 0,
    this.totalQuestionsAnswered = 0,
    this.combo = 0,
    this.maxCombo = 0,
    this.xpEarned = 0,
    this.correctCount = 0,
    this.incorrectCount = 0,
    this.remediationQueue = const [],
    this.introductionPairIndex = 0,
    this.isShowingIntroduction = true,
    this.isShowingFeedback = false,
    this.lastAnswerCorrect = false,
    this.lastCorrectAnswer,
    this.lastXPGained = 0,
    this.comboWarningActive = false,
    this.lastComboBroken = false,
    this.isSessionComplete = false,
    this.startTime,
    this.reinforceQuestionsAsked = 0,
    this.finalQuestionsAsked = 0,
    this.micDisabledForSession = false,
  });

  final SessionPhase phase;
  final List<WordSessionState> words;
  final SessionQuestion? currentQuestion;
  final int questionIndex;
  final int totalQuestionsAnswered;
  final int combo;
  final int maxCombo;
  final int xpEarned;
  final int correctCount;
  final int incorrectCount;
  final List<String> remediationQueue; // wordIds to retry soon
  final int introductionPairIndex;     // Which pair we're showing (0, 1, 2, 3)
  final bool isShowingIntroduction;    // true = showing cards, false = showing question
  final bool isShowingFeedback;
  final bool lastAnswerCorrect;
  final String? lastCorrectAnswer;
  final int lastXPGained;
  final bool comboWarningActive; // true = next wrong will break combo
  final bool lastComboBroken;    // true = combo just dropped this answer
  final bool isSessionComplete;
  final DateTime? startTime;
  final int reinforceQuestionsAsked;
  final int finalQuestionsAsked;
  final bool micDisabledForSession;

  /// Current pair of words being introduced (Faz 1)
  List<WordSessionState> get currentPair {
    final start = introductionPairIndex * 2;
    final end = min(start + 2, words.length);
    if (start >= words.length) return [];
    return words.sublist(start, end);
  }

  /// Total pairs for Faz 1
  int get totalPairs => (words.length / 2).ceil();

  /// Whether all pairs have been introduced
  bool get allPairsIntroduced => introductionPairIndex >= totalPairs;

  /// Overall accuracy for adaptive difficulty
  double get overallAccuracy {
    final total = correctCount + incorrectCount;
    if (total == 0) return 1.0;
    return correctCount / total;
  }

  /// Whether user is performing well (for adaptive difficulty)
  bool get isPerformingWell =>
      totalQuestionsAnswered >= 5 && overallAccuracy > 0.8;

  /// Whether user is struggling
  bool get isStruggling =>
      totalQuestionsAnswered >= 4 && overallAccuracy < 0.5;

  /// Words that had errors (for Faz 3)
  List<WordSessionState> get weakWords =>
      words.where((w) => w.incorrectCount > 0).toList()
        ..sort((a, b) => b.incorrectCount.compareTo(a.incorrectCount));

  /// Duration in seconds since session start
  int get durationSeconds {
    if (startTime == null) return 0;
    return DateTime.now().difference(startTime!).inSeconds;
  }

  VocabularySessionState copyWith({
    SessionPhase? phase,
    List<WordSessionState>? words,
    SessionQuestion? currentQuestion,
    bool clearQuestion = false,
    int? questionIndex,
    int? totalQuestionsAnswered,
    int? combo,
    int? maxCombo,
    int? xpEarned,
    int? correctCount,
    int? incorrectCount,
    List<String>? remediationQueue,
    int? introductionPairIndex,
    bool? isShowingIntroduction,
    bool? isShowingFeedback,
    bool? lastAnswerCorrect,
    String? lastCorrectAnswer,
    int? lastXPGained,
    bool? comboWarningActive,
    bool? lastComboBroken,
    bool clearLastCorrectAnswer = false,
    bool? isSessionComplete,
    DateTime? startTime,
    int? reinforceQuestionsAsked,
    int? finalQuestionsAsked,
    bool? micDisabledForSession,
  }) {
    return VocabularySessionState(
      phase: phase ?? this.phase,
      words: words ?? this.words,
      currentQuestion: clearQuestion ? null : (currentQuestion ?? this.currentQuestion),
      questionIndex: questionIndex ?? this.questionIndex,
      totalQuestionsAnswered: totalQuestionsAnswered ?? this.totalQuestionsAnswered,
      combo: combo ?? this.combo,
      maxCombo: maxCombo ?? this.maxCombo,
      xpEarned: xpEarned ?? this.xpEarned,
      correctCount: correctCount ?? this.correctCount,
      incorrectCount: incorrectCount ?? this.incorrectCount,
      remediationQueue: remediationQueue ?? this.remediationQueue,
      introductionPairIndex: introductionPairIndex ?? this.introductionPairIndex,
      isShowingIntroduction: isShowingIntroduction ?? this.isShowingIntroduction,
      isShowingFeedback: isShowingFeedback ?? this.isShowingFeedback,
      lastAnswerCorrect: lastAnswerCorrect ?? this.lastAnswerCorrect,
      lastCorrectAnswer: clearLastCorrectAnswer ? null : (lastCorrectAnswer ?? this.lastCorrectAnswer),
      lastXPGained: clearLastCorrectAnswer ? 0 : (lastXPGained ?? this.lastXPGained),
      comboWarningActive: comboWarningActive ?? this.comboWarningActive,
      lastComboBroken: lastComboBroken ?? this.lastComboBroken,
      isSessionComplete: isSessionComplete ?? this.isSessionComplete,
      startTime: startTime ?? this.startTime,
      reinforceQuestionsAsked: reinforceQuestionsAsked ?? this.reinforceQuestionsAsked,
      finalQuestionsAsked: finalQuestionsAsked ?? this.finalQuestionsAsked,
      micDisabledForSession: micDisabledForSession ?? this.micDisabledForSession,
    );
  }
}

// =============================================
// SESSION CONTROLLER
// =============================================

class VocabularySessionController extends StateNotifier<VocabularySessionState> {
  VocabularySessionController() : super(const VocabularySessionState());

  final _random = Random();

  /// Start a new session with words from a word list
  void startSession(List<VocabularyWord> vocabularyWords) {
    if (vocabularyWords.isEmpty) return;

    final wordStates = vocabularyWords.map((w) => WordSessionState(
      wordId: w.id,
      word: w.word,
      meaningTR: w.meaningTR,
      meaningEN: w.meaningEN,
      imageUrl: w.imageUrl,
      audioUrl: w.audioUrl,
      exampleSentence: w.exampleSentence,
      phonetic: w.phonetic,
    )).toList();

    state = VocabularySessionState(
      phase: SessionPhase.explore,
      words: wordStates,
      introductionPairIndex: 0,
      isShowingIntroduction: true,
      startTime: DateTime.now(),
    );
  }

  void disableMicForSession() {
    state = state.copyWith(micDisabledForSession: true);
  }

  // ------------------------------------
  // FAZ 1: EXPLORE
  // ------------------------------------

  /// Mark current pair's words as introduced, show the question
  void finishIntroduction() {
    final updatedWords = List<WordSessionState>.from(state.words);
    final pair = state.currentPair;
    for (final word in pair) {
      final idx = updatedWords.indexWhere((w) => w.wordId == word.wordId);
      if (idx != -1 && updatedWords[idx].masteryLevel == WordMasteryLevel.unseen) {
        updatedWords[idx] = updatedWords[idx].copyWith(
          masteryLevel: WordMasteryLevel.introduced,
        );
      }
    }

    // Generate easy question for this pair
    final question = _generateExplorePairQuestion(pair);

    state = state.copyWith(
      words: updatedWords,
      isShowingIntroduction: false,
      currentQuestion: question,
    );
  }

  /// Advance to next pair or transition to Faz 2
  void advanceAfterExploreQuestion() {
    final nextPairIndex = state.introductionPairIndex + 1;

    if (nextPairIndex >= state.totalPairs) {
      // All pairs introduced → transition to Faz 2
      _transitionToReinforce();
    } else {
      state = state.copyWith(
        introductionPairIndex: nextPairIndex,
        isShowingIntroduction: true,
        isShowingFeedback: false,
        clearQuestion: true,
      );
    }
  }

  // ------------------------------------
  // ANSWER HANDLING (all phases)
  // ------------------------------------

  /// Process an answer and update state
  void answerQuestion(String answer) {
    final question = state.currentQuestion;
    if (question == null) return;

    final isCorrect = _checkAnswer(answer, question);
    final wordIdx = state.words.indexWhere((w) => w.wordId == question.targetWordId);

    final updatedWords = List<WordSessionState>.from(state.words);

    if (wordIdx != -1) {
      final word = updatedWords[wordIdx];
      if (isCorrect) {
        // Update mastery level based on question tier
        var newMastery = word.masteryLevel;
        final tier = question.type.tier;
        if (tier == QuestionTier.recognition &&
            word.masteryLevel.index <= WordMasteryLevel.introduced.index) {
          newMastery = WordMasteryLevel.recognized;
        } else if (tier == QuestionTier.bridge &&
            word.masteryLevel.index <= WordMasteryLevel.recognized.index) {
          newMastery = WordMasteryLevel.bridged;
        } else if (tier == QuestionTier.production &&
            word.masteryLevel.index <= WordMasteryLevel.bridged.index) {
          newMastery = WordMasteryLevel.produced;
        }

        updatedWords[wordIdx] = word.copyWith(
          masteryLevel: newMastery,
          correctCount: word.correctCount + 1,
          needsRemediation: false,
        );
      } else {
        updatedWords[wordIdx] = word.copyWith(
          incorrectCount: word.incorrectCount + 1,
          isFirstTryPerfect: false,
          needsRemediation: true,
        );
      }
    }

    // Update combo with warning system:
    // First wrong while combo active → warning only, combo preserved
    // Second wrong (warning active) → combo drops by 2
    // Correct answer → combo+1, warning cleared
    int newCombo;
    bool newWarning;
    bool broken = false;
    if (isCorrect) {
      newCombo = state.combo + 1;
      newWarning = false;
    } else if (state.combo >= 2 && !state.comboWarningActive) {
      // First miss with active combo: warn but preserve
      newCombo = state.combo;
      newWarning = true;
    } else {
      // No combo or warning already shown: drop combo
      broken = state.combo >= 2; // had a combo and it's dropping
      newCombo = max<int>(0, state.combo - 2);
      newWarning = false;
    }
    final newMaxCombo = max<int>(newCombo, state.maxCombo);

    // Calculate XP with combo multiplier
    int xpGained = 0;
    if (isCorrect) {
      final comboMultiplier = min<int>(newCombo, 5); // Cap at x5
      final baseXP = (question.type == QuestionType.pronunciation &&
              state.micDisabledForSession)
          ? QuestionType.spelling.baseXP
          : question.type.baseXP;
      xpGained = baseXP * max<int>(1, comboMultiplier);
    }

    // Add to remediation queue if wrong
    final updatedRemediation = List<String>.from(state.remediationQueue);
    if (!isCorrect && !updatedRemediation.contains(question.targetWordId)) {
      updatedRemediation.add(question.targetWordId);
    } else if (isCorrect) {
      updatedRemediation.remove(question.targetWordId);
    }

    state = state.copyWith(
      words: updatedWords,
      combo: newCombo,
      maxCombo: newMaxCombo,
      comboWarningActive: newWarning,
      lastComboBroken: broken,
      xpEarned: state.xpEarned + xpGained,
      correctCount: state.correctCount + (isCorrect ? 1 : 0),
      incorrectCount: state.incorrectCount + (isCorrect ? 0 : 1),
      totalQuestionsAnswered: state.totalQuestionsAnswered + 1,
      remediationQueue: updatedRemediation,
      isShowingFeedback: true,
      lastAnswerCorrect: isCorrect,
      lastCorrectAnswer: isCorrect ? null : question.correctAnswer,
      lastXPGained: xpGained,
    );
  }

  /// Dismiss feedback and advance to next question
  void dismissFeedback() {
    if (state.phase == SessionPhase.explore) {
      advanceAfterExploreQuestion();
      return;
    }

    state = state.copyWith(
      isShowingFeedback: false,
      clearLastCorrectAnswer: true,
    );

    _generateNextQuestion();
  }

  /// Answer a matching question (special: processes all 4 words at once)
  void answerMatchingQuestion({
    required int correctMatches,
    required int totalMatches,
    required List<String> correctWordIds,
    required List<String> incorrectWordIds,
  }) {
    final updatedWords = List<WordSessionState>.from(state.words);

    for (final wordId in correctWordIds) {
      final idx = updatedWords.indexWhere((w) => w.wordId == wordId);
      if (idx != -1) {
        var newMastery = updatedWords[idx].masteryLevel;
        if (newMastery.index <= WordMasteryLevel.recognized.index) {
          newMastery = WordMasteryLevel.bridged;
        }
        updatedWords[idx] = updatedWords[idx].copyWith(
          masteryLevel: newMastery,
          correctCount: updatedWords[idx].correctCount + 1,
        );
      }
    }

    for (final wordId in incorrectWordIds) {
      final idx = updatedWords.indexWhere((w) => w.wordId == wordId);
      if (idx != -1) {
        updatedWords[idx] = updatedWords[idx].copyWith(
          incorrectCount: updatedWords[idx].incorrectCount + 1,
          isFirstTryPerfect: false,
          needsRemediation: true,
        );
      }
    }

    final isAllCorrect = correctMatches == totalMatches;
    // Combo warning system (same as answerQuestion)
    int newCombo;
    bool newWarning;
    bool broken = false;
    if (isAllCorrect) {
      newCombo = state.combo + 1;
      newWarning = false;
    } else if (state.combo >= 2 && !state.comboWarningActive) {
      newCombo = state.combo;
      newWarning = true;
    } else {
      broken = state.combo >= 2;
      newCombo = max<int>(0, state.combo - 2);
      newWarning = false;
    }
    // Partial XP for matching: 3/4 correct still earns proportional XP
    final comboMult = max<int>(1, min<int>(newCombo, 5));
    final xpGained = correctMatches > 0
        ? (QuestionType.matching.baseXP * comboMult * correctMatches) ~/ totalMatches
        : 0;

    // Add incorrect words to remediation
    final updatedRemediation = List<String>.from(state.remediationQueue);
    for (final wordId in incorrectWordIds) {
      if (!updatedRemediation.contains(wordId)) {
        updatedRemediation.add(wordId);
      }
    }

    state = state.copyWith(
      words: updatedWords,
      combo: newCombo,
      comboWarningActive: newWarning,
      lastComboBroken: broken,
      maxCombo: max<int>(newCombo, state.maxCombo),
      xpEarned: state.xpEarned + xpGained,
      // Count matching as 1 question for accuracy (not 4)
      correctCount: state.correctCount + (isAllCorrect ? 1 : 0),
      incorrectCount: state.incorrectCount + (isAllCorrect ? 0 : 1),
      totalQuestionsAnswered: state.totalQuestionsAnswered + 1,
      remediationQueue: updatedRemediation,
      isShowingFeedback: true,
      lastAnswerCorrect: isAllCorrect,
      lastXPGained: xpGained,
      reinforceQuestionsAsked: state.phase == SessionPhase.reinforce
          ? state.reinforceQuestionsAsked + 1
          : state.reinforceQuestionsAsked,
    );
  }

  // ------------------------------------
  // FAZ 2: REINFORCE — Question Generation
  // ------------------------------------

  void _transitionToReinforce() {
    state = state.copyWith(
      phase: SessionPhase.reinforce,
      isShowingIntroduction: false,
      isShowingFeedback: false,
      reinforceQuestionsAsked: 0,
      clearQuestion: true,
    );
    _generateNextQuestion();
  }

  void _generateNextQuestion() {
    if (state.phase == SessionPhase.reinforce) {
      _generateReinforceQuestion();
    } else if (state.phase == SessionPhase.finalPhase) {
      _generateFinalQuestion();
    }
  }

  void _generateReinforceQuestion() {
    // Check if we should transition to Final phase
    // All words must reach at least bridged level (passed bridge questions)
    // so that production-tier questions (spelling, pronunciation) get a chance
    final allBridged = state.words.every(
      (w) => w.masteryLevel.index >= WordMasteryLevel.bridged.index,
    );
    final minQuestions = state.words.length * 2 + 4; // ensure ~4 production Qs
    final enoughQuestions = state.reinforceQuestionsAsked >= minQuestions;

    if (allBridged && enoughQuestions) {
      _transitionToFinal();
      return;
    }

    // Hard cap scales with word count to keep sessions reasonable
    final hardCap = state.words.length * 3;
    if (state.reinforceQuestionsAsked >= hardCap) {
      _transitionToFinal();
      return;
    }

    // Check remediation queue first (retry 1-2 questions after error)
    if (state.remediationQueue.isNotEmpty && _random.nextDouble() < 0.4) {
      final wordId = state.remediationQueue.first;
      final word = state.words.firstWhere((w) => w.wordId == wordId);
      final question = _generateRemediationQuestion(word);
      state = state.copyWith(
        currentQuestion: question,
        questionIndex: state.questionIndex + 1,
        reinforceQuestionsAsked: state.reinforceQuestionsAsked + 1,
      );
      return;
    }

    // Pick a word that needs testing, prioritizing lower mastery
    final targetWord = _pickWordForReinforce();
    if (targetWord == null) {
      _transitionToFinal();
      return;
    }

    final question = _generateQuestionForWord(targetWord);
    state = state.copyWith(
      currentQuestion: question,
      questionIndex: state.questionIndex + 1,
      reinforceQuestionsAsked: state.reinforceQuestionsAsked + 1,
    );
  }

  WordSessionState? _pickWordForReinforce() {
    // Separate words by what they need
    final needsRecognition = state.words
        .where((w) =>
            w.masteryLevel.index <= WordMasteryLevel.introduced.index)
        .toList();
    final needsBridge = state.words
        .where((w) => w.masteryLevel == WordMasteryLevel.recognized)
        .toList();
    final needsProduction = state.words
        .where((w) => w.masteryLevel == WordMasteryLevel.bridged)
        .toList();

    // Always prioritize lower mastery levels — every word must pass
    // recognition before moving to bridge/production
    if (needsRecognition.isNotEmpty) {
      return needsRecognition[_random.nextInt(needsRecognition.length)];
    }
    if (needsBridge.isNotEmpty) {
      return needsBridge[_random.nextInt(needsBridge.length)];
    }
    if (needsProduction.isNotEmpty) {
      return needsProduction[_random.nextInt(needsProduction.length)];
    }

    // All words at max mastery — pick random for variety
    if (state.words.isNotEmpty) {
      return state.words[_random.nextInt(state.words.length)];
    }
    return null;
  }

  SessionQuestion _generateQuestionForWord(WordSessionState word) {
    // Determine appropriate question types based on mastery
    List<QuestionType> eligibleTypes;

    switch (word.masteryLevel) {
      case WordMasteryLevel.unseen:
      case WordMasteryLevel.introduced:
        eligibleTypes = [
          QuestionType.multipleChoice,
          QuestionType.reverseMultipleChoice,
          QuestionType.listeningSelect,
        ];
      case WordMasteryLevel.recognized:
        eligibleTypes = [
          QuestionType.scrambledLetters,
          QuestionType.wordWheel,
          if (state.words.length >= 4) QuestionType.matching,
        ];
        // If struggling, also allow easier types
        if (state.isStruggling) {
          eligibleTypes.add(QuestionType.reverseMultipleChoice);
        }
      case WordMasteryLevel.bridged:
      case WordMasteryLevel.produced:
        eligibleTypes = [
          QuestionType.spelling,
          QuestionType.listeningWrite,
          if (!state.micDisabledForSession && word.word.length >= 3)
            QuestionType.pronunciation,
          if (word.exampleSentence != null) QuestionType.sentenceGap,
        ];
        // If no production type available, fall back to bridge
        if (eligibleTypes.isEmpty) {
          eligibleTypes = [QuestionType.scrambledLetters, QuestionType.wordWheel];
        }
    }

    final type = eligibleTypes[_random.nextInt(eligibleTypes.length)];
    return _buildQuestion(type, word);
  }

  SessionQuestion _generateRemediationQuestion(WordSessionState word) {
    // Easy remediation: 2-option MC with image support
    final otherWords = state.words.where((w) => w.wordId != word.wordId).toList();
    otherWords.shuffle(_random);
    final wrongOption = otherWords.isNotEmpty ? otherWords.first.meaningTR : '???';

    final options = [word.meaningTR, wrongOption]..shuffle(_random);

    return SessionQuestion(
      type: QuestionType.multipleChoice,
      targetWordId: word.wordId,
      targetWord: word.word,
      targetMeaning: word.meaningTR,
      correctAnswer: word.meaningTR,
      options: options,
      imageUrl: word.imageUrl,
      audioUrl: word.audioUrl,
      isRemediation: true,
    );
  }

  // ------------------------------------
  // FAZ 3: FINAL
  // ------------------------------------

  void _transitionToFinal() {
    if (state.weakWords.isEmpty) {
      // No weak words — session complete
      _completeSession();
      return;
    }

    state = state.copyWith(
      phase: SessionPhase.finalPhase,
      isShowingFeedback: false,
      finalQuestionsAsked: 0,
      clearQuestion: true,
    );
    _generateFinalQuestion();
  }

  void _generateFinalQuestion() {
    final targetFinalQuestions = min(5, state.weakWords.length);
    if (state.finalQuestionsAsked >= targetFinalQuestions) {
      _completeSession();
      return;
    }

    // Pick from weakest words
    final weak = state.weakWords;
    final word = weak[state.finalQuestionsAsked % weak.length];

    // Use production-level questions for final phase
    List<QuestionType> types = [
      QuestionType.spelling,
      if (!state.micDisabledForSession && word.word.length >= 3)
        QuestionType.pronunciation,
      if (word.exampleSentence != null) QuestionType.sentenceGap,
      QuestionType.scrambledLetters,
      QuestionType.wordWheel,
    ];

    final type = types[_random.nextInt(types.length)];
    final question = _buildQuestion(type, word);

    state = state.copyWith(
      currentQuestion: question,
      questionIndex: state.questionIndex + 1,
      finalQuestionsAsked: state.finalQuestionsAsked + 1,
    );
  }

  void _completeSession() {
    state = state.copyWith(isSessionComplete: true);
  }

  // ------------------------------------
  // QUESTION BUILDERS
  // ------------------------------------

  SessionQuestion _buildQuestion(QuestionType type, WordSessionState word) {
    switch (type) {
      case QuestionType.multipleChoice:
        return _buildMultipleChoice(word, reverse: false);
      case QuestionType.reverseMultipleChoice:
        return _buildMultipleChoice(word, reverse: true);
      case QuestionType.listeningSelect:
        return _buildListeningSelect(word);
      case QuestionType.matching:
        return _buildMatching(word);
      case QuestionType.scrambledLetters:
      case QuestionType.wordWheel:
        return _buildScrambledLetters(word, type: type);
      case QuestionType.spelling:
        return _buildSpelling(word);
      case QuestionType.listeningWrite:
        return _buildListeningWrite(word);
      case QuestionType.sentenceGap:
        return _buildSentenceGap(word);
      case QuestionType.pronunciation:
        return _buildPronunciation(word);
    }
  }

  SessionQuestion _buildMultipleChoice(WordSessionState word, {required bool reverse}) {
    final otherWords = state.words.where((w) => w.wordId != word.wordId).toList();
    otherWords.shuffle(_random);
    final wrongOptions = otherWords
        .take(3)
        .map((w) => reverse ? w.word : w.meaningTR)
        .toList();

    // Pad with placeholder distractors if pool is too small for 4 options
    if (wrongOptions.length < 3) {
      final placeholders = reverse
          ? const ['(other)', '(none)', '(unknown)']
          : const ['(diğer)', '(yok)', '(bilinmiyor)'];
      final correctAnswer = reverse ? word.word : word.meaningTR;
      for (final p in placeholders) {
        if (wrongOptions.length >= 3) break;
        if (p != correctAnswer && !wrongOptions.contains(p)) {
          wrongOptions.add(p);
        }
      }
    }

    final correctAnswer = reverse ? word.word : word.meaningTR;
    final options = [correctAnswer, ...wrongOptions]..shuffle(_random);

    return SessionQuestion(
      type: reverse ? QuestionType.reverseMultipleChoice : QuestionType.multipleChoice,
      targetWordId: word.wordId,
      targetWord: word.word,
      targetMeaning: word.meaningTR,
      correctAnswer: correctAnswer,
      options: options,
      imageUrl: word.imageUrl,
      audioUrl: word.audioUrl,
    );
  }

  SessionQuestion _buildListeningSelect(WordSessionState word) {
    final otherWords = state.words.where((w) => w.wordId != word.wordId).toList();
    otherWords.shuffle(_random);
    final wrongOptions = otherWords.take(3).map((w) => w.word).toList();

    // Pad if pool too small
    if (wrongOptions.length < 3) {
      const placeholders = ['(other)', '(none)', '(unknown)'];
      for (final p in placeholders) {
        if (wrongOptions.length >= 3) break;
        if (p != word.word && !wrongOptions.contains(p)) {
          wrongOptions.add(p);
        }
      }
    }

    final options = [word.word, ...wrongOptions]..shuffle(_random);

    return SessionQuestion(
      type: QuestionType.listeningSelect,
      targetWordId: word.wordId,
      targetWord: word.word,
      targetMeaning: word.meaningTR,
      correctAnswer: word.word,
      options: options,
      audioUrl: word.audioUrl,
    );
  }

  SessionQuestion _buildMatching(WordSessionState word) {
    // Pick 3 more words for matching (total 4)
    final otherWords = state.words.where((w) => w.wordId != word.wordId).toList();
    otherWords.shuffle(_random);
    final matchWords = [word, ...otherWords.take(3)];

    final pairs = matchWords.map((w) => SessionMatchingPair(
      word: w.word,
      meaning: w.meaningTR,
      wordId: w.wordId,
    )).toList();

    return SessionQuestion(
      type: QuestionType.matching,
      targetWordId: word.wordId,
      targetWord: word.word,
      targetMeaning: word.meaningTR,
      correctAnswer: '', // N/A for matching
      matchingPairs: pairs,
    );
  }

  SessionQuestion _buildScrambledLetters(
    WordSessionState word, {
    QuestionType type = QuestionType.scrambledLetters,
  }) {
    final letters = word.word.split('');
    final scrambled = List<String>.from(letters);

    // Ensure scrambled order is different from original (limit iterations to avoid
    // infinite loop on words with identical characters like "aa")
    int attempts = 0;
    do {
      scrambled.shuffle(_random);
      attempts++;
    } while (scrambled.join() == word.word && word.word.length > 1 && attempts < 20);

    return SessionQuestion(
      type: type,
      targetWordId: word.wordId,
      targetWord: word.word,
      targetMeaning: word.meaningTR,
      correctAnswer: word.word,
      scrambledLetters: scrambled,
      imageUrl: word.imageUrl,
    );
  }

  SessionQuestion _buildSpelling(WordSessionState word) {
    return SessionQuestion(
      type: QuestionType.spelling,
      targetWordId: word.wordId,
      targetWord: word.word,
      targetMeaning: word.meaningTR,
      correctAnswer: word.word,
    );
  }

  SessionQuestion _buildPronunciation(WordSessionState word) {
    return SessionQuestion(
      type: QuestionType.pronunciation,
      targetWordId: word.wordId,
      targetWord: word.word,
      targetMeaning: word.meaningTR,
      correctAnswer: word.word,
      imageUrl: word.imageUrl,
    );
  }

  SessionQuestion _buildListeningWrite(WordSessionState word) {
    return SessionQuestion(
      type: QuestionType.listeningWrite,
      targetWordId: word.wordId,
      targetWord: word.word,
      targetMeaning: word.meaningTR,
      correctAnswer: word.word,
      audioUrl: word.audioUrl,
    );
  }

  SessionQuestion _buildSentenceGap(WordSessionState word) {
    final sentence = word.exampleSentence ?? 'The ___ is important.';
    // Replace the target word with a blank
    final gapSentence = sentence.replaceFirst(
      RegExp(RegExp.escape(word.word), caseSensitive: false),
      '___',
    );

    return SessionQuestion(
      type: QuestionType.sentenceGap,
      targetWordId: word.wordId,
      targetWord: word.word,
      targetMeaning: word.meaningTR,
      correctAnswer: word.word,
      sentence: gapSentence,
    );
  }

  // ------------------------------------
  // EXPLORE QUESTION (Faz 1 — easy)
  // ------------------------------------

  SessionQuestion _generateExplorePairQuestion(List<WordSessionState> pair) {
    if (pair.length < 2) {
      // Single word left — simple MC with a random distractor
      final word = pair.first;
      final others = state.words.where((w) => w.wordId != word.wordId).toList();
      others.shuffle(_random);
      final wrongOption = others.isNotEmpty ? others.first.meaningTR : '???';
      final options = [word.meaningTR, wrongOption]..shuffle(_random);

      return SessionQuestion(
        type: QuestionType.multipleChoice,
        targetWordId: word.wordId,
        targetWord: word.word,
        targetMeaning: word.meaningTR,
        correctAnswer: word.meaningTR,
        options: options,
        imageUrl: word.imageUrl,
        audioUrl: word.audioUrl,
      );
    }

    // 2-option MC from the pair
    final targetIdx = _random.nextInt(2);
    final target = pair[targetIdx];
    final other = pair[1 - targetIdx];

    // Vary question style by pair index
    final useImageStyle = state.introductionPairIndex % 2 == 0;

    if (useImageStyle) {
      // EN word → pick Turkish meaning (2 options)
      final options = [target.meaningTR, other.meaningTR]..shuffle(_random);
      return SessionQuestion(
        type: QuestionType.multipleChoice,
        targetWordId: target.wordId,
        targetWord: target.word,
        targetMeaning: target.meaningTR,
        correctAnswer: target.meaningTR,
        options: options,
        imageUrl: target.imageUrl,
        audioUrl: target.audioUrl,
      );
    } else {
      // Audio / listening style — play audio, pick word
      final options = [target.word, other.word]..shuffle(_random);
      return SessionQuestion(
        type: QuestionType.listeningSelect,
        targetWordId: target.wordId,
        targetWord: target.word,
        targetMeaning: target.meaningTR,
        correctAnswer: target.word,
        options: options,
        audioUrl: target.audioUrl,
      );
    }
  }

  // ------------------------------------
  // HELPERS
  // ------------------------------------

  bool _checkAnswer(String answer, SessionQuestion question) {
    // Case-insensitive comparison, trim whitespace
    final normalizedAnswer = answer.trim().toLowerCase();
    final normalizedCorrect = question.correctAnswer.trim().toLowerCase();
    return normalizedAnswer == normalizedCorrect;
  }

  /// Build session results for persistence
  List<SessionWordResult> buildWordResults() {
    return state.words.map((w) => SessionWordResult(
      wordId: w.wordId,
      correctCount: w.correctCount,
      incorrectCount: w.incorrectCount,
      masteryLevel: w.masteryLevel,
      isFirstTryPerfect: w.isFirstTryPerfect,
    )).toList();
  }

  /// Count of strong words (no errors)
  int get wordsStrongCount => state.words.where((w) => w.incorrectCount == 0).length;

  /// Count of weak words (had errors)
  int get wordsWeakCount => state.words.where((w) => w.incorrectCount > 0).length;

  /// Count of first-try-perfect words
  int get firstTryPerfectCount => state.words.where((w) => w.isFirstTryPerfect).length;
}

// =============================================
// PROVIDER
// =============================================

// Not autoDispose: state must survive session→summary navigation.
// startSession() resets everything, so no stale data risk.
final vocabularySessionControllerProvider =
    StateNotifierProvider<VocabularySessionController, VocabularySessionState>(
  (ref) => VocabularySessionController(),
);
