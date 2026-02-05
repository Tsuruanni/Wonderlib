import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ActivityScreen extends ConsumerWidget {

  const ActivityScreen({
    super.key,
    required this.chapterId,
  });
  final String chapterId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Activity'),
      ),
      body: Center(
        child: Text('Chapter Activity: $chapterId'),
      ),
    );
  }
}
