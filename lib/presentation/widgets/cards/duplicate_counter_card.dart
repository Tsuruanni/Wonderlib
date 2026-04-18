import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/text_styles.dart';
import '../../../app/theme.dart';
import '../../../domain/entities/card.dart';
import '../../providers/card_provider.dart';

class DuplicateCounterCard extends ConsumerWidget {
  const DuplicateCounterCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userCards = ref.watch(userCardsProvider).valueOrNull ?? [];

    final duplicates = userCards.where((c) => c.quantity > 1).toList();
    final totalExtra =
        duplicates.fold<int>(0, (sum, c) => sum + c.quantity - 1);

    if (totalExtra == 0) return const SizedBox.shrink();

    final mostDuplicated = duplicates.reduce(
        (a, b) => a.quantity >= b.quantity ? a : b,);

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
            'Duplicates',
            style: AppTextStyles.titleMedium(color: AppColors.black).copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                '$totalExtra',
                style: AppTextStyles.headlineLarge(color: AppColors.black).copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(width: 8),
              Text(
                'extra cards',
                style: AppTextStyles.bodyMedium(color: AppColors.neutralText).copyWith(fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildMostDuplicated(mostDuplicated),
        ],
      ),
    );
  }

  Widget _buildMostDuplicated(UserCard uc) {
    final rarityColor = Color(uc.card.rarity.colorHex);

    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: rarityColor, width: 2),
          ),
          clipBehavior: Clip.antiAlias,
          child: uc.card.imageUrl != null
              ? CachedNetworkImage(
                  imageUrl: uc.card.imageUrl!,
                  fit: BoxFit.cover,
                  placeholder: (context, url) =>
                      Container(color: rarityColor.withValues(alpha: 0.2)),
                  errorWidget: (context, url, error) =>
                      Container(color: rarityColor.withValues(alpha: 0.2)),
                )
              : Container(color: rarityColor.withValues(alpha: 0.2)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            uc.card.name,
            style: AppTextStyles.bodySmall(color: AppColors.black).copyWith(fontWeight: FontWeight.w700),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: rarityColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            'x${uc.quantity}',
            style: AppTextStyles.bodySmall(color: rarityColor).copyWith(fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );
  }
}
