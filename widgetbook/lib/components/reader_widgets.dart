import 'package:flutter/material.dart';
import 'package:widgetbook/widgetbook.dart';

import 'package:readeng/presentation/widgets/reader/chapter_navigation_bar.dart';
import 'package:readeng/presentation/widgets/reader/chapter_completion_card.dart';
import 'package:readeng/presentation/widgets/reader/collapsible_reader_header.dart';
import 'package:readeng/presentation/widgets/reader/image_block_widget.dart';
import 'package:readeng/presentation/widgets/reader/paragraph_widget.dart';
import 'package:readeng/presentation/widgets/reader/word_highlight_text.dart';
import 'package:readeng/presentation/widgets/reader/vocabulary_popup.dart';
import 'package:readeng/presentation/providers/reader_provider.dart';
import 'package:readeng/domain/entities/book.dart';
import 'package:readeng/domain/entities/chapter.dart';
import 'package:readeng/domain/entities/content/content_block.dart';

/// Reader widgets for Widgetbook
final readerWidgets = [
  // Chapter Navigation Bar
  WidgetbookComponent(
    name: 'ChapterNavigationBar',
    useCases: [
      WidgetbookUseCase(
        name: 'First Chapter',
        builder: (context) => const ChapterNavigationBar(
          chapterNumber: 1,
          totalChapters: 5,
          scrollProgress: 0.3,
          onPrevious: null,
          onNext: null,
          onComplete: null,
          hasPrevious: false,
          hasNext: true,
          isLastChapter: false,
        ),
      ),
      WidgetbookUseCase(
        name: 'Middle Chapter',
        builder: (context) => const ChapterNavigationBar(
          chapterNumber: 3,
          totalChapters: 5,
          scrollProgress: 0.6,
          onPrevious: null,
          onNext: null,
          onComplete: null,
          hasPrevious: true,
          hasNext: true,
          isLastChapter: false,
        ),
      ),
      WidgetbookUseCase(
        name: 'Last Chapter - Complete Button',
        builder: (context) => const ChapterNavigationBar(
          chapterNumber: 5,
          totalChapters: 5,
          scrollProgress: 0.95,
          onPrevious: null,
          onNext: null,
          onComplete: null,
          hasPrevious: true,
          hasNext: false,
          isLastChapter: true,
        ),
      ),
      WidgetbookUseCase(
        name: 'With Knobs',
        builder: (context) => ChapterNavigationBar(
          chapterNumber: context.knobs.int.slider(
            label: 'Chapter',
            initialValue: 2,
            min: 1,
            max: 10,
          ),
          totalChapters: 10,
          scrollProgress: context.knobs.double.slider(
            label: 'Progress',
            initialValue: 0.5,
            min: 0,
            max: 1,
          ),
          onPrevious: () {},
          onNext: () {},
          onComplete: () {},
          hasPrevious: true,
          hasNext: true,
          isLastChapter: context.knobs.boolean(
            label: 'Is Last Chapter',
            initialValue: false,
          ),
        ),
      ),
    ],
  ),

  // Chapter Completion Card
  WidgetbookComponent(
    name: 'ChapterCompletionCard',
    useCases: [
      WidgetbookUseCase(
        name: 'Has Next Chapter',
        builder: (context) => Container(
          padding: const EdgeInsets.all(16),
          color: _lightSettings.theme.background,
          child: ChapterCompletionCard(
            hasNextChapter: true,
            nextChapter: _mockChapter,
            settings: _lightSettings,
            sessionXP: 25,
            onNextChapter: () {},
            onBackToBook: () {},
          ),
        ),
      ),
      WidgetbookUseCase(
        name: 'Book Complete',
        builder: (context) => Container(
          padding: const EdgeInsets.all(16),
          color: _lightSettings.theme.background,
          child: ChapterCompletionCard(
            hasNextChapter: false,
            nextChapter: null,
            settings: _lightSettings,
            sessionXP: 100,
            onNextChapter: () {},
            onBackToBook: () {},
          ),
        ),
      ),
      WidgetbookUseCase(
        name: 'Dark Theme',
        builder: (context) => Container(
          padding: const EdgeInsets.all(16),
          color: _darkSettings.theme.background,
          child: ChapterCompletionCard(
            hasNextChapter: false,
            nextChapter: null,
            settings: _darkSettings,
            sessionXP: 75,
            onNextChapter: () {},
            onBackToBook: () {},
          ),
        ),
      ),
    ],
  ),

  // Collapsible Reader Header
  WidgetbookComponent(
    name: 'CollapsibleReaderHeader',
    useCases: [
      WidgetbookUseCase(
        name: 'Expanded (400px)',
        builder: (context) => SizedBox(
          height: 400,
          child: CollapsibleReaderHeader(
            book: _mockBook,
            chapter: _mockChapter,
            chapterNumber: 1,
            scrollProgress: 0.3,
            sessionXP: 15,
            readingTimeSeconds: 180,
            backgroundColor: _lightSettings.theme.background,
            textColor: _lightSettings.theme.text,
            onClose: () {},
            onSettingsTap: () {},
          ),
        ),
      ),
      WidgetbookUseCase(
        name: 'Collapsed (100px)',
        builder: (context) => SizedBox(
          height: 100,
          child: CollapsibleReaderHeader(
            book: _mockBook,
            chapter: _mockChapter,
            chapterNumber: 2,
            scrollProgress: 0.65,
            sessionXP: 30,
            readingTimeSeconds: 420,
            backgroundColor: _lightSettings.theme.background,
            textColor: _lightSettings.theme.text,
            onClose: () {},
            onSettingsTap: () {},
          ),
        ),
      ),
      WidgetbookUseCase(
        name: 'Dark Theme',
        builder: (context) => SizedBox(
          height: 400,
          child: CollapsibleReaderHeader(
            book: _mockBook,
            chapter: _mockChapter,
            chapterNumber: 1,
            scrollProgress: 0.5,
            sessionXP: 20,
            readingTimeSeconds: 300,
            backgroundColor: _darkSettings.theme.background,
            textColor: _darkSettings.theme.text,
            onClose: () {},
            onSettingsTap: () {},
          ),
        ),
      ),
    ],
  ),

  // Image Block Widget
  WidgetbookComponent(
    name: 'ImageBlockWidget',
    useCases: [
      WidgetbookUseCase(
        name: 'With Image',
        builder: (context) => Container(
          padding: const EdgeInsets.all(16),
          color: _lightSettings.theme.background,
          child: ImageBlockWidget(
            block: _mockImageBlock,
            settings: _lightSettings,
          ),
        ),
      ),
      WidgetbookUseCase(
        name: 'With Caption',
        builder: (context) => Container(
          padding: const EdgeInsets.all(16),
          color: _lightSettings.theme.background,
          child: ImageBlockWidget(
            block: _mockImageBlockWithCaption,
            settings: _lightSettings,
          ),
        ),
      ),
      WidgetbookUseCase(
        name: 'Dark Theme',
        builder: (context) => Container(
          padding: const EdgeInsets.all(16),
          color: _darkSettings.theme.background,
          child: ImageBlockWidget(
            block: _mockImageBlockWithCaption,
            settings: _darkSettings,
          ),
        ),
      ),
    ],
  ),

  // Paragraph Widget
  WidgetbookComponent(
    name: 'ParagraphWidget',
    useCases: [
      WidgetbookUseCase(
        name: 'Plain Text',
        builder: (context) => Container(
          padding: const EdgeInsets.all(16),
          color: _lightSettings.theme.background,
          child: ParagraphWidget(
            content: _sampleParagraph,
            vocabulary: const [],
            settings: _lightSettings,
            onVocabularyTap: (vocab, position) {},
          ),
        ),
      ),
      WidgetbookUseCase(
        name: 'With Vocabulary',
        builder: (context) => Container(
          padding: const EdgeInsets.all(16),
          color: _lightSettings.theme.background,
          child: ParagraphWidget(
            content: _sampleParagraph,
            vocabulary: _mockVocabulary,
            settings: _lightSettings,
            onVocabularyTap: (vocab, position) {},
          ),
        ),
      ),
      WidgetbookUseCase(
        name: 'Dark Theme',
        builder: (context) => Container(
          padding: const EdgeInsets.all(16),
          color: _darkSettings.theme.background,
          child: ParagraphWidget(
            content: _sampleParagraph,
            vocabulary: _mockVocabulary,
            settings: _darkSettings,
            onVocabularyTap: (vocab, position) {},
          ),
        ),
      ),
      WidgetbookUseCase(
        name: 'Large Font',
        builder: (context) => Container(
          padding: const EdgeInsets.all(16),
          color: _lightSettings.theme.background,
          child: ParagraphWidget(
            content: _sampleParagraph,
            vocabulary: _mockVocabulary,
            settings: _largeFontSettings,
            onVocabularyTap: (vocab, position) {},
          ),
        ),
      ),
    ],
  ),

  // Word Highlight Text
  WidgetbookComponent(
    name: 'WordHighlightText',
    useCases: [
      WidgetbookUseCase(
        name: 'No Highlight',
        builder: (context) => Container(
          padding: const EdgeInsets.all(16),
          color: _lightSettings.theme.background,
          child: WordHighlightText(
            text: _sampleSentence,
            wordTimings: _mockWordTimings,
            settings: _lightSettings,
            activeWordIndex: null,
          ),
        ),
      ),
      WidgetbookUseCase(
        name: 'Word 3 Active',
        builder: (context) => Container(
          padding: const EdgeInsets.all(16),
          color: _lightSettings.theme.background,
          child: WordHighlightText(
            text: _sampleSentence,
            wordTimings: _mockWordTimings,
            settings: _lightSettings,
            activeWordIndex: 2,
          ),
        ),
      ),
      WidgetbookUseCase(
        name: 'With Vocabulary',
        builder: (context) => Container(
          padding: const EdgeInsets.all(16),
          color: _lightSettings.theme.background,
          child: WordHighlightText(
            text: _sampleSentence,
            wordTimings: _mockWordTimings,
            settings: _lightSettings,
            activeWordIndex: 4,
            vocabulary: _mockSentenceVocabulary,
            onVocabularyTap: (vocab, position) {},
          ),
        ),
      ),
      WidgetbookUseCase(
        name: 'Dark Theme',
        builder: (context) => Container(
          padding: const EdgeInsets.all(16),
          color: _darkSettings.theme.background,
          child: WordHighlightText(
            text: _sampleSentence,
            wordTimings: _mockWordTimings,
            settings: _darkSettings,
            activeWordIndex: 3,
            vocabulary: _mockSentenceVocabulary,
            onVocabularyTap: (vocab, position) {},
          ),
        ),
      ),
    ],
  ),

  // Translate Button
  WidgetbookComponent(
    name: 'TranslateButton',
    useCases: [
      WidgetbookUseCase(
        name: 'Light Theme',
        builder: (context) => Container(
          padding: const EdgeInsets.all(16),
          color: _lightSettings.theme.background,
          child: TranslateButton(
            onPressed: () {},
            settings: _lightSettings,
          ),
        ),
      ),
      WidgetbookUseCase(
        name: 'Dark Theme',
        builder: (context) => Container(
          padding: const EdgeInsets.all(16),
          color: _darkSettings.theme.background,
          child: TranslateButton(
            onPressed: () {},
            settings: _darkSettings,
          ),
        ),
      ),
    ],
  ),

  // Vocabulary Popup
  WidgetbookComponent(
    name: 'VocabularyPopup',
    useCases: [
      WidgetbookUseCase(
        name: 'With Meaning',
        builder: (context) => SizedBox(
          width: 400,
          height: 400,
          child: VocabularyPopup(
            vocabulary: const ChapterVocabulary(
              word: 'beautiful',
              meaning: 'very attractive or pleasing; having beauty',
              phonetic: '/ˈbjuːtɪfəl/',
            ),
            position: const Offset(200, 150),
            onClose: () {},
            onAddToVocabulary: () {},
          ),
        ),
      ),
      WidgetbookUseCase(
        name: 'Without Phonetic',
        builder: (context) => SizedBox(
          width: 400,
          height: 400,
          child: VocabularyPopup(
            vocabulary: const ChapterVocabulary(
              word: 'garden',
              meaning: 'a piece of ground used to grow flowers, vegetables, or fruit',
            ),
            position: const Offset(200, 150),
            onClose: () {},
            onAddToVocabulary: () {},
          ),
        ),
      ),
      WidgetbookUseCase(
        name: 'Without Add Button',
        builder: (context) => SizedBox(
          width: 400,
          height: 400,
          child: VocabularyPopup(
            vocabulary: const ChapterVocabulary(
              word: 'magical',
              meaning: 'having special powers; enchanting',
              phonetic: '/ˈmædʒɪkəl/',
            ),
            position: const Offset(200, 150),
            onClose: () {},
          ),
        ),
      ),
    ],
  ),
];

// ============================================
// Mock Data
// ============================================

// Reader Settings
const _lightSettings = ReaderSettings(
  fontSize: 18,
  lineHeight: 1.6,
  theme: ReaderTheme.light,
  showVocabularyHighlights: true,
);

const _darkSettings = ReaderSettings(
  fontSize: 18,
  lineHeight: 1.6,
  theme: ReaderTheme.dark,
  showVocabularyHighlights: true,
);

const _largeFontSettings = ReaderSettings(
  fontSize: 24,
  lineHeight: 1.8,
  theme: ReaderTheme.light,
  showVocabularyHighlights: true,
);

// Mock Book
final _mockBook = Book(
  id: 'book-1',
  title: 'The Magic Garden',
  slug: 'the-magic-garden',
  description: 'A magical adventure through an enchanted garden.',
  coverUrl: 'https://images.unsplash.com/photo-1490750967868-88aa4486c946?w=400',
  level: 'A1',
  genre: 'Fiction',
  ageGroup: 'elementary',
  estimatedMinutes: 20,
  wordCount: 1200,
  chapterCount: 5,
  status: BookStatus.published,
  metadata: {'author': 'Emma Stories'},
  createdAt: DateTime.now(),
  updatedAt: DateTime.now(),
);

// Mock Chapter
final _mockChapter = Chapter(
  id: 'chapter-1',
  bookId: 'book-1',
  title: 'The Secret Path',
  orderIndex: 0,
  content: _sampleParagraph,
  audioUrl: 'https://example.com/audio.mp3',
  imageUrls: ['https://images.unsplash.com/photo-1490750967868-88aa4486c946?w=200'],
  wordCount: 250,
  estimatedMinutes: 5,
  vocabulary: _mockVocabulary,
  createdAt: DateTime.now(),
  updatedAt: DateTime.now(),
);

// Sample text content
const _sampleParagraph = '''
The beautiful garden was full of colorful flowers and tall green trees. A small bird sang a happy song from the highest branch. Emma walked slowly along the winding path, enjoying the warm sunshine on her face. She discovered a magical fountain hidden behind the rose bushes.
''';

const _sampleSentence = 'The beautiful garden was full of colorful flowers.';

// Mock vocabulary for paragraph
const _mockVocabulary = [
  ChapterVocabulary(
    word: 'beautiful',
    meaning: 'very attractive or pleasing',
    phonetic: '/ˈbjuːtɪfəl/',
  ),
  ChapterVocabulary(
    word: 'colorful',
    meaning: 'having many bright colors',
    phonetic: '/ˈkʌlərfəl/',
  ),
  ChapterVocabulary(
    word: 'magical',
    meaning: 'having special powers; enchanting',
    phonetic: '/ˈmædʒɪkəl/',
  ),
];

// Mock vocabulary for sentence
const _mockSentenceVocabulary = [
  ChapterVocabulary(
    word: 'beautiful',
    meaning: 'very attractive or pleasing',
    phonetic: '/ˈbjuːtɪfəl/',
  ),
  ChapterVocabulary(
    word: 'colorful',
    meaning: 'having many bright colors',
    phonetic: '/ˈkʌlərfəl/',
  ),
];

// Mock word timings for sentence: "The beautiful garden was full of colorful flowers."
const _mockWordTimings = [
  WordTiming(word: 'The', startIndex: 0, endIndex: 3, startMs: 0, endMs: 200),
  WordTiming(word: 'beautiful', startIndex: 4, endIndex: 13, startMs: 200, endMs: 600),
  WordTiming(word: 'garden', startIndex: 14, endIndex: 20, startMs: 600, endMs: 900),
  WordTiming(word: 'was', startIndex: 21, endIndex: 24, startMs: 900, endMs: 1100),
  WordTiming(word: 'full', startIndex: 25, endIndex: 29, startMs: 1100, endMs: 1300),
  WordTiming(word: 'of', startIndex: 30, endIndex: 32, startMs: 1300, endMs: 1400),
  WordTiming(word: 'colorful', startIndex: 33, endIndex: 41, startMs: 1400, endMs: 1800),
  WordTiming(word: 'flowers.', startIndex: 42, endIndex: 50, startMs: 1800, endMs: 2200),
];

// Mock content blocks
final _mockImageBlock = ContentBlock(
  id: 'block-img-1',
  chapterId: 'chapter-1',
  orderIndex: 1,
  type: ContentBlockType.image,
  imageUrl: 'https://images.unsplash.com/photo-1490750967868-88aa4486c946?w=600',
  caption: null,
  createdAt: DateTime.now(),
  updatedAt: DateTime.now(),
);

final _mockImageBlockWithCaption = ContentBlock(
  id: 'block-img-2',
  chapterId: 'chapter-1',
  orderIndex: 2,
  type: ContentBlockType.image,
  imageUrl: 'https://images.unsplash.com/photo-1490750967868-88aa4486c946?w=600',
  caption: 'A beautiful garden with colorful flowers',
  createdAt: DateTime.now(),
  updatedAt: DateTime.now(),
);
