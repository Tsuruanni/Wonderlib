import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ReaderScreen extends ConsumerWidget {
  final String bookId;
  final String chapterId;

  const ReaderScreen({
    super.key,
    required this.bookId,
    required this.chapterId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reading'),
      ),
      body: Center(
        child: Text('Book: $bookId, Chapter: $chapterId'),
      ),
    );
  }
}
