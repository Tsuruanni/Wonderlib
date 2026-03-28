import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:owlio_shared/owlio_shared.dart';

import '../../../core/supabase_client.dart';

/// Provider for loading all myth cards
final mythCardsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final supabase = ref.watch(supabaseClientProvider);
  final response =
      await supabase.from(DbTables.mythCards).select().order('card_no');
  return List<Map<String, dynamic>>.from(response);
});

/// Filter by category
final cardCategoryFilterProvider = StateProvider<CardCategory?>((ref) => null);
