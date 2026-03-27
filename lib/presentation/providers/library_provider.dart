import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Search query state
final librarySearchQueryProvider = StateProvider<String>((ref) => '');

/// Whether search is active
final isSearchActiveProvider = StateProvider<bool>((ref) => false);

/// Available CEFR levels for filtering
const cefrLevels = ['A1', 'A2', 'B1', 'B2', 'C1', 'C2'];
