import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

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
                  colors: [
                    Colors.black.withValues(alpha: 0.1),
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.6),
                    Colors.black.withValues(alpha: 0.9),
                  ],
                  stops: const [0.0, 0.4, 0.7, 1.0],
                ),
              ),
            ),

            // Rarity / Frame Overlay (Border glow for high rarity)
            if (card.rarity == CardRarity.legendary ||
                card.rarity == CardRarity.epic)
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(2),
                  border: Border.all(
                    color: rarityColor.withValues(alpha: 0.3),
                    width: 4,
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
                    style: GoogleFonts.nunito(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: AppColors.white,
                    ),
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
                    style: GoogleFonts.nunito(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: AppColors.white,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );

    // Apply shimmer to high rarity cards
    if (card.rarity == CardRarity.epic) {
      cardContent = cardContent
          .animate(onPlay: (c) => c.repeat(reverse: true))
          .shimmer(
            duration: 3000.ms,
            color: AppColors.cardEpic.withValues(alpha: 0.2),
            angle: 0.5,
          );
    } else if (card.rarity == CardRarity.legendary) {
      cardContent = cardContent
          .animate(onPlay: (c) => c.repeat(reverse: true))
          .shimmer(
            duration: 2500.ms,
            color: AppColors.cardLegendary.withValues(alpha: 0.3),
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
    // Mini mode: only card name at bottom
    if (!isFull) {
      return Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Spacer(),
            Text(
              card.name,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.nunito(
                fontSize: 13,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                shadows: [
                  Shadow(
                    color: Colors.black,
                    offset: const Offset(0, 1),
                    blurRadius: 2,
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // Full mode: category icon, power, name, stars, description, skill
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Top Row: Category Icon & Power
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.4),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  card.categoryIcon ?? card.category.icon,
                  style: const TextStyle(fontSize: 24),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: AppColors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: rarityColor.withValues(alpha: 0.6),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset(
                      'assets/icons/xp_green_outline.png',
                      width: 16.0,
                      height: 16.0,
                      filterQuality: FilterQuality.high,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      '${card.power}',
                      style: GoogleFonts.nunito(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const Spacer(),

          // Bottom Content: Name, Rarity, Desc/Skill
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                card.name,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.nunito(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  shadows: [
                    Shadow(
                      color: Colors.black,
                      offset: const Offset(0, 1),
                      blurRadius: 2,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                CardColors.getRarityStars(card.rarity),
                style: TextStyle(
                  fontSize: 16,
                  color: rarityColor,
                  shadows: const [
                    Shadow(
                      color: Colors.black,
                      offset: Offset(0, 1),
                      blurRadius: 2,
                    ),
                  ],
                ),
              ),

              // Full Variant Extras
              if (isFull) ...[
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Container(
                    height: 1,
                    color: Colors.white.withValues(alpha: 0.2),
                  ),
                ),
                const SizedBox(height: 12),
                if (card.specialSkill != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: rarityColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: rarityColor.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Text(
                      'Skill: ${card.specialSkill}',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.nunito(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color.lerp(
                            rarityColor, Colors.white, 0.7),
                      ),
                    ),
                  ),
                if (card.description != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    card.description!,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.nunito(
                      fontSize: 13,
                      color:
                          Colors.white.withValues(alpha: 0.9),
                      height: 1.4,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCardImage(String url) {
    return CachedNetworkImage(
      imageUrl: url,
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
