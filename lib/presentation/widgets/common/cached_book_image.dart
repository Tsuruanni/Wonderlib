import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/file_cache_service.dart';

/// A cache-aware image widget for book cover art and other book-related images.
///
/// Checks if the remote URL has a locally cached file via [FileCacheService].
/// If a local file exists it renders from disk (no network), otherwise falls
/// back to [CachedNetworkImage] so the image is still shown while offline
/// mode is not fully downloaded.
///
/// Usage:
/// ```dart
/// CachedBookImage(
///   imageUrl: book.coverImageUrl,
///   width: 80,
///   height: 120,
///   fit: BoxFit.cover,
/// )
/// ```
class CachedBookImage extends ConsumerWidget {
  const CachedBookImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.errorWidget,
  });

  final String? imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;

  /// Widget shown while the image is loading. Defaults to a [CircularProgressIndicator].
  final Widget? placeholder;

  /// Widget shown when the image fails to load. Defaults to a broken-image icon.
  final Widget? errorWidget;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (imageUrl == null || imageUrl!.isEmpty) {
      return _sizedBox(errorWidget ?? _defaultError(context));
    }

    final fileCacheService = ref.watch(fileCacheServiceProvider);

    return FutureBuilder<String>(
      future: fileCacheService.resolveUrl(imageUrl!),
      builder: (context, snapshot) {
        final resolved = snapshot.data ?? imageUrl!;

        if (resolved.startsWith('/')) {
          // Local file path — render directly from disk.
          return _sizedBox(
            Image.file(
              File(resolved),
              width: width,
              height: height,
              fit: fit,
              errorBuilder: (_, __, ___) =>
                  _sizedBox(errorWidget ?? _defaultError(context)),
            ),
          );
        }

        // Remote URL — use CachedNetworkImage so it is still shown while the
        // offline download is pending.
        return _sizedBox(
          CachedNetworkImage(
            imageUrl: resolved,
            width: width,
            height: height,
            fit: fit,
            placeholder: (_, __) =>
                placeholder ?? _defaultPlaceholder(context),
            errorWidget: (_, __, ___) =>
                errorWidget ?? _defaultError(context),
          ),
        );
      },
    );
  }

  Widget _sizedBox(Widget child) {
    if (width == null && height == null) return child;
    return SizedBox(width: width, height: height, child: child);
  }

  Widget _defaultPlaceholder(BuildContext context) {
    return Container(
      width: width,
      height: height,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: const Center(
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    );
  }

  Widget _defaultError(BuildContext context) {
    return Container(
      width: width,
      height: height,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Icon(
        Icons.broken_image_outlined,
        color: Theme.of(context).colorScheme.outline,
      ),
    );
  }
}
