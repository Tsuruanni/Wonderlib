import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:owlio_shared/owlio_shared.dart';

import '../../../app/theme.dart';
import '../../../domain/entities/avatar.dart';
import '../../../domain/usecases/avatar/buy_avatar_item_usecase.dart';
import '../../../domain/usecases/avatar/equip_avatar_item_usecase.dart';
import '../../../domain/usecases/avatar/set_avatar_base_usecase.dart';
import '../../../domain/usecases/avatar/unequip_avatar_item_usecase.dart';
import '../../providers/avatar_provider.dart';
import '../../providers/usecase_providers.dart';
import '../../providers/user_provider.dart';
import '../../widgets/common/avatar_widget.dart';

class AvatarCustomizeScreen extends ConsumerStatefulWidget {
  const AvatarCustomizeScreen({super.key});

  @override
  ConsumerState<AvatarCustomizeScreen> createState() =>
      _AvatarCustomizeScreenState();
}

class _AvatarCustomizeScreenState extends ConsumerState<AvatarCustomizeScreen> {
  bool _isMutating = false;

  // ── helpers ──────────────────────────────────────────────────────────────

  Color _rarityColor(CardRarity rarity) {
    switch (rarity) {
      case CardRarity.common:
        return const Color(0xFFAFAFAF);
      case CardRarity.rare:
        return const Color(0xFF1CB0F6);
      case CardRarity.epic:
        return const Color(0xFF9B59B6);
      case CardRarity.legendary:
        return const Color(0xFFFFC800);
    }
  }

  Future<void> _setBase(AvatarBase base) async {
    if (_isMutating) return;
    setState(() => _isMutating = true);
    try {
      final useCase = ref.read(setAvatarBaseUseCaseProvider);
      final result =
          await useCase(SetAvatarBaseParams(baseId: base.id));
      result.fold(
        (failure) => _showSnack(
          'Failed to set base: ${failure.message}',
          isError: true,
        ),
        (_) {
          ref.invalidate(userAvatarItemsProvider);
          ref.invalidate(userControllerProvider);
        },
      );
    } finally {
      if (mounted) setState(() => _isMutating = false);
    }
  }

  Future<void> _equip(AvatarItem item) async {
    if (_isMutating) return;
    setState(() => _isMutating = true);
    try {
      final useCase = ref.read(equipAvatarItemUseCaseProvider);
      final result =
          await useCase(EquipAvatarItemParams(itemId: item.id));
      result.fold(
        (failure) => _showSnack(
          'Failed to equip: ${failure.message}',
          isError: true,
        ),
        (_) {
          ref.invalidate(userAvatarItemsProvider);
          ref.invalidate(userControllerProvider);
        },
      );
    } finally {
      if (mounted) setState(() => _isMutating = false);
    }
  }

  Future<void> _unequip(AvatarItem item) async {
    if (_isMutating) return;
    setState(() => _isMutating = true);
    try {
      final useCase = ref.read(unequipAvatarItemUseCaseProvider);
      final result =
          await useCase(UnequipAvatarItemParams(itemId: item.id));
      result.fold(
        (failure) => _showSnack(
          'Failed to unequip: ${failure.message}',
          isError: true,
        ),
        (_) {
          ref.invalidate(userAvatarItemsProvider);
          ref.invalidate(userControllerProvider);
        },
      );
    } finally {
      if (mounted) setState(() => _isMutating = false);
    }
  }

  Future<void> _buy(AvatarItem item) async {
    if (_isMutating) return;
    setState(() => _isMutating = true);
    try {
      final useCase = ref.read(buyAvatarItemUseCaseProvider);
      final result =
          await useCase(BuyAvatarItemParams(itemId: item.id));
      result.fold(
        (failure) => _showSnack(
          'Purchase failed: ${failure.message}',
          isError: true,
        ),
        (buyResult) {
          ref.invalidate(userAvatarItemsProvider);
          ref.invalidate(userControllerProvider);
          _showSnack(
            '${item.displayName} purchased! ${buyResult.coinsRemaining} coins remaining.',
          );
        },
      );
    } finally {
      if (mounted) setState(() => _isMutating = false);
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
            CachedNetworkImage(
              imageUrl: item.previewUrl ?? item.imageUrl,
              height: 80,
              width: 80,
              fit: BoxFit.contain,
              errorWidget: (_, __, ___) => const Icon(Icons.image, size: 40),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.monetization_on,
                  color: AppColors.wasp,
                  size: 20,
                ),
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
      body: _isMutating
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
                  error: (_, __) => const SizedBox.shrink(),
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
                        return DefaultTabController(
                          length: categories.length,
                          child: Column(
                            children: [
                              TabBar(
                                isScrollable: true,
                                tabAlignment: TabAlignment.start,
                                labelStyle: GoogleFonts.nunito(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,),
                                unselectedLabelStyle:
                                    GoogleFonts.nunito(fontSize: 13),
                                labelColor: AppColors.primary,
                                unselectedLabelColor: AppColors.neutralText,
                                indicatorColor: AppColors.primary,
                                tabs: categories
                                    .map(
                                      (cat) => Tab(
                                        text: _formatCategoryName(cat),
                                      ),
                                    )
                                    .toList(),
                              ),
                              Expanded(
                                child: TabBarView(
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
                                          rarityColor: _rarityColor,
                                        ),
                                      )
                                      .toList(),
                                ),
                              ),
                            ],
                          ),
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
            size: 120,
            fallbackInitials: initials,
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.monetization_on,
                color: AppColors.wasp,
                size: 18,
              ),
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
                  CachedNetworkImage(
                    imageUrl: base.imageUrl,
                    width: 40,
                    height: 40,
                    fit: BoxFit.contain,
                    errorWidget: (_, __, ___) =>
                        const Icon(Icons.pets, size: 32),
                  ),
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
    required this.rarityColor,
  });

  final List<AvatarItem> items;
  final Set<String> ownedIds;
  final EquippedAvatar equippedAvatar;
  final int userCoins;
  final void Function(AvatarItem) onEquip;
  final void Function(AvatarItem) onUnequip;
  final void Function(AvatarItem) onBuy;
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
              onUnequip(item);
            } else if (isOwned) {
              onEquip(item);
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
                      child: CachedNetworkImage(
                        imageUrl: item.previewUrl ?? item.imageUrl,
                        fit: BoxFit.contain,
                        errorWidget: (_, __, ___) =>
                            const Icon(Icons.image, size: 32),
                      ),
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
    // Not owned — show price
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.monetization_on, color: AppColors.wasp, size: 10),
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
