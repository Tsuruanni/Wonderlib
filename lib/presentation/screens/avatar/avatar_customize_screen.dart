import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../app/theme.dart';
import '../../../domain/entities/avatar.dart';
import '../../utils/app_icons.dart';
import '../../providers/avatar_provider.dart';
import '../../providers/user_provider.dart';
import '../../widgets/common/avatar_widget.dart';

bool _isSvgUrl(String url) {
  final path = Uri.tryParse(url)?.path ?? url;
  return path.toLowerCase().endsWith('.svg');
}

Widget _networkImage(String url, {double? width, double? height, BoxFit fit = BoxFit.contain}) {
  if (_isSvgUrl(url)) {
    return SvgPicture.network(url, width: width, height: height, fit: fit,
      placeholderBuilder: (_) => const SizedBox.shrink());
  }
  return CachedNetworkImage(imageUrl: url, width: width, height: height, fit: fit,
    errorWidget: (_, __, ___) => const Icon(Icons.image, size: 32));
}

class AvatarCustomizeScreen extends ConsumerStatefulWidget {
  const AvatarCustomizeScreen({super.key});

  @override
  ConsumerState<AvatarCustomizeScreen> createState() =>
      _AvatarCustomizeScreenState();
}

const _kHairColorCategory = '_hair_color';

const _hairColorPalette = <String, Color>{
  '#1A1A1A': Color(0xFF1A1A1A), // black
  '#4A3728': Color(0xFF4A3728), // dark brown
  '#8B4513': Color(0xFF8B4513), // brown
  '#C68642': Color(0xFFC68642), // light brown
  '#E8B960': Color(0xFFE8B960), // blonde
  '#F5DEB3': Color(0xFFF5DEB3), // platinum
  '#B22222': Color(0xFFB22222), // red
  '#CC5500': Color(0xFFCC5500), // auburn
  '#8B008B': Color(0xFF8B008B), // purple
  '#1E90FF': Color(0xFF1E90FF), // blue
  '#2E8B57': Color(0xFF2E8B57), // green
  '#FF69B4': Color(0xFFFF69B4), // pink
};

class _AvatarCustomizeScreenState extends ConsumerState<AvatarCustomizeScreen> {
  String? _selectedCategory;

  // ── helpers ──────────────────────────────────────────────────────────────

  Future<void> _changeGender() async {
    final user = ref.read(userControllerProvider).valueOrNull;
    if (user == null) return;
    final coins = user.coins;
    final bases = ref.read(avatarBasesProvider).valueOrNull ?? [];
    final otherBase = bases.where((b) => b.id != user.avatarBaseId).firstOrNull;
    if (otherBase == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Change Gender', style: GoogleFonts.nunito(fontWeight: FontWeight.bold)),
        content: Text(
          'Switch to ${otherBase.displayName} for 500 coins?\nYour current items will be saved.\n\nBalance: $coins coins',
          style: GoogleFonts.nunito(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancel', style: GoogleFonts.nunito()),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: coins >= 500 ? () => Navigator.of(ctx).pop(true) : null,
            child: Text('Change (500)', style: GoogleFonts.nunito(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final error = await ref.read(avatarControllerProvider.notifier).setBase(otherBase.id);
    if (error != null && mounted) _showSnack(error, isError: true);
  }

  Future<void> _setHairColor(String hexColor) async {
    try {
      await Supabase.instance.client.rpc('set_hair_color', params: {'p_color': hexColor});
      ref.read(userControllerProvider.notifier).refreshProfileOnly();
    } catch (e) {
      if (mounted) _showSnack('Failed to set hair color', isError: true);
    }
  }

  Future<void> _equip(AvatarItem item) async {
    final error = await ref.read(avatarControllerProvider.notifier).equipItem(item.id);
    if (error != null && mounted) _showSnack(error, isError: true);
  }

  Future<void> _unequip(AvatarItem item) async {
    final error = await ref.read(avatarControllerProvider.notifier).unequipItem(item.id);
    if (error != null && mounted) _showSnack(error, isError: true);
  }

  Future<void> _buy(AvatarItem item) async {
    final error = await ref.read(avatarControllerProvider.notifier).buyItem(item.id);
    if (!mounted) return;
    if (error != null) {
      _showSnack(error, isError: true);
    }
  }

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.danger : AppColors.primary,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showBuyConfirmation(AvatarItem item, int userCoins) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Buy ${item.displayName}?',
          style: GoogleFonts.nunito(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _networkImage(item.previewUrl ?? item.imageUrl, width: 80, height: 80),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AppIcons.gem(size: 20),
                const SizedBox(width: 4),
                Text(
                  '${item.coinPrice} coins',
                  style: GoogleFonts.nunito(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'You have $userCoins coins',
              style: GoogleFonts.nunito(color: AppColors.neutralText, fontSize: 13),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Cancel', style: GoogleFonts.nunito()),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              _buy(item);
            },
            child: Text('Buy', style: GoogleFonts.nunito(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // ── build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(userControllerProvider).valueOrNull;
    final equippedAvatar = ref.watch(equippedAvatarProvider);
    final shopAsync = ref.watch(avatarShopProvider);
    final userItemsAsync = ref.watch(userAvatarItemsProvider);
    final ownedIds = ref.watch(ownedAvatarItemIdsProvider);
    final itemsByCategory = ref.watch(avatarItemsByCategoryProvider);
    final isMutating = ref.watch(avatarControllerProvider) is AsyncLoading;

    // Hide ears category (only 1 item, always equipped)
    // Insert "Hair Color" right after "hair"
    final categories = itemsByCategory.keys
        .where((c) => c != 'ears')
        .toList()..sort();
    final hairIndex = categories.indexOf('hair');
    if (hairIndex != -1) {
      categories.insert(hairIndex + 1, _kHairColorCategory);
    }

    // Auto-select first category
    if (_selectedCategory == null && categories.isNotEmpty) {
      _selectedCategory = categories.first;
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'CUSTOMIZE AVATAR',
          style: GoogleFonts.nunito(
            fontWeight: FontWeight.bold,
            color: AppColors.black,
            letterSpacing: 1.0,
          ),
        ),
        centerTitle: true,
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: isMutating
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // ── Top: avatar preview centered above item grid ─────
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Column(
                    children: [
                      AvatarWidget(
                        avatar: equippedAvatar,
                        size: 360,
                        width: 360,
                        height: 360,
                        fallbackInitials: user?.initials ?? '?',
                        borderRadius: 24,
                        showBorder: false,
                      ),
                      const SizedBox(height: 6),
                      GestureDetector(
                        onTap: _changeGender,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.swap_horiz_rounded, size: 14, color: AppColors.neutralText),
                            const SizedBox(width: 4),
                            Text(
                              'Change Gender',
                              style: GoogleFonts.nunito(
                                fontSize: 11,
                                color: AppColors.neutralText,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                // ── Bottom: category sidebar + item grid ─────────────
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Left: category list ──
                      SizedBox(
                        width: 90,
                        child: _buildCategoryList(categories),
                      ),

                      const VerticalDivider(width: 1),

                      // ── Right: item grid ─────────────────────────────────
                Expanded(
                  child: shopAsync.when(
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Center(child: Text('Error: $e')),
                    data: (_) => userItemsAsync.when(
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (e, _) => Center(child: Text('Error: $e')),
                      data: (_) {
                        if (categories.isEmpty) {
                          return const Center(child: Text('No items available yet.'));
                        }
                        if (_selectedCategory == _kHairColorCategory) {
                          return _HairColorPalette(
                            selectedColor: equippedAvatar.hairColor,
                            onSelect: _setHairColor,
                          );
                        }
                        return _ItemGrid(
                          items: itemsByCategory[_selectedCategory] ?? [],
                          ownedIds: ownedIds,
                          equippedAvatar: equippedAvatar,
                          userCoins: user?.coins ?? 0,
                          onEquip: _equip,
                          onUnequip: _unequip,
                          onBuy: (item) => _showBuyConfirmation(item, user?.coins ?? 0),
                          onBuyFree: _buy,
                        );
                      },
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

  Widget _buildCategoryList(List<String> categories) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: categories.length,
      itemBuilder: (context, index) {
        final cat = categories[index];
        final isSelected = cat == _selectedCategory;
        return GestureDetector(
          onTap: () => setState(() => _selectedCategory = cat),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.primaryBackground : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: isSelected
                  ? Border.all(color: AppColors.primary, width: 1.5)
                  : null,
            ),
            child: Text(
              _formatCategoryName(cat),
              style: GoogleFonts.nunito(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected ? AppColors.primary : AppColors.neutralText,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        );
      },
    );
  }

  String _formatCategoryName(String name) {
    if (name == _kHairColorCategory) return 'Hair Color';
    if (name.isEmpty) return name;
    return name[0].toUpperCase() + name.substring(1).replaceAll('_', ' ');
  }
}

// ── Item grid for selected category ─────────────────────────────────────────

class _ItemGrid extends StatelessWidget {
  const _ItemGrid({
    required this.items,
    required this.ownedIds,
    required this.equippedAvatar,
    required this.userCoins,
    required this.onEquip,
    required this.onUnequip,
    required this.onBuy,
    required this.onBuyFree,
  });

  final List<AvatarItem> items;
  final Set<String> ownedIds;
  final EquippedAvatar equippedAvatar;
  final int userCoins;
  final void Function(AvatarItem) onEquip;
  final void Function(AvatarItem) onUnequip;
  final void Function(AvatarItem) onBuy;
  final void Function(AvatarItem) onBuyFree;

  bool _isItemEquipped(AvatarItem item) {
    return equippedAvatar.layers.any((layer) => layer.url == item.imageUrl);
  }

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Center(child: Text('No items in this category.'));
    }
    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 90,
        childAspectRatio: 0.75,
        crossAxisSpacing: 6,
        mainAxisSpacing: 6,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final isOwned = ownedIds.contains(item.id);
        final isEquipped = _isItemEquipped(item);
        final canAfford = userCoins >= item.coinPrice;
        // Extract short label: "Hair 1", "Eyes 3", etc.
        final catName = item.category.displayName;
        final label = '$catName ${index + 1}';
        return _ItemCard(
          item: item,
          label: label,
          isEquipped: isEquipped,
          isDimmed: !isOwned && !canAfford && item.coinPrice > 0,
          onTap: () {
            if (isEquipped) {
              if (!item.category.isRequired) {
                onUnequip(item);
              }
            } else if (isOwned) {
              onEquip(item);
            } else if (item.coinPrice == 0) {
              onBuyFree(item);
            } else if (canAfford) {
              onBuy(item);
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Not enough coins! Need ${item.coinPrice} coins.'),
                  backgroundColor: AppColors.danger,
                  behavior: SnackBarBehavior.floating,
                  duration: const Duration(seconds: 2),
                ),
              );
            }
          },
        );
      },
    );
  }
}

// ── Compact item card (image only, no text) ─────────────────────────────────

class _ItemCard extends StatelessWidget {
  const _ItemCard({
    required this.item,
    required this.label,
    required this.isEquipped,
    required this.isDimmed,
    required this.onTap,
  });

  final AvatarItem item;
  final String label;
  final bool isEquipped;
  final bool isDimmed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 150),
        opacity: isDimmed ? 0.45 : 1.0,
        child: Column(
          children: [
            Expanded(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: isEquipped ? AppColors.primaryBackground : AppColors.gray100,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isEquipped ? AppColors.primary : Colors.transparent,
                    width: isEquipped ? 2 : 0,
                  ),
                ),
                child: Stack(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(4),
                      child: Center(
                        child: _networkImage(item.previewUrl ?? item.imageUrl),
                      ),
                    ),
                    if (isEquipped)
                      Positioned(
                        top: 3,
                        right: 3,
                        child: Container(
                          width: 16,
                          height: 16,
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.check, color: AppColors.white, size: 10),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: GoogleFonts.nunito(
                fontSize: 9,
                fontWeight: isEquipped ? FontWeight.bold : FontWeight.w600,
                color: isEquipped ? AppColors.primary : AppColors.neutralText,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Hair color palette ──────────────────────────────────────────────────────

class _HairColorPalette extends StatelessWidget {
  const _HairColorPalette({required this.selectedColor, required this.onSelect});

  final String? selectedColor;
  final void Function(String hex) onSelect;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: _hairColorPalette.entries.map((entry) {
          final isSelected = selectedColor == entry.key;
          return GestureDetector(
            onTap: () => onSelect(entry.key),
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: entry.value,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? AppColors.primary : Colors.transparent,
                  width: 3,
                ),
                boxShadow: isSelected
                    ? [BoxShadow(color: entry.value.withValues(alpha: 0.5), blurRadius: 8)]
                    : null,
              ),
              child: isSelected
                  ? const Icon(Icons.check, color: AppColors.white, size: 20)
                  : null,
            ),
          );
        }).toList(),
      ),
    );
  }
}
