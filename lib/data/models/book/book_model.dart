import '../../../domain/entities/book.dart';

/// Data model for Book - handles JSON serialization
class BookModel {

  const BookModel({
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

  factory BookModel.fromJson(Map<String, dynamic> json) {
    return BookModel(
      id: json['id'] as String,
      title: json['title'] as String,
      slug: json['slug'] as String,
      description: json['description'] as String?,
      coverUrl: json['cover_url'] as String?,
      level: json['level'] as String,
      genre: json['genre'] as String?,
      ageGroup: json['age_group'] as String?,
      estimatedMinutes: json['estimated_minutes'] as int?,
      wordCount: json['word_count'] as int?,
      chapterCount: json['chapter_count'] as int? ?? 0,
      status: _parseBookStatus(json['status'] as String?),
      metadata: (json['metadata'] as Map<String, dynamic>?) ?? {},
      publishedAt: json['published_at'] != null
          ? DateTime.parse(json['published_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  factory BookModel.fromEntity(Book entity) {
    return BookModel(
      id: entity.id,
      title: entity.title,
      slug: entity.slug,
      description: entity.description,
      coverUrl: entity.coverUrl,
      level: entity.level,
      genre: entity.genre,
      ageGroup: entity.ageGroup,
      estimatedMinutes: entity.estimatedMinutes,
      wordCount: entity.wordCount,
      chapterCount: entity.chapterCount,
      status: entity.status,
      metadata: entity.metadata,
      publishedAt: entity.publishedAt,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
    );
  }
  final String id;
  final String title;
  final String slug;
  final String? description;
  final String? coverUrl;
  final String level;
  final String? genre;
  final String? ageGroup;
  final int? estimatedMinutes;
  final int? wordCount;
  final int chapterCount;
  final BookStatus status;
  final Map<String, dynamic> metadata;
  final DateTime? publishedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'slug': slug,
      'description': description,
      'cover_url': coverUrl,
      'level': level,
      'genre': genre,
      'age_group': ageGroup,
      'estimated_minutes': estimatedMinutes,
      'word_count': wordCount,
      'chapter_count': chapterCount,
      'status': status.name,
      'metadata': metadata,
      'published_at': publishedAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  Book toEntity() {
    return Book(
      id: id,
      title: title,
      slug: slug,
      description: description,
      coverUrl: coverUrl,
      level: level,
      genre: genre,
      ageGroup: ageGroup,
      estimatedMinutes: estimatedMinutes,
      wordCount: wordCount,
      chapterCount: chapterCount,
      status: status,
      metadata: metadata,
      publishedAt: publishedAt,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  static BookStatus _parseBookStatus(String? status) {
    switch (status) {
      case 'published':
        return BookStatus.published;
      case 'archived':
        return BookStatus.archived;
      default:
        return BookStatus.draft;
    }
  }
}
