import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/theme.dart';
import '../../../core/utils/extensions/context_extensions.dart';
import '../../providers/book_download_provider.dart';
import '../../widgets/common/cached_book_image.dart';

class DownloadedBooksScreen extends ConsumerWidget {
  const DownloadedBooksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final downloadedAsync = ref.watch(downloadedBooksProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'Downloaded Books',
          style: GoogleFonts.nunito(
            fontWeight: FontWeight.bold,
            color: AppColors.neutralText,
            letterSpacing: 1.0,
          ),
        ),
        centerTitle: true,
        backgroundColor: AppColors.background,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.primary),
      ),
      body: downloadedAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Text(
            'Failed to load downloads',
            style: GoogleFonts.nunito(color: AppColors.neutralText),
          ),
        ),
        data: (books) {
          if (books.isEmpty) {
            return _EmptyState();
          }

          final totalBytes = books.fold<int>(
            0,
            (sum, b) => sum + b.fileSizeBytes,
          );
          final totalFormatted = _formatTotalSize(totalBytes);

          return Column(
            children: [
              // Storage summary banner
              _StorageBanner(totalFormatted: totalFormatted, count: books.length),

              // Book list
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  itemCount: books.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final info = books[index];
                    return _DownloadedBookTile(info: info);
                  },
                ),
              ),

              // Remove all button
              Padding(
                padding: const EdgeInsets.all(16),
                child: _RemoveAllButton(books: books),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Formats the total storage sum for the banner. Per-item size uses
  /// [DownloadedBookInfo.formattedSize] instead.
  String _formatTotalSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

// ---------------------------------------------------------------------------
// Storage Banner
// ---------------------------------------------------------------------------

class _StorageBanner extends StatelessWidget {
  const _StorageBanner({
    required this.totalFormatted,
    required this.count,
  });

  final String totalFormatted;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.secondaryBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.secondary.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.secondary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.storage_rounded,
              color: AppColors.secondary,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$count book${count == 1 ? '' : 's'} downloaded',
                  style: GoogleFonts.nunito(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: AppColors.black,
                  ),
                ),
                Text(
                  'Total storage used: $totalFormatted',
                  style: GoogleFonts.nunito(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: AppColors.neutralText,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Individual downloaded book tile
// ---------------------------------------------------------------------------

class _DownloadedBookTile extends ConsumerWidget {
  const _DownloadedBookTile({required this.info});

  final DownloadedBookInfo info;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final book = info.book;

    // Parse cachedAt to a readable date
    final cachedDate = _parseCachedAt(info.cachedAt);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.neutral, width: 2),
        boxShadow: [
          BoxShadow(
            color: AppColors.neutral,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cover image
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: CachedBookImage(
              imageUrl: book.coverUrl,
              width: 56,
              height: 80,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 12),

          // Book info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  book.title,
                  style: GoogleFonts.nunito(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: AppColors.black,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    _MetaChip(
                      icon: Icons.menu_book_rounded,
                      label: '${book.chapterCount} chapter${book.chapterCount == 1 ? '' : 's'}',
                    ),
                    const SizedBox(width: 8),
                    _MetaChip(
                      icon: Icons.folder_rounded,
                      label: info.formattedSize,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Cached: $cachedDate',
                  style: GoogleFonts.nunito(
                    fontSize: 11,
                    color: AppColors.neutralText,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                // Remove button
                SizedBox(
                  height: 32,
                  child: OutlinedButton.icon(
                    onPressed: () =>
                        _confirmRemove(context, ref, book.title),
                    icon: const Icon(Icons.delete_outline_rounded, size: 16),
                    label: Text(
                      'Remove Download',
                      style: GoogleFonts.nunito(
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.danger,
                      side: BorderSide(
                        color: AppColors.danger.withValues(alpha: 0.5),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmRemove(
    BuildContext context,
    WidgetRef ref,
    String bookTitle,
  ) async {
    final confirmed = await context.showConfirmDialog(
      title: 'Remove Download',
      message:
          'Remove the offline copy of "$bookTitle"? You can re-download it later.',
      confirmText: 'Remove',
      isDestructive: true,
    );
    if (confirmed ?? false) {
      await ref
          .read(bookDownloaderProvider.notifier)
          .removeDownload(info.bookId);
    }
  }

  String _parseCachedAt(String cachedAt) {
    try {
      final dt = DateTime.parse(cachedAt).toLocal();
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
    } catch (_) {
      return cachedAt;
    }
  }
}

// ---------------------------------------------------------------------------
// Meta chip (icon + label)
// ---------------------------------------------------------------------------

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: AppColors.neutralText),
        const SizedBox(width: 3),
        Text(
          label,
          style: GoogleFonts.nunito(
            fontSize: 12,
            color: AppColors.neutralText,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Remove all button
// ---------------------------------------------------------------------------

class _RemoveAllButton extends ConsumerWidget {
  const _RemoveAllButton({required this.books});

  final List<DownloadedBookInfo> books;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () => _confirmRemoveAll(context, ref),
        icon: const Icon(Icons.delete_sweep_rounded),
        label: Text(
          'Remove All Downloads',
          style: GoogleFonts.nunito(fontWeight: FontWeight.w800),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.danger,
          side: BorderSide(color: AppColors.danger.withValues(alpha: 0.5)),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmRemoveAll(BuildContext context, WidgetRef ref) async {
    final confirmed = await context.showConfirmDialog(
      title: 'Remove All Downloads',
      message:
          'Remove all ${books.length} downloaded book${books.length == 1 ? '' : 's'}? You can re-download them later.',
      confirmText: 'Remove All',
      isDestructive: true,
    );
    if (confirmed ?? false) {
      final notifier = ref.read(bookDownloaderProvider.notifier);
      for (final info in books) {
        await notifier.removeDownload(info.bookId);
      }
    }
  }
}

// ---------------------------------------------------------------------------
// Empty state
// ---------------------------------------------------------------------------

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.download_done_rounded,
              size: 72,
              color: AppColors.neutral,
            ),
            const SizedBox(height: 16),
            Text(
              'No Downloaded Books',
              style: GoogleFonts.nunito(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.black,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Download books from the library to read them offline.',
              textAlign: TextAlign.center,
              style: GoogleFonts.nunito(
                fontSize: 14,
                color: AppColors.neutralText,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
