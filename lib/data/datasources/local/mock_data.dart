import '../../../core/constants/app_constants.dart';
import '../../../domain/entities/activity.dart';
import '../../../domain/entities/badge.dart';
import '../../../domain/entities/book.dart';
import '../../../domain/entities/chapter.dart';
import '../../../domain/entities/reading_progress.dart';
import '../../../domain/entities/school.dart';
import '../../../domain/entities/user.dart';
import '../../../domain/entities/vocabulary.dart';

class MockData {
  // ============================================
  // INLINE ACTIVITIES (Microlearning)
  // ============================================

  /// Inline activities for chapter-1-1 (The Drawing)
  static final inlineActivitiesChapter1 = [
    // After paragraph 1: True/False about the picture
    const InlineActivity(
      id: 'inline-1-1',
      type: InlineActivityType.trueFalse,
      afterParagraphIndex: 0,
      content: TrueFalseContent(
        statement: 'Anlatıcı resmi bir gazetede gördü',
        correctAnswer: false,
      ),
      xpReward: 5,
    ),

    // After paragraph 2: Word translation
    const InlineActivity(
      id: 'inline-1-2',
      type: InlineActivityType.wordTranslation,
      afterParagraphIndex: 1,
      content: WordTranslationContent(
        word: 'magnificent',
        correctAnswer: 'muhteşem',
        options: ['muhteşem', 'korkunç', 'sıradan'],
      ),
      xpReward: 5,
      vocabularyWords: ['magnificent'],
    ),

    // After paragraph 3: True/False about the hat
    const InlineActivity(
      id: 'inline-1-3',
      type: InlineActivityType.trueFalse,
      afterParagraphIndex: 2,
      content: TrueFalseContent(
        statement: 'Yetişkinler çizimin bir şapka olduğunu düşündü',
        correctAnswer: true,
      ),
      xpReward: 5,
    ),

    // After paragraph 4: Find words from paragraph
    const InlineActivity(
      id: 'inline-1-4',
      type: InlineActivityType.findWords,
      afterParagraphIndex: 3,
      content: FindWordsContent(
        instruction: 'Paragrafta geçen iki kelimeyi bul',
        options: ['Coğrafya', 'Matematik', 'Müzik'],
        correctAnswers: ['Coğrafya', 'Matematik'],
      ),
      xpReward: 5,
      vocabularyWords: ['geography', 'arithmetic'],
    ),

    // After paragraph 5: Word translation
    const InlineActivity(
      id: 'inline-1-5',
      type: InlineActivityType.wordTranslation,
      afterParagraphIndex: 4,
      content: WordTranslationContent(
        word: 'masterpiece',
        correctAnswer: 'başyapıt',
        options: ['başyapıt', 'resim', 'çizgi'],
      ),
      xpReward: 5,
      vocabularyWords: ['masterpiece'],
    ),
  ];

  /// Inline activities for chapter-1-2 (The Pilot)
  static final inlineActivitiesChapter2 = [
    const InlineActivity(
      id: 'inline-2-1',
      type: InlineActivityType.trueFalse,
      afterParagraphIndex: 0,
      content: TrueFalseContent(
        statement: 'Anlatıcı pilot olmayı seçti',
        correctAnswer: true,
      ),
      xpReward: 5,
    ),

    const InlineActivity(
      id: 'inline-2-2',
      type: InlineActivityType.wordTranslation,
      afterParagraphIndex: 1,
      content: WordTranslationContent(
        word: 'distinguish',
        correctAnswer: 'ayırt etmek',
        options: ['ayırt etmek', 'uçmak', 'kaybolmak'],
      ),
      xpReward: 5,
      vocabularyWords: ['distinguish'],
    ),

    const InlineActivity(
      id: 'inline-2-3',
      type: InlineActivityType.findWords,
      afterParagraphIndex: 2,
      content: FindWordsContent(
        instruction: 'Yetişkinlerle ilgili iki kelime bul',
        options: ['Anlayışlı', 'Önemli', 'Çocuksu'],
        correctAnswers: ['Anlayışlı', 'Önemli'],
      ),
      xpReward: 5,
      vocabularyWords: ['clear-sighted', 'consequence'],
    ),

    const InlineActivity(
      id: 'inline-2-4',
      type: InlineActivityType.trueFalse,
      afterParagraphIndex: 3,
      content: TrueFalseContent(
        statement: 'Anlatıcı yetişkinler hakkındaki fikrini değiştirdi',
        correctAnswer: false,
      ),
      xpReward: 5,
    ),
  ];

  /// Inline activities for chapter-1-3 (The Little Prince Arrives)
  static final inlineActivitiesChapter3 = [
    const InlineActivity(
      id: 'inline-3-1',
      type: InlineActivityType.trueFalse,
      afterParagraphIndex: 0,
      content: TrueFalseContent(
        statement: 'Anlatıcının uçağı Sahra Çölü\'nde arızalandı',
        correctAnswer: true,
      ),
      xpReward: 5,
    ),

    const InlineActivity(
      id: 'inline-3-2',
      type: InlineActivityType.wordTranslation,
      afterParagraphIndex: 1,
      content: WordTranslationContent(
        word: 'scarcely',
        correctAnswer: 'zar zor',
        options: ['zar zor', 'bolca', 'hızlıca'],
      ),
      xpReward: 5,
      vocabularyWords: ['scarcely'],
    ),

    const InlineActivity(
      id: 'inline-3-3',
      type: InlineActivityType.findWords,
      afterParagraphIndex: 2,
      content: FindWordsContent(
        instruction: 'Anlatıcının durumunu anlatan iki kelime bul',
        options: ['Yalnız', 'İzole', 'Mutlu'],
        correctAnswers: ['Yalnız', 'İzole'],
      ),
      xpReward: 5,
      vocabularyWords: ['alone', 'isolated'],
    ),

    const InlineActivity(
      id: 'inline-3-4',
      type: InlineActivityType.wordTranslation,
      afterParagraphIndex: 3,
      content: WordTranslationContent(
        word: 'amazement',
        correctAnswer: 'şaşkınlık',
        options: ['şaşkınlık', 'korku', 'mutluluk'],
      ),
      xpReward: 5,
      vocabularyWords: ['amazement'],
    ),

    const InlineActivity(
      id: 'inline-3-5',
      type: InlineActivityType.trueFalse,
      afterParagraphIndex: 4,
      content: TrueFalseContent(
        statement: 'Küçük ses anlatıcıdan bir koyun çizmesini istedi',
        correctAnswer: true,
      ),
      xpReward: 5,
    ),
  ];

  /// Get inline activities for a specific chapter
  static List<InlineActivity> getInlineActivities(String chapterId) {
    switch (chapterId) {
      case 'chapter-1-1':
        return inlineActivitiesChapter1;
      case 'chapter-1-2':
        return inlineActivitiesChapter2;
      case 'chapter-1-3':
        return inlineActivitiesChapter3;
      default:
        return [];
    }
  }
  // Schools
  static final schools = [
    School(
      id: 'school-1',
      name: 'Özel Yıldız Koleji',
      code: 'YILDIZ2024',
      logoUrl: null,
      status: SchoolStatus.active,
      subscriptionTier: 'premium',
      subscriptionExpiresAt: DateTime.now().add(const Duration(days: 365)),
      settings: {'maxStudents': 500},
      createdAt: DateTime(2024, 1, 1),
      updatedAt: DateTime.now(),
    ),
    School(
      id: 'school-2',
      name: 'Atatürk İlkokulu',
      code: 'ATATURK24',
      logoUrl: null,
      status: SchoolStatus.active,
      subscriptionTier: 'basic',
      subscriptionExpiresAt: DateTime.now().add(const Duration(days: 180)),
      settings: {'maxStudents': 200},
      createdAt: DateTime(2024, 2, 1),
      updatedAt: DateTime.now(),
    ),
  ];

  // Users
  static final users = [
    User(
      id: 'user-1',
      schoolId: 'school-1',
      classId: 'class-5a',
      role: UserRole.student,
      studentNumber: '2024001',
      firstName: 'Ahmet',
      lastName: 'Yılmaz',
      email: 'ahmet@test.com',
      avatarUrl: null,
      xp: 1250,
      level: 8,
      currentStreak: 5,
      longestStreak: 12,
      lastActivityDate: DateTime.now().subtract(const Duration(hours: 2)),
      settings: {'theme': 'light', 'fontSize': 'medium'},
      createdAt: DateTime(2024, 9, 1),
      updatedAt: DateTime.now(),
    ),
    User(
      id: 'user-2',
      schoolId: 'school-1',
      classId: 'class-5a',
      role: UserRole.student,
      studentNumber: '2024002',
      firstName: 'Zeynep',
      lastName: 'Kaya',
      email: 'zeynep@test.com',
      avatarUrl: null,
      xp: 2100,
      level: 12,
      currentStreak: 15,
      longestStreak: 15,
      lastActivityDate: DateTime.now().subtract(const Duration(hours: 5)),
      settings: {'theme': 'dark', 'fontSize': 'large'},
      createdAt: DateTime(2024, 9, 1),
      updatedAt: DateTime.now(),
    ),
    User(
      id: 'user-3',
      schoolId: 'school-1',
      classId: 'class-5a',
      role: UserRole.teacher,
      studentNumber: null,
      firstName: 'Ayşe',
      lastName: 'Öztürk',
      email: 'ayse.ozturk@yildizkoleji.com',
      avatarUrl: null,
      xp: 0,
      level: 1,
      currentStreak: 0,
      longestStreak: 0,
      lastActivityDate: null,
      settings: {},
      createdAt: DateTime(2024, 8, 1),
      updatedAt: DateTime.now(),
    ),
  ];

  // Books
  static final books = [
    Book(
      id: 'book-1',
      title: 'The Little Prince',
      slug: 'the-little-prince',
      description: 'A young prince travels from planet to planet, learning about life, love, and friendship. A timeless classic that speaks to readers of all ages.',
      coverUrl: 'https://covers.openlibrary.org/b/id/8739161-L.jpg',
      level: CEFRLevels.a2,
      genre: 'Fiction',
      ageGroup: 'elementary',
      estimatedMinutes: 45,
      wordCount: 3500,
      chapterCount: 6,
      status: BookStatus.published,
      metadata: {'author': 'Antoine de Saint-Exupéry', 'year': 1943},
      publishedAt: DateTime(2024, 1, 15),
      createdAt: DateTime(2024, 1, 1),
      updatedAt: DateTime.now(),
    ),
    Book(
      id: 'book-2',
      title: 'Charlotte\'s Web',
      slug: 'charlottes-web',
      description: 'The story of a pig named Wilbur and his friendship with a barn spider named Charlotte. A tale about friendship and the circle of life.',
      coverUrl: 'https://covers.openlibrary.org/b/id/8406786-L.jpg',
      level: CEFRLevels.a2,
      genre: 'Fiction',
      ageGroup: 'elementary',
      estimatedMinutes: 60,
      wordCount: 5200,
      chapterCount: 8,
      status: BookStatus.published,
      metadata: {'author': 'E.B. White', 'year': 1952},
      publishedAt: DateTime(2024, 2, 1),
      createdAt: DateTime(2024, 1, 15),
      updatedAt: DateTime.now(),
    ),
    Book(
      id: 'book-3',
      title: 'The Secret Garden',
      slug: 'the-secret-garden',
      description: 'A young orphan discovers a hidden garden and, with the help of new friends, brings it back to life while healing herself in the process.',
      coverUrl: 'https://covers.openlibrary.org/b/id/8231994-L.jpg',
      level: CEFRLevels.b1,
      genre: 'Fiction',
      ageGroup: 'middle',
      estimatedMinutes: 90,
      wordCount: 8000,
      chapterCount: 12,
      status: BookStatus.published,
      metadata: {'author': 'Frances Hodgson Burnett', 'year': 1911},
      publishedAt: DateTime(2024, 3, 1),
      createdAt: DateTime(2024, 2, 15),
      updatedAt: DateTime.now(),
    ),
    Book(
      id: 'book-4',
      title: 'Animal Farm',
      slug: 'animal-farm',
      description: 'A group of farm animals rebel against their human farmer, hoping to create a society where animals can be equal and free.',
      coverUrl: 'https://covers.openlibrary.org/b/id/7984916-L.jpg',
      level: CEFRLevels.b2,
      genre: 'Fiction',
      ageGroup: 'high',
      estimatedMinutes: 120,
      wordCount: 12000,
      chapterCount: 10,
      status: BookStatus.published,
      metadata: {'author': 'George Orwell', 'year': 1945},
      publishedAt: DateTime(2024, 4, 1),
      createdAt: DateTime(2024, 3, 15),
      updatedAt: DateTime.now(),
    ),
    Book(
      id: 'book-5',
      title: 'The Cat in the Hat',
      slug: 'the-cat-in-the-hat',
      description: 'Two children are visited by a mischievous cat who brings chaos and fun to their rainy day at home.',
      coverUrl: 'https://covers.openlibrary.org/b/id/8225261-L.jpg',
      level: CEFRLevels.a1,
      genre: 'Fiction',
      ageGroup: 'elementary',
      estimatedMinutes: 15,
      wordCount: 800,
      chapterCount: 3,
      status: BookStatus.published,
      metadata: {'author': 'Dr. Seuss', 'year': 1957},
      publishedAt: DateTime(2024, 5, 1),
      createdAt: DateTime(2024, 4, 15),
      updatedAt: DateTime.now(),
    ),
    Book(
      id: 'book-6',
      title: 'Wonder',
      slug: 'wonder',
      description: 'August Pullman was born with a facial difference. This is his story about starting school and finding true friendship.',
      coverUrl: 'https://covers.openlibrary.org/b/id/8107708-L.jpg',
      level: CEFRLevels.b1,
      genre: 'Fiction',
      ageGroup: 'middle',
      estimatedMinutes: 150,
      wordCount: 15000,
      chapterCount: 15,
      status: BookStatus.published,
      metadata: {'author': 'R.J. Palacio', 'year': 2012},
      publishedAt: DateTime(2024, 6, 1),
      createdAt: DateTime(2024, 5, 15),
      updatedAt: DateTime.now(),
    ),
  ];

  // Chapters (for "The Little Prince")
  static final chapters = [
    Chapter(
      id: 'chapter-1-1',
      bookId: 'book-1',
      title: 'The Drawing',
      orderIndex: 1,
      content: '''Once when I was six years old I saw a magnificent picture in a book about the jungle. It showed a boa constrictor swallowing an animal.

I pondered deeply over the adventures of the jungle. And after some work with a colored pencil I succeeded in making my first drawing. My Drawing Number One. It looked like this: I showed my masterpiece to the grown-ups, and asked them whether the drawing frightened them.

But they answered: "Frighten? Why should anyone be frightened by a hat?"

My drawing was not a picture of a hat. It was a picture of a boa constrictor digesting an elephant. But since the grown-ups were not able to understand it, I made another drawing. My Drawing Number Two. The grown-ups' response, this time, was to advise me to lay aside my drawings of boa constrictors, and devote myself instead to geography, history, arithmetic, and grammar.

That is why, at the age of six, I gave up what might have been a magnificent career as a painter.''',
      audioUrl: null,
      imageUrls: [],
      wordCount: 180,
      estimatedMinutes: 5,
      vocabulary: [
        const ChapterVocabulary(
          word: 'magnificent',
          meaning: 'muhteşem, görkemli',
          phonetic: '/mæɡˈnɪfɪsənt/',
        ),
        const ChapterVocabulary(
          word: 'boa constrictor',
          meaning: 'boa yılanı',
          phonetic: '/ˈboʊə kənˈstrɪktər/',
        ),
        const ChapterVocabulary(
          word: 'pondered',
          meaning: 'düşündü, kafa yordu',
          phonetic: '/ˈpɒndərd/',
        ),
        const ChapterVocabulary(
          word: 'masterpiece',
          meaning: 'başyapıt, şaheser',
          phonetic: '/ˈmɑːstərpiːs/',
        ),
      ],
      createdAt: DateTime(2024, 1, 1),
      updatedAt: DateTime.now(),
    ),
    Chapter(
      id: 'chapter-1-2',
      bookId: 'book-1',
      title: 'The Pilot',
      orderIndex: 2,
      content: '''So then I chose another profession, and learned to pilot airplanes. I have flown a little over all parts of the world; and it is true that geography has been very useful to me.

At a glance I can distinguish China from Arizona. If one gets lost in the night, such knowledge is valuable.

In the course of this life I have had a great many encounters with a great many people who have been concerned with matters of consequence. I have lived a great deal among grown-ups. I have seen them intimately, close at hand. And that hasn't much improved my opinion of them.

Whenever I met one of them who seemed to me at all clear-sighted, I tried the experiment of showing him my Drawing Number One, which I have always kept. I would try to find out if this was a person of true understanding. But, whoever it was, he or she would always say: "That is a hat."

Then I would never talk to that person about boa constrictors, or primeval forests, or stars. I would bring myself down to his level.''',
      audioUrl: null,
      imageUrls: [],
      wordCount: 200,
      estimatedMinutes: 6,
      vocabulary: [
        const ChapterVocabulary(
          word: 'profession',
          meaning: 'meslek',
          phonetic: '/prəˈfeʃən/',
        ),
        const ChapterVocabulary(
          word: 'distinguish',
          meaning: 'ayırt etmek',
          phonetic: '/dɪˈstɪŋɡwɪʃ/',
        ),
        const ChapterVocabulary(
          word: 'encounters',
          meaning: 'karşılaşmalar',
          phonetic: '/ɪnˈkaʊntərz/',
        ),
        const ChapterVocabulary(
          word: 'consequence',
          meaning: 'önem, sonuç',
          phonetic: '/ˈkɒnsɪkwəns/',
        ),
      ],
      createdAt: DateTime(2024, 1, 1),
      updatedAt: DateTime.now(),
    ),
    Chapter(
      id: 'chapter-1-3',
      bookId: 'book-1',
      title: 'The Little Prince Arrives',
      orderIndex: 3,
      content: '''I lived my life alone, without anyone that I could really talk to, until I had an accident with my plane in the Desert of Sahara, six years ago. Something was broken in my engine.

And as I had with me neither a mechanic nor any passengers, I set myself to attempt the difficult repairs all alone. It was a question of life or death for me: I had scarcely enough drinking water to last a week.

The first night, then, I went to sleep on the sand, a thousand miles from any human habitation. I was more isolated than a shipwrecked sailor on a raft in the middle of the ocean.

Thus you can imagine my amazement, at sunrise, when I was awakened by an odd little voice. It said: "If you please, draw me a sheep!"

"What!"

"Draw me a sheep!"

I jumped to my feet, completely thunderstruck. I blinked my eyes hard. I looked carefully all around me. And I saw a most extraordinary small person, who stood there examining me with great seriousness.''',
      audioUrl: null,
      imageUrls: [],
      wordCount: 210,
      estimatedMinutes: 7,
      vocabulary: [
        const ChapterVocabulary(
          word: 'accident',
          meaning: 'kaza',
          phonetic: '/ˈæksɪdənt/',
        ),
        const ChapterVocabulary(
          word: 'scarcely',
          meaning: 'zar zor, güçlükle',
          phonetic: '/ˈskeəsli/',
        ),
        const ChapterVocabulary(
          word: 'habitation',
          meaning: 'yerleşim yeri',
          phonetic: '/ˌhæbɪˈteɪʃən/',
        ),
        const ChapterVocabulary(
          word: 'amazement',
          meaning: 'şaşkınlık, hayret',
          phonetic: '/əˈmeɪzmənt/',
        ),
        const ChapterVocabulary(
          word: 'thunderstruck',
          meaning: 'şaşkına dönmüş',
          phonetic: '/ˈθʌndəstrʌk/',
        ),
      ],
      createdAt: DateTime(2024, 1, 1),
      updatedAt: DateTime.now(),
    ),
  ];

  // Activities
  static final activities = [
    Activity(
      id: 'activity-1-1',
      chapterId: 'chapter-1-1',
      type: ActivityType.multipleChoice,
      orderIndex: 1,
      title: 'Reading Comprehension',
      instructions: 'Answer the following questions about Chapter 1.',
      questions: [
        const ActivityQuestion(
          id: 'q1',
          question: 'How old was the narrator when he made his first drawing?',
          options: ['Four years old', 'Six years old', 'Eight years old', 'Ten years old'],
          correctAnswer: 'Six years old',
          explanation: 'The text says "Once when I was six years old..."',
          points: 2,
        ),
        const ActivityQuestion(
          id: 'q2',
          question: 'What did the grown-ups think Drawing Number One showed?',
          options: ['An elephant', 'A snake', 'A hat', 'A tree'],
          correctAnswer: 'A hat',
          explanation: 'The grown-ups said: "Why should anyone be frightened by a hat?"',
          points: 2,
        ),
        const ActivityQuestion(
          id: 'q3',
          question: 'What was the drawing actually showing?',
          options: [
            'A boa constrictor digesting an elephant',
            'A hat on a table',
            'A snake eating a mouse',
            'An elephant in the jungle'
          ],
          correctAnswer: 'A boa constrictor digesting an elephant',
          explanation: 'The narrator explains: "It was a picture of a boa constrictor digesting an elephant."',
          points: 2,
        ),
      ],
      settings: {'timeLimit': 300, 'allowRetry': true},
      createdAt: DateTime(2024, 1, 1),
      updatedAt: DateTime.now(),
    ),
    Activity(
      id: 'activity-1-2',
      chapterId: 'chapter-1-1',
      type: ActivityType.trueFalse,
      orderIndex: 2,
      title: 'True or False',
      instructions: 'Decide if each statement is true or false.',
      questions: [
        const ActivityQuestion(
          id: 'tf1',
          question: 'The narrator saw the picture of a boa constrictor in a newspaper.',
          options: ['True', 'False'],
          correctAnswer: 'False',
          explanation: 'He saw it in a book about the jungle, not a newspaper.',
          points: 1,
        ),
        const ActivityQuestion(
          id: 'tf2',
          question: 'The grown-ups advised the narrator to study geography and grammar.',
          options: ['True', 'False'],
          correctAnswer: 'True',
          explanation: 'The text says they advised him "to devote myself instead to geography, history, arithmetic, and grammar."',
          points: 1,
        ),
        const ActivityQuestion(
          id: 'tf3',
          question: 'The narrator continued his career as a painter.',
          options: ['True', 'False'],
          correctAnswer: 'False',
          explanation: 'He says "I gave up what might have been a magnificent career as a painter."',
          points: 1,
        ),
      ],
      settings: {'timeLimit': 180, 'allowRetry': true},
      createdAt: DateTime(2024, 1, 1),
      updatedAt: DateTime.now(),
    ),
  ];

  // Vocabulary Words
  static final vocabularyWords = [
    VocabularyWord(
      id: 'vocab-1',
      word: 'magnificent',
      phonetic: '/mæɡˈnɪfɪsənt/',
      meaningTR: 'muhteşem, görkemli',
      meaningEN: 'extremely beautiful, elaborate, or impressive',
      exampleSentence: 'The view from the mountain was magnificent.',
      audioUrl: null,
      imageUrl: null,
      level: CEFRLevels.b1,
      categories: ['adjectives', 'describing'],
      createdAt: DateTime(2024, 1, 1),
    ),
    VocabularyWord(
      id: 'vocab-2',
      word: 'adventure',
      phonetic: '/ədˈventʃər/',
      meaningTR: 'macera, serüven',
      meaningEN: 'an unusual and exciting experience or activity',
      exampleSentence: 'Reading books is like going on an adventure.',
      audioUrl: null,
      imageUrl: null,
      level: CEFRLevels.a2,
      categories: ['nouns', 'travel'],
      createdAt: DateTime(2024, 1, 1),
    ),
    VocabularyWord(
      id: 'vocab-3',
      word: 'frightened',
      phonetic: '/ˈfraɪtənd/',
      meaningTR: 'korkmuş, ürkmüş',
      meaningEN: 'feeling fear or anxiety',
      exampleSentence: 'The loud noise frightened the little cat.',
      audioUrl: null,
      imageUrl: null,
      level: CEFRLevels.a2,
      categories: ['adjectives', 'emotions'],
      createdAt: DateTime(2024, 1, 1),
    ),
    VocabularyWord(
      id: 'vocab-4',
      word: 'discover',
      phonetic: '/dɪˈskʌvər/',
      meaningTR: 'keşfetmek, bulmak',
      meaningEN: 'to find something for the first time',
      exampleSentence: 'Scientists discover new things every day.',
      audioUrl: null,
      imageUrl: null,
      level: CEFRLevels.a2,
      categories: ['verbs', 'learning'],
      createdAt: DateTime(2024, 1, 1),
    ),
    VocabularyWord(
      id: 'vocab-5',
      word: 'imagination',
      phonetic: '/ɪˌmædʒɪˈneɪʃən/',
      meaningTR: 'hayal gücü',
      meaningEN: 'the ability to form pictures in your mind',
      exampleSentence: 'Children have wonderful imagination.',
      audioUrl: null,
      imageUrl: null,
      level: CEFRLevels.b1,
      categories: ['nouns', 'thinking'],
      createdAt: DateTime(2024, 1, 1),
    ),
    VocabularyWord(
      id: 'vocab-6',
      word: 'journey',
      phonetic: '/ˈdʒɜːrni/',
      meaningTR: 'yolculuk, seyahat',
      meaningEN: 'the act of traveling from one place to another',
      exampleSentence: 'The journey to the mountains took three hours.',
      audioUrl: null,
      imageUrl: null,
      level: CEFRLevels.a2,
      categories: ['nouns', 'travel'],
      createdAt: DateTime(2024, 1, 1),
    ),
    VocabularyWord(
      id: 'vocab-7',
      word: 'mysterious',
      phonetic: '/mɪˈstɪriəs/',
      meaningTR: 'gizemli, esrarengiz',
      meaningEN: 'strange and not known or understood',
      exampleSentence: 'There was a mysterious light in the forest.',
      audioUrl: null,
      imageUrl: null,
      level: CEFRLevels.b1,
      categories: ['adjectives', 'describing'],
      createdAt: DateTime(2024, 1, 1),
    ),
    VocabularyWord(
      id: 'vocab-8',
      word: 'curious',
      phonetic: '/ˈkjʊriəs/',
      meaningTR: 'meraklı',
      meaningEN: 'eager to know or learn something',
      exampleSentence: 'The curious cat explored every room.',
      audioUrl: null,
      imageUrl: null,
      level: CEFRLevels.a2,
      categories: ['adjectives', 'personality'],
      createdAt: DateTime(2024, 1, 1),
    ),
  ];

  // Badges
  static final badges = [
    Badge(
      id: 'badge-1',
      name: 'First Steps',
      slug: 'first-steps',
      description: 'Complete your first chapter',
      icon: '📖',
      category: 'reading',
      conditionType: BadgeConditionType.booksCompleted,
      conditionValue: 1,
      xpReward: 50,
      isActive: true,
      createdAt: DateTime(2024, 1, 1),
    ),
    Badge(
      id: 'badge-2',
      name: 'Bookworm',
      slug: 'bookworm',
      description: 'Complete 5 books',
      icon: '🐛',
      category: 'reading',
      conditionType: BadgeConditionType.booksCompleted,
      conditionValue: 5,
      xpReward: 200,
      isActive: true,
      createdAt: DateTime(2024, 1, 1),
    ),
    Badge(
      id: 'badge-3',
      name: 'Streak Master',
      slug: 'streak-master',
      description: 'Maintain a 7-day reading streak',
      icon: '🔥',
      category: 'streak',
      conditionType: BadgeConditionType.streakDays,
      conditionValue: 7,
      xpReward: 100,
      isActive: true,
      createdAt: DateTime(2024, 1, 1),
    ),
    Badge(
      id: 'badge-4',
      name: 'Vocabulary Champion',
      slug: 'vocabulary-champion',
      description: 'Learn 50 vocabulary words',
      icon: '🏆',
      category: 'vocabulary',
      conditionType: BadgeConditionType.vocabularyLearned,
      conditionValue: 50,
      xpReward: 150,
      isActive: true,
      createdAt: DateTime(2024, 1, 1),
    ),
    Badge(
      id: 'badge-5',
      name: 'Perfect Score',
      slug: 'perfect-score',
      description: 'Get 100% on an activity',
      icon: '⭐',
      category: 'activities',
      conditionType: BadgeConditionType.perfectScores,
      conditionValue: 1,
      xpReward: 75,
      isActive: true,
      createdAt: DateTime(2024, 1, 1),
    ),
    Badge(
      id: 'badge-6',
      name: 'Rising Star',
      slug: 'rising-star',
      description: 'Earn 500 XP',
      icon: '🌟',
      category: 'xp',
      conditionType: BadgeConditionType.xpTotal,
      conditionValue: 500,
      xpReward: 50,
      isActive: true,
      createdAt: DateTime(2024, 1, 1),
    ),
  ];

  // Reading Progress (for user-1)
  static final readingProgress = [
    ReadingProgress(
      id: 'progress-1',
      userId: 'user-1',
      bookId: 'book-1',
      chapterId: 'chapter-1-2',
      currentPage: 2,
      isCompleted: false,
      completionPercentage: 33.3,
      totalReadingTime: 720,
      startedAt: DateTime.now().subtract(const Duration(days: 3)),
      completedAt: null,
      updatedAt: DateTime.now().subtract(const Duration(hours: 2)),
    ),
    ReadingProgress(
      id: 'progress-2',
      userId: 'user-1',
      bookId: 'book-5',
      chapterId: 'chapter-5-3',
      currentPage: 3,
      isCompleted: true,
      completionPercentage: 100,
      totalReadingTime: 900,
      startedAt: DateTime.now().subtract(const Duration(days: 7)),
      completedAt: DateTime.now().subtract(const Duration(days: 5)),
      updatedAt: DateTime.now().subtract(const Duration(days: 5)),
    ),
  ];

  // Vocabulary Progress (for user-1)
  static final vocabularyProgress = [
    VocabularyProgress(
      id: 'vp-1',
      userId: 'user-1',
      wordId: 'vocab-1',
      status: VocabularyStatus.learning,
      easeFactor: 2.5,
      intervalDays: 1,
      repetitions: 1,
      nextReviewAt: DateTime.now().add(const Duration(days: 1)),
      lastReviewedAt: DateTime.now().subtract(const Duration(hours: 12)),
      createdAt: DateTime.now().subtract(const Duration(days: 2)),
    ),
    VocabularyProgress(
      id: 'vp-2',
      userId: 'user-1',
      wordId: 'vocab-2',
      status: VocabularyStatus.reviewing,
      easeFactor: 2.6,
      intervalDays: 6,
      repetitions: 2,
      nextReviewAt: DateTime.now().add(const Duration(days: 3)),
      lastReviewedAt: DateTime.now().subtract(const Duration(days: 3)),
      createdAt: DateTime.now().subtract(const Duration(days: 10)),
    ),
    VocabularyProgress(
      id: 'vp-3',
      userId: 'user-1',
      wordId: 'vocab-3',
      status: VocabularyStatus.mastered,
      easeFactor: 2.8,
      intervalDays: 30,
      repetitions: 5,
      nextReviewAt: DateTime.now().add(const Duration(days: 25)),
      lastReviewedAt: DateTime.now().subtract(const Duration(days: 5)),
      createdAt: DateTime.now().subtract(const Duration(days: 45)),
    ),
  ];

  // Activity Results (for user-1)
  static final activityResults = [
    ActivityResult(
      id: 'result-1',
      userId: 'user-1',
      activityId: 'activity-1-1',
      score: 6,
      maxScore: 6,
      answers: {'q1': 'Six years old', 'q2': 'A hat', 'q3': 'A boa constrictor digesting an elephant'},
      timeSpent: 180,
      attemptNumber: 1,
      completedAt: DateTime.now().subtract(const Duration(days: 2)),
    ),
  ];

  // User Badges (for user-1)
  static final userBadges = [
    UserBadge(
      id: 'ub-1',
      odId: 'user-1',
      badgeId: 'badge-1',
      badge: badges[0],
      earnedAt: DateTime.now().subtract(const Duration(days: 5)),
    ),
    UserBadge(
      id: 'ub-2',
      odId: 'user-1',
      badgeId: 'badge-5',
      badge: badges[4],
      earnedAt: DateTime.now().subtract(const Duration(days: 2)),
    ),
    UserBadge(
      id: 'ub-3',
      odId: 'user-1',
      badgeId: 'badge-6',
      badge: badges[5],
      earnedAt: DateTime.now().subtract(const Duration(days: 10)),
    ),
  ];
}
