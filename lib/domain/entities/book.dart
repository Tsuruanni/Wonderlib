import 'package:equatable/equatable.dart';

enum BookStatus { draft, published, archived }

class Book extends Equatable {

  const Book({
    required this.id,
    required this.title,
    required this.slug,
    this.description,
    this.coverUrl,
    required this.level,
    this.genre,
    this.ageGroup,
    this.estimatedMinutes,
    this.wordCount,
    this.chapterCount = 0,
    this.status = BookStatus.draft,
    this.metadata = const {},
    this.publishedAt,
    required this.createdAt,
    required this.updatedAt,
  });
  final String id;
  final String title;
  final String slug;
  final String? description;
  final String? coverUrl;
  final String level; // CEFR level: A1, A2, B1, B2, C1, C2
  final String? genre;
  final String? ageGroup; // elementary, middle, high
  final int? estimatedMinutes;
  final int? wordCount;
  final int chapterCount;
  final BookStatus status;
  final Map<String, dynamic> metadata;
  final DateTime? publishedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isPublished => status == BookStatus.published;
  bool get isDraft => status == BookStatus.draft;
  bool get isArchived => status == BookStatus.archived;

  String get readingTime {
    if (estimatedMinutes == null) return '';
    if (estimatedMinutes! < 60) return '$estimatedMinutes min';
    final hours = estimatedMinutes! ~/ 60;
    final mins = estimatedMinutes! % 60;
    return mins > 0 ? '${hours}h ${mins}m' : '${hours}h';
  }

  @override
  List<Object?> get props => [
        id,
        title,
        slug,
        description,
        coverUrl,
        level,
        genre,
        ageGroup,
        estimatedMinutes,
        wordCount,
        chapterCount,
        status,
        metadata,
        publishedAt,
        createdAt,
        updatedAt,
      ];
}
