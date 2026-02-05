import 'package:flutter/material.dart';
import 'package:widgetbook/widgetbook.dart';

import 'package:readeng/presentation/widgets/book/level_badge.dart';
import 'package:readeng/presentation/widgets/book/book_grid_card.dart';
import 'package:readeng/presentation/widgets/book/book_list_tile.dart';
import 'package:readeng/domain/entities/book.dart';

/// Book widgets for Widgetbook
final bookWidgets = [
  // Level Badge
  WidgetbookComponent(
    name: 'LevelBadge',
    useCases: [
      WidgetbookUseCase(
        name: 'All Levels',
        builder: (context) => const Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            LevelBadge(level: 'A1'),
            LevelBadge(level: 'A2'),
            LevelBadge(level: 'B1'),
            LevelBadge(level: 'B2'),
            LevelBadge(level: 'C1'),
            LevelBadge(level: 'C2'),
          ],
        ),
      ),
      WidgetbookUseCase(
        name: 'All Sizes',
        builder: (context) => const Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            LevelBadge(level: 'B1', size: LevelBadgeSize.small),
            LevelBadge(level: 'B1', size: LevelBadgeSize.medium),
            LevelBadge(level: 'B1', size: LevelBadgeSize.large),
          ],
        ),
      ),
      WidgetbookUseCase(
        name: 'With Knobs',
        builder: (context) => LevelBadge(
          level: context.knobs.string(
            label: 'Level',
            initialValue: 'B1',
          ),
          size: context.knobs.boolean(
            label: 'Large Size',
            initialValue: false,
          ) ? LevelBadgeSize.large : LevelBadgeSize.medium,
        ),
      ),
    ],
  ),

  // Book Grid Card
  WidgetbookComponent(
    name: 'BookGridCard',
    useCases: [
      WidgetbookUseCase(
        name: 'Default',
        builder: (context) => SizedBox(
          width: 160,
          height: 240,
          child: BookGridCard(
            book: _mockBook,
            onTap: () {},
          ),
        ),
      ),
      WidgetbookUseCase(
        name: 'Locked',
        builder: (context) => SizedBox(
          width: 160,
          height: 240,
          child: BookGridCard(
            book: _mockBook,
            onTap: () {},
            showLockIcon: true,
          ),
        ),
      ),
      WidgetbookUseCase(
        name: 'No Cover',
        builder: (context) => SizedBox(
          width: 160,
          height: 240,
          child: BookGridCard(
            book: _mockBookNoCover,
            onTap: () {},
          ),
        ),
      ),
    ],
  ),

  // Book List Tile
  WidgetbookComponent(
    name: 'BookListTile',
    useCases: [
      WidgetbookUseCase(
        name: 'Default',
        builder: (context) => BookListTile(
          book: _mockBook,
          onTap: () {},
        ),
      ),
      WidgetbookUseCase(
        name: 'Locked',
        builder: (context) => BookListTile(
          book: _mockBook,
          onTap: () {},
          showLockIcon: true,
        ),
      ),
      WidgetbookUseCase(
        name: 'No Cover',
        builder: (context) => BookListTile(
          book: _mockBookNoCover,
          onTap: () {},
        ),
      ),
    ],
  ),
];

// Mock data
final _mockBook = Book(
  id: '1',
  title: 'The Magic Garden',
  slug: 'the-magic-garden',
  description: 'A magical adventure through an enchanted garden.',
  coverUrl: 'https://images.unsplash.com/photo-1490750967868-88aa4486c946?w=400',
  level: 'A1',
  genre: 'Fiction',
  ageGroup: 'elementary',
  estimatedMinutes: 20,
  wordCount: 1200,
  chapterCount: 3,
  status: BookStatus.published,
  metadata: {'author': 'Emma Stories'},
  createdAt: DateTime.now(),
  updatedAt: DateTime.now(),
);

final _mockBookNoCover = Book(
  id: '2',
  title: 'Space Adventure',
  slug: 'space-adventure',
  description: 'Journey through the solar system.',
  coverUrl: null,
  level: 'B2',
  genre: 'Fiction',
  ageGroup: 'middle',
  estimatedMinutes: 30,
  wordCount: 2000,
  chapterCount: 5,
  status: BookStatus.published,
  metadata: {'author': 'Star Writer'},
  createdAt: DateTime.now(),
  updatedAt: DateTime.now(),
);
