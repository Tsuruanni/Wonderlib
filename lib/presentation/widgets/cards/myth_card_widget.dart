import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../app/text_styles.dart';
import '../../../app/theme.dart';
import '../../../domain/entities/card.dart';
import '../../utils/ui_helpers.dart';

/// Displays a single myth card with rarity-based visual styling.
///
/// Two variants:
/// - **mini** (default): Compact for grid display — icon, name, power, rarity stars
/// - **full**: Expanded for detail view — adds description + special skill
class MythCardWidget extends StatelessWidget {
  const MythCardWidget({
    super.key,
    required this.card,
    this.isFull = false,
    this.quantity,
    this.showNewBadge = false,
    this.onTap,
  });

  final MythCard card;
  final bool isFull;
  final int? quantity;
  final bool showNewBadge;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final rarityColor = CardColors.getRarityColor(card.rarity);
    final rarityDark = CardColors.getRarityDarkColor(card.rarity);

    // Standard Aspect Ratio: 2.5 width / 3.5 height = ~0.714
    Widget cardContent = Container(
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: rarityColor,
          width: card.rarity == CardRarity.legendary ? 3.0 : 2.0,
        ),
        boxShadow: [
          BoxShadow(
            color: rarityDark.withValues(alpha: 0.4),
            offset: const Offset(0, 4),
            blurRadius: 8,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(2),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Background: Card artwork or rarity gradient fallback
            if (card.imageUrl != null)
              _buildCardImage(card.imageUrl!)
            else
              _buildFallbackBackground(),

            // Gradient Overlay for Text Readability
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: isFull
                      ? [Colors.transparent, Colors.transparent]
                      : [
                          Colors.black.withValues(alpha: 0.7),
                          Colors.transparent,
                          Colors.transparent,
                        ],
                  stops: isFull
                      ? const [0.0, 1.0]
                      : const [0.0, 0.35, 1.0],
                ),
              ),
            ),

            // Rarity / Frame Overlay (Border glow for high rarity)
            if (card.rarity == CardRarity.legendary)
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(2),
                  border: Border.all(
                    color: rarityColor.withValues(alpha: 0.3),
                    width: 4,
                  ),
                ),
              ),
            if (card.rarity == CardRarity.epic)
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(2),
                  border: Border.all(
                    color: rarityColor.withValues(alpha: 0.5),
                    width: 3,
                  ),
                ),
              ),

             _buildCardContent(isFull, rarityColor, rarityDark),

            // Quantity Badge (bottom-right in mini, top-right in full)
            if (quantity != null && quantity! > 1)
              Positioned(
                top: isFull ? 8 : null,
                bottom: isFull ? null : 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.black.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: Text(
                    '\u00d7$quantity',
                    style: AppTextStyles.caption(color: AppColors.white).copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
              ),

            // NEW Badge (Top Left)
            if (showNewBadge)
              Positioned(
                top: 8,
                left: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.4),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: Text(
                    'NEW!',
                    style: AppTextStyles.caption(color: AppColors.white).copyWith(fontSize: 11, fontWeight: FontWeight.w900),
                  ),
                ),
              ),
          ],
        ),
      ),
    );

    // Apply shimmer/glow based on rarity
    // In full mode: all cards get shimmer. In mini: only epic/legendary.
    final shouldShimmer = isFull ||
        card.rarity == CardRarity.epic ||
        card.rarity == CardRarity.legendary;

    if (shouldShimmer) {
      final shimmerColor = Color(card.rarity.colorHex);
      final double shimmerAlpha = switch (card.rarity) {
        CardRarity.legendary => 0.35,
        CardRarity.epic => 0.25,
        _ => 0.15,
      };
      const shimmerDuration = 2500;

      cardContent = cardContent
          .animate(onPlay: (c) => c.repeat(reverse: true))
          .shimmer(
            duration: shimmerDuration.ms,
            color: shimmerColor.withValues(alpha: shimmerAlpha),
            angle: 0.5,
          );
    }

    return GestureDetector(
      onTap: onTap,
      child: AspectRatio(
        aspectRatio: 0.7, // ~ 2.5/3.5 standard card ratio
        child: cardContent,
      ),
    );
  }

  Widget _buildCardContent(bool isFull, Color rarityColor, Color rarityDark) {
    // Mini mode: only card name at top
    if (!isFull) {
      return Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              card.name,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.bodySmall(color: Colors.white).copyWith(fontWeight: FontWeight.w900, shadows: [
                  Shadow(
                    color: Colors.black,
                    offset: const Offset(0, 1),
                    blurRadius: 2,
                  ),
                ]),
            ),
            const Spacer(),
          ],
        ),
      );
    }

    // Full mode: completely clean — no text overlay (details in side panel)
    return const SizedBox.shrink();
  }

  Widget _buildCardImage(String url) {
    // Encode spaces for web compatibility
    final encodedUrl = url.replaceAll(' ', '%20');
    return CachedNetworkImage(
      imageUrl: encodedUrl,
      fit: BoxFit.cover,
      fadeInDuration: const Duration(milliseconds: 200),
      placeholder: (context, url) => Container(
        decoration: BoxDecoration(
          gradient: CardColors.getRarityGradient(card.rarity),
        ),
      ),
      errorWidget: (context, url, error) => _buildFallbackBackground(),
    );
  }

  Widget _buildFallbackBackground() {
    return Container(
      decoration: BoxDecoration(
        gradient: CardColors.getRarityGradient(card.rarity),
      ),
      child: Center(
        child: Opacity(
          opacity: 0.1,
          child: Text(
            card.categoryIcon ?? card.category.icon,
            style: const TextStyle(fontSize: 80),
          ),
        ),
      ),
    );
  }
}
