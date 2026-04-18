import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/text_styles.dart';
import '../../../app/theme.dart';
import '../../../domain/entities/card.dart';
import '../../providers/card_provider.dart';
import '../common/app_progress_bar.dart';

class CollectionProgressCard extends ConsumerWidget {
  const CollectionProgressCard({super.key});

  static const _rarityColors = {
    CardRarity.common: AppColors.cardCommon,
    CardRarity.rare: AppColors.cardRare,
    CardRarity.epic: AppColors.cardEpic,
    CardRarity.legendary: AppColors.cardLegendary,
  };

  static const _rarityDarkColors = {
    CardRarity.common: AppColors.cardCommonDark,
    CardRarity.rare: AppColors.cardRareDark,
    CardRarity.epic: AppColors.cardEpicDark,
    CardRarity.legendary: AppColors.cardLegendaryDark,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userCards = ref.watch(userCardsProvider).valueOrNull ?? [];
    final catalog = ref.watch(cardCatalogProvider).valueOrNull ?? [];
    final breakdown = ref.watch(rarityBreakdownProvider);

    final owned = userCards.length;
    final total = catalog.length;
    final progress = total > 0 ? owned / total : 0.0;

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
            'Collection',
            style: AppTextStyles.titleMedium(color: AppColors.black).copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                '$owned',
                style: AppTextStyles.headlineLarge(color: AppColors.black).copyWith(fontWeight: FontWeight.w900),
              ),
              Text(
                ' / $total',
                style: AppTextStyles.headlineLarge(color: AppColors.neutralDark).copyWith(fontWeight: FontWeight.w900),
              ),
              const Spacer(),
              Text(
                '${(progress * 100).toInt()}%',
                style: AppTextStyles.titleMedium(color: AppColors.primary).copyWith(fontSize: 18, fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 8),
          AppProgressBar(
            progress: progress,
            height: 8,
          ),
          const SizedBox(height: 16),
          for (final rarity in CardRarity.values) ...[
            _buildRarityRow(rarity, breakdown[rarity]!),
            if (rarity != CardRarity.legendary) const SizedBox(height: 8),
          ],

          // Total packs opened
          _buildPacksOpened(ref),
        ],
      ),
    );
  }

  Widget _buildPacksOpened(WidgetRef ref) {
    final stats = ref.watch(userCardStatsProvider).valueOrNull;
    final total = stats?.totalPacksOpened ?? 0;
    if (total == 0) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Text(
        '$total packs opened',
        textAlign: TextAlign.center,
        style: AppTextStyles.bodySmall(color: AppColors.neutralText).copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _buildRarityRow(CardRarity rarity, ({int owned, int total}) data) {
    final color = _rarityColors[rarity]!;
    final progress = data.total > 0 ? data.owned / data.total : 0.0;

    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 72,
          child: Text(
            rarity.label,
            style: AppTextStyles.bodySmall(color: AppColors.neutralText).copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        Expanded(
          child: AppProgressBar(
            progress: progress,
            height: 6,
            fillColor: color,
            fillShadow: _rarityDarkColors[rarity]!,
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 36,
          child: Text(
            '${data.owned}/${data.total}',
            style: AppTextStyles.caption(color: AppColors.neutralText).copyWith(fontWeight: FontWeight.w700),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}
