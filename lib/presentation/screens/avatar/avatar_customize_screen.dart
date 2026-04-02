import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../app/theme.dart';
import '../../../domain/entities/avatar.dart';
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

class _AvatarCustomizeScreenState extends ConsumerState<AvatarCustomizeScreen> {
  String? _selectedCategory;

  // ── helpers ──────────────────────────────────────────────────────────────

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
                Image.asset('assets/icons/gem_outline_256.png', width: 20, height: 20, filterQuality: FilterQuality.high),
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
    final categories = itemsByCategory.keys
        .where((c) => c != 'ears')
        .toList()..sort();

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
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Left column: avatar preview + category list ──────
                SizedBox(
                  width: 100,
                  child: Column(
                    children: [
                      // Square avatar preview, fills the width
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: AspectRatio(
                          aspectRatio: 1,
                          child: AvatarWidget(
                            avatar: equippedAvatar,
                            size: 84,
                            fallbackInitials: user?.initials ?? '?',
                            borderRadius: 16,
                          ),
                        ),
                      ),
                      const Divider(height: 1),
                      // Category list
                      Expanded(
                        child: _buildCategoryList(categories),
                      ),
                    ],
                  ),
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
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 6,
        mainAxisSpacing: 6,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final isOwned = ownedIds.contains(item.id);
        final isEquipped = _isItemEquipped(item);
        final canAfford = userCoins >= item.coinPrice;
        return _ItemCard(
          item: item,
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
    required this.isEquipped,
    required this.isDimmed,
    required this.onTap,
  });

  final AvatarItem item;
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
    );
  }
}
