import 'package:flutter/material.dart';

/// Shared image widget for session questions.
/// Shows the word image if available, otherwise a gradient placeholder.
class QuestionImage extends StatelessWidget {
  const QuestionImage({
    super.key,
    required this.imageUrl,
    this.size = 80,
  });

  final String? imageUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasImage = imageUrl != null && imageUrl!.isNotEmpty;

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: hasImage
          ? Image.network(
              imageUrl!,
              height: size,
              width: size,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _placeholder(theme),
            )
          : _placeholder(theme),
    );
  }

  Widget _placeholder(ThemeData theme) {
    return Container(
      height: size,
      width: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primaryContainer,
            theme.colorScheme.tertiaryContainer,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(
        Icons.image_rounded,
        size: size * 0.4,
        color: theme.colorScheme.primary.withValues(alpha: 0.4),
      ),
    );
  }
}
