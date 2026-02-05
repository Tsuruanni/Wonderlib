import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../domain/entities/content/content_block.dart';
import '../../providers/reader_provider.dart';

/// Widget for rendering an image content block.
/// Shows the image with optional caption below.
class ImageBlockWidget extends StatelessWidget {
  const ImageBlockWidget({
    super.key,
    required this.block,
    required this.settings,
  });

  final ContentBlock block;
  final ReaderSettings settings;

  @override
  Widget build(BuildContext context) {
    final imageUrl = block.imageUrl;
    if (imageUrl == null || imageUrl.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Image with rounded corners
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: CachedNetworkImage(
              imageUrl: imageUrl,
              fit: BoxFit.cover,
              placeholder: (context, url) => _buildPlaceholder(),
              errorWidget: (context, url, error) => _buildErrorWidget(),
            ),
          ),

          // Caption if available
          if (block.caption != null && block.caption!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              block.caption!,
              style: TextStyle(
                fontSize: settings.fontSize * 0.85,
                fontStyle: FontStyle.italic,
                color: settings.theme.text.withValues(alpha: 0.7),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      height: 200,
      color: settings.theme.text.withValues(alpha: 0.1),
      child: Center(
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: settings.theme.text.withValues(alpha: 0.5),
        ),
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Container(
      height: 200,
      color: settings.theme.text.withValues(alpha: 0.1),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.broken_image_outlined,
              size: 48,
              color: settings.theme.text.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 8),
            Text(
              'Image failed to load',
              style: TextStyle(
                color: settings.theme.text.withValues(alpha: 0.5),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
