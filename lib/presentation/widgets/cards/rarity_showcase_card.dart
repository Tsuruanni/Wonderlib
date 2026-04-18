import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/text_styles.dart';
import '../../../app/theme.dart';
import '../../../domain/entities/card.dart';
import '../../providers/card_provider.dart';

class RarityShowcaseCard extends ConsumerWidget {
  const RarityShowcaseCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userCards = ref.watch(userCardsProvider).valueOrNull ?? [];
    if (userCards.isEmpty) return const SizedBox.shrink();

    final sorted = [...userCards]
      ..sort((a, b) {
        final rarityCompare = b.card.rarity.index.compareTo(a.card.rarity.index);
        if (rarityCompare != 0) return rarityCompare;
        return b.card.power.compareTo(a.card.power);
      });
    final topCards = sorted.take(6).toList();
    final firstRow = topCards.take(3).toList();
    final secondRow = topCards.length > 3 ? topCards.skip(3).toList() : <UserCard>[];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.neutral, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Rarest Cards',
            style: AppTextStyles.titleMedium(color: AppColors.black).copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          _buildRow(firstRow),
          if (secondRow.isNotEmpty) ...[
            const SizedBox(height: 8),
            _buildRow(secondRow),
          ],
        ],
      ),
    );
  }

  Widget _buildRow(List<UserCard> cards) {
    return Row(
      children: [
        for (int i = 0; i < 3; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: i < cards.length
                ? _buildCardPreview(cards[i].card)
                : const SizedBox.shrink(),
          ),
        ],
      ],
    );
  }

  Widget _buildCardPreview(MythCard card) {
    final rarityColor = Color(card.rarity.colorHex);

    return Column(
      children: [
        Container(
          height: 80,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: rarityColor, width: 2),
          ),
          clipBehavior: Clip.antiAlias,
          child: card.imageUrl != null
              ? CachedNetworkImage(
                  imageUrl: card.imageUrl!,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  placeholder: (context, url) => Container(color: rarityColor.withValues(alpha: 0.2)),
                  errorWidget: (context, url, error) => Container(color: rarityColor.withValues(alpha: 0.2)),
                )
              : Container(color: rarityColor.withValues(alpha: 0.2)),
        ),
        const SizedBox(height: 4),
        Text(
          card.name,
          style: AppTextStyles.caption(color: AppColors.black).copyWith(fontSize: 11, fontWeight: FontWeight.w700),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
        Text(
          '⚡ ${card.power}',
          style: AppTextStyles.caption(color: rarityColor).copyWith(fontSize: 11, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}
