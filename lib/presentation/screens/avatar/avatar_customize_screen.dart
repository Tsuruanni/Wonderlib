import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:owlio_shared/owlio_shared.dart';

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

class _AvatarCustomizeScreenState extends ConsumerState<AvatarCustomizeScreen>
    with SingleTickerProviderStateMixin {
  TabController? _tabController;
  int _tabCount = 0;

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  void _ensureTabController(int count) {
    if (count != _tabCount || _tabController == null) {
      final oldIndex = _tabController?.index ?? 0;
      _tabController?.dispose();
      _tabCount = count;
      _tabController = TabController(
        length: count,
        vsync: this,
        initialIndex: oldIndex.clamp(0, (count - 1).clamp(0, count)),
      );
    }
  }

  // ── helpers ──────────────────────────────────────────────────────────────

  Color _rarityColor(CardRarity rarity) => Color(rarity.colorHex);

  Future<void> _setBase(AvatarBase base) async {
    final user = ref.read(userControllerProvider).valueOrNull;
    // If same base, ignore
    if (base.id == user?.avatarBaseId) return;

    // Show confirmation dialog for gender change (costs 500 coins)
    final coins = user?.coins ?? 0;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Change Gender', style: GoogleFonts.nunito(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Change gender for 500 coins?\nYour equipped items will be saved and restored if you switch back.',
              style: GoogleFonts.nunito(),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset('assets/icons/gem_outline_256.png', width: 16, height: 16, filterQuality: FilterQuality.high),
                const SizedBox(width: 4),
                Text('Your balance: $coins coins', style: GoogleFonts.nunito(fontWeight: FontWeight.bold)),
              ],
            ),
          ],
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
            child: Text('Change (500 coins)', style: GoogleFonts.nunito(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final error = await ref.read(avatarControllerProvider.notifier).setBase(base.id);
    if (error != null && mounted) _showSnack(error, isError: true);
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
    } else {
      _showSnack('${item.displayName} purchased!');
    }
  }

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor:
            isError ? AppColors.danger : AppColors.primary,
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
                  style: GoogleFonts.nunito(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'You have $userCoins coins',
              style: GoogleFonts.nunito(
                color: AppColors.neutralText,
                fontSize: 13,
              ),
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
              shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
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
    final basesAsync = ref.watch(avatarBasesProvider);
    final shopAsync = ref.watch(avatarShopProvider);
    final userItemsAsync = ref.watch(userAvatarItemsProvider);
    final ownedIds = ref.watch(ownedAvatarItemIdsProvider);
    final itemsByCategory = ref.watch(avatarItemsByCategoryProvider);
    final isMutating = ref.watch(avatarControllerProvider) is AsyncLoading;

    final categories = itemsByCategory.keys.toList()..sort();

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
                // ── Live preview ──────────────────────────────────────────
                _PreviewSection(
                  avatar: equippedAvatar,
                  initials: user?.initials ?? '?',
                  coins: user?.coins ?? 0,
                ),

                // ── Base animal selection ─────────────────────────────────
                basesAsync.when(
                  loading: () => const SizedBox(
                    height: 80,
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (_, __) => SizedBox(
                    height: 80,
                    child: Center(
                      child: TextButton.icon(
                        onPressed: () => ref.invalidate(avatarBasesProvider),
                        icon: const Icon(Icons.refresh, size: 18),
                        label: const Text('Failed to load animals. Tap to retry.'),
                      ),
                    ),
                  ),
                  data: (bases) => _BaseAnimalRow(
                    bases: bases,
                    selectedBaseId: user?.avatarBaseId,
                    onSelect: _setBase,
                  ),
                ),

                const Divider(height: 1),

                // ── Category tabs + item grids ────────────────────────────
                Expanded(
                  child: shopAsync.when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (e, _) =>
                        Center(child: Text('Error loading shop: $e')),
                    data: (_) => userItemsAsync.when(
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (e, _) =>
                          Center(child: Text('Error loading items: $e')),
                      data: (_) {
                        if (categories.isEmpty) {
                          return const Center(
                            child: Text('No accessories available yet.'),
                          );
                        }
                        _ensureTabController(categories.length);
                        return Column(
                          children: [
                            TabBar(
                              controller: _tabController,
                              isScrollable: true,
                              tabAlignment: TabAlignment.start,
                              labelStyle: GoogleFonts.nunito(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13),
                              unselectedLabelStyle:
                                  GoogleFonts.nunito(fontSize: 13),
                              labelColor: AppColors.primary,
                              unselectedLabelColor: AppColors.neutralText,
                              indicatorColor: AppColors.primary,
                              tabs: categories
                                  .map((cat) => Tab(
                                        text: _formatCategoryName(cat),
                                      ))
                                  .toList(),
                            ),
                            Expanded(
                              child: TabBarView(
                                controller: _tabController,
                                children: categories
                                    .map(
                                      (cat) => _ItemGrid(
                                        items:
                                            itemsByCategory[cat] ?? [],
                                        ownedIds: ownedIds,
                                        equippedAvatar: equippedAvatar,
                                        userCoins: user?.coins ?? 0,
                                        onEquip: _equip,
                                        onUnequip: _unequip,
                                        onBuy: (item) =>
                                            _showBuyConfirmation(
                                          item,
                                          user?.coins ?? 0,
                                        ),
                                        onBuyFree: _buy,
                                        rarityColor: _rarityColor,
                                      ),
                                    )
                                    .toList(),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  String _formatCategoryName(String name) {
    if (name.isEmpty) return name;
    return name[0].toUpperCase() + name.substring(1).replaceAll('_', ' ');
  }
}

// ── Preview section ──────────────────────────────────────────────────────────

class _PreviewSection extends StatelessWidget {
  const _PreviewSection({
    required this.avatar,
    required this.initials,
    required this.coins,
  });

  final EquippedAvatar avatar;
  final String initials;
  final int coins;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        children: [
          AvatarWidget(
            avatar: avatar,
            size: 240,
            fallbackInitials: initials,
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset('assets/icons/gem_outline_256.png', width: 18, height: 18, filterQuality: FilterQuality.high),
              const SizedBox(width: 4),
              Text(
                '$coins coins',
                style: GoogleFonts.nunito(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: AppColors.black,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Base animal row ───────────────────────────────────────────────────────────

class _BaseAnimalRow extends StatelessWidget {
  const _BaseAnimalRow({
    required this.bases,
    required this.selectedBaseId,
    required this.onSelect,
  });

  final List<AvatarBase> bases;
  final String? selectedBaseId;
  final void Function(AvatarBase) onSelect;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 88,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: bases.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final base = bases[index];
          final isSelected = base.id == selectedBaseId;
          return GestureDetector(
            onTap: () => onSelect(base),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 64,
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primaryBackground
                    : AppColors.neutral,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? AppColors.primary : Colors.transparent,
                  width: 2.5,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _networkImage(base.imageUrl, width: 40, height: 40),
                  const SizedBox(height: 2),
                  Text(
                    base.displayName,
                    style: GoogleFonts.nunito(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.neutralText,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── Item grid for one category ───────────────────────────────────────────────

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
    required this.rarityColor,
  });

  final List<AvatarItem> items;
  final Set<String> ownedIds;
  final EquippedAvatar equippedAvatar;
  final int userCoins;
  final void Function(AvatarItem) onEquip;
  final void Function(AvatarItem) onUnequip;
  final void Function(AvatarItem) onBuy;
  final void Function(AvatarItem) onBuyFree;
  final Color Function(CardRarity) rarityColor;

  bool _isItemEquipped(AvatarItem item) {
    return equippedAvatar.layers
        .any((layer) => layer.url == item.imageUrl);
  }

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Center(child: Text('No items in this category.'));
    }
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.75,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final isOwned = ownedIds.contains(item.id);
        final isEquipped = _isItemEquipped(item);
        final canAfford = userCoins >= item.coinPrice;
        return _ItemCard(
          item: item,
          isOwned: isOwned,
          isEquipped: isEquipped,
          canAfford: canAfford,
          rarityColor: rarityColor(item.rarity),
          onTap: () {
            if (isEquipped) {
              // Only allow unequip for non-required categories
              if (!item.category.isRequired) {
                onUnequip(item);
              }
              // Required category: do nothing (can't unequip)
            } else if (isOwned) {
              onEquip(item);
            } else if (item.coinPrice == 0) {
              // Free item — buy directly without confirmation
              onBuyFree(item);
            } else if (canAfford) {
              onBuy(item);
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Not enough coins! Need ${item.coinPrice} coins.',
                  ),
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

// ── Individual item card ─────────────────────────────────────────────────────

class _ItemCard extends StatelessWidget {
  const _ItemCard({
    required this.item,
    required this.isOwned,
    required this.isEquipped,
    required this.canAfford,
    required this.rarityColor,
    required this.onTap,
  });

  final AvatarItem item;
  final bool isOwned;
  final bool isEquipped;
  final bool canAfford;
  final Color rarityColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDimmed = !isOwned && !canAfford;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 150),
        opacity: isDimmed ? 0.45 : 1.0,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: isEquipped
                ? AppColors.primaryBackground
                : AppColors.gray100,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isEquipped ? AppColors.primary : rarityColor,
              width: isEquipped ? 2.5 : 1.5,
            ),
          ),
          child: Stack(
            children: [
              // Main content
              Padding(
                padding: const EdgeInsets.all(6),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Expanded(
                      child: _networkImage(item.previewUrl ?? item.imageUrl),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.displayName,
                      style: GoogleFonts.nunito(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: AppColors.black,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    _StatusLabel(
                      isEquipped: isEquipped,
                      isOwned: isOwned,
                      coinPrice: item.coinPrice,
                    ),
                  ],
                ),
              ),

              // Equipped checkmark badge
              if (isEquipped)
                Positioned(
                  top: 4,
                  right: 4,
                  child: Container(
                    width: 18,
                    height: 18,
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check,
                      color: AppColors.white,
                      size: 12,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Status label for item card ───────────────────────────────────────────────

class _StatusLabel extends StatelessWidget {
  const _StatusLabel({
    required this.isEquipped,
    required this.isOwned,
    required this.coinPrice,
  });

  final bool isEquipped;
  final bool isOwned;
  final int coinPrice;

  @override
  Widget build(BuildContext context) {
    if (isEquipped) {
      return Text(
        'Equipped',
        style: GoogleFonts.nunito(
          fontSize: 9,
          fontWeight: FontWeight.bold,
          color: AppColors.primary,
        ),
      );
    }
    if (isOwned) {
      return Text(
        'Owned',
        style: GoogleFonts.nunito(
          fontSize: 9,
          color: AppColors.neutralText,
        ),
      );
    }
    // Not owned — show price or "Free"
    if (coinPrice == 0) {
      return Text(
        'Free',
        style: GoogleFonts.nunito(
          fontSize: 9,
          fontWeight: FontWeight.bold,
          color: AppColors.success,
        ),
      );
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Image.asset('assets/icons/gem_outline_256.png', width: 10, height: 10, filterQuality: FilterQuality.high),
        const SizedBox(width: 2),
        Text(
          '$coinPrice',
          style: GoogleFonts.nunito(
            fontSize: 9,
            fontWeight: FontWeight.bold,
            color: AppColors.black,
          ),
        ),
      ],
    );
  }
}
