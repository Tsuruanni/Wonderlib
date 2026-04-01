import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/theme.dart';
import '../../../domain/entities/card.dart';
import '../../providers/card_provider.dart';

class RarestCardOwnerCard extends ConsumerWidget {
  const RarestCardOwnerCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(exclusiveCardsProvider);

    return async.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (cards) {
        if (cards.isEmpty) return const SizedBox.shrink();

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
                'Only You Have',
                style: GoogleFonts.nunito(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: AppColors.black,
                ),
              ),
              const SizedBox(height: 12),
              for (int i = 0; i < cards.length; i++) ...[
                if (i > 0) const SizedBox(height: 10),
                _buildExclusiveRow(cards[i]),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildExclusiveRow(MythCard card) {
    final rarityColor = Color(card.rarity.colorHex);

    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: rarityColor, width: 2),
          ),
          clipBehavior: Clip.antiAlias,
          child: card.imageUrl != null
              ? CachedNetworkImage(
                  imageUrl: card.imageUrl!,
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                card.name,
                style: GoogleFonts.nunito(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.black,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                'Only owner in class',
                style: GoogleFonts.nunito(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: rarityColor,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
