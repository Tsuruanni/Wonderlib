import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

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
    final top3 = sorted.take(3).toList();

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
            style: GoogleFonts.nunito(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: AppColors.black,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              for (int i = 0; i < top3.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(child: _buildCardPreview(top3[i].card)),
              ],
            ],
          ),
        ],
      ),
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
          style: GoogleFonts.nunito(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppColors.black,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
        Text(
          '⚡ ${card.power}',
          style: GoogleFonts.nunito(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: rarityColor,
          ),
        ),
      ],
    );
  }
}
