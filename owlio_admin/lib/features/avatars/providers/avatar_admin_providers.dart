import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:owlio_shared/owlio_shared.dart';

import '../../../core/supabase_client.dart';

final avatarBasesAdminProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final supabase = ref.watch(supabaseClientProvider);
  return await supabase.from(DbTables.avatarBases).select().order('sort_order');
});

final avatarItemCategoriesAdminProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final supabase = ref.watch(supabaseClientProvider);
  return await supabase.from(DbTables.avatarItemCategories).select().order('sort_order');
});

final avatarItemsAdminProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final supabase = ref.watch(supabaseClientProvider);
  return await supabase
      .from(DbTables.avatarItems)
      .select('*, avatar_item_categories(name, display_name)')
      .order('coin_price');
});

final avatarBaseDetailProvider = FutureProvider.family<Map<String, dynamic>?, String>((ref, baseId) async {
  final supabase = ref.watch(supabaseClientProvider);
  return await supabase
      .from(DbTables.avatarBases)
      .select()
      .eq('id', baseId)
      .maybeSingle();
});

final avatarItemDetailProvider = FutureProvider.family<Map<String, dynamic>?, String>((ref, itemId) async {
  final supabase = ref.watch(supabaseClientProvider);
  return await supabase
      .from(DbTables.avatarItems)
      .select('*, avatar_item_categories(*)')
      .eq('id', itemId)
      .maybeSingle();
});

final avatarCategoryDetailProvider = FutureProvider.family<Map<String, dynamic>?, String>((ref, categoryId) async {
  final supabase = ref.watch(supabaseClientProvider);
  return await supabase
      .from(DbTables.avatarItemCategories)
      .select()
      .eq('id', categoryId)
      .maybeSingle();
});
