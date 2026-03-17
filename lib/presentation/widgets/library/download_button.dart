import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/book_download_provider.dart';

/// Shows the download status for a book and allows the user to trigger a
/// download for offline reading.
///
/// Displays:
/// - A [CircularProgressIndicator] with progress value while actively downloading
/// - A green check icon when the download is complete
/// - A download icon button otherwise, which opens a confirmation dialog
class BookDownloadButton extends ConsumerWidget {
  const BookDownloadButton({
    super.key,
    required this.bookId,
    required this.userId,
  });

  final String bookId;
  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusAsync = ref.watch(bookDownloadStatusProvider(bookId));
    final activeDownloads = ref.watch(activeDownloadsProvider);
    final activeProgress = activeDownloads[bookId];

    // Actively downloading — show progress indicator
    if (activeProgress != null) {
      return SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(
          value: activeProgress > 0 ? activeProgress : null,
          strokeWidth: 2.5,
          color: Colors.white,
        ),
      );
    }

    final status = statusAsync.valueOrNull;

    // Download complete — show success check
    if (status == 'complete') {
      return const Icon(
        Icons.check_circle_rounded,
        color: Colors.greenAccent,
      );
    }

    // Default — show download icon button
    return IconButton(
      icon: const Icon(Icons.download_rounded),
      tooltip: 'Download for offline reading',
      onPressed: () => _showDownloadDialog(context, ref),
    );
  }

  Future<void> _showDownloadDialog(BuildContext context, WidgetRef ref) async {
    bool includeAudio = false;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return _DownloadDialog(
          initialIncludeAudio: includeAudio,
          onConfirm: (audio) {
            includeAudio = audio;
          },
        );
      },
    );

    if ((confirmed ?? false) && context.mounted) {
      ref.read(bookDownloaderProvider.notifier).downloadBook(
            bookId,
            userId: userId,
            includeAudio: includeAudio,
          );
    }
  }
}

/// Stateful dialog that lets the user confirm a download and optionally
/// include audio files.
class _DownloadDialog extends StatefulWidget {
  const _DownloadDialog({
    required this.initialIncludeAudio,
    required this.onConfirm,
  });

  final bool initialIncludeAudio;
  final void Function(bool includeAudio) onConfirm;

  @override
  State<_DownloadDialog> createState() => _DownloadDialogState();
}

class _DownloadDialogState extends State<_DownloadDialog> {
  late bool _includeAudio;

  @override
  void initState() {
    super.initState();
    _includeAudio = widget.initialIncludeAudio;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Download Book'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Download this book for offline reading?'),
          const SizedBox(height: 16),
          CheckboxListTile(
            value: _includeAudio,
            onChanged: (value) {
              setState(() => _includeAudio = value ?? false);
            },
            title: const Text('Include audio'),
            subtitle: const Text('Larger download size'),
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            widget.onConfirm(_includeAudio);
            Navigator.of(context).pop(true);
          },
          child: const Text('Download'),
        ),
      ],
    );
  }
}
