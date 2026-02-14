import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../domain/entities/card.dart';
import '../../utils/ui_helpers.dart';

/// Displays a locked/undiscovered card as a dark silhouette.
///
/// Shows a subtle rarity-colored border hint and the category emoji dimmed.
/// Tapping reveals the card name + "Not yet discovered" message.
class LockedCardWidget extends StatelessWidget {
  const LockedCardWidget({
    super.key,
    required this.card,
    this.onTap,
  });

  final MythCard card;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final rarityColor = CardColors.getRarityColor(card.rarity);

    return GestureDetector(
      onTap: onTap,
      child: AspectRatio(
        aspectRatio: 0.7, // ~ 2.5/3.5 standard card ratio
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFFE0E0E0),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: rarityColor.withValues(alpha: 0.3),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withValues(alpha: 0.2),
                offset: const Offset(0, 3),
                blurRadius: 0,
              ),
            ],
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Pattern / Noise (Simulated with simple gradient for now)
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.grey[200]!,
                      Colors.grey[300]!,
                    ],
                  ),
                ),
              ),
              
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Lock Icon
                    Icon(
                      Icons.lock_rounded,
                      size: 32,
                      color: AppColors.neutralText.withValues(alpha: 0.4),
                    ),
                    const SizedBox(height: 8),
                    // Question mark or Hint
                    Text(
                      '?',
                      style: TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.w900,
                        color: AppColors.neutralText.withValues(alpha: 0.2),
                      ),
                    ),
                  ],
                ),
              ),
              
              // Rarity hint at bottom
              Positioned(
                bottom: 12,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: rarityColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      card.category.icon,
                      style: TextStyle(
                        fontSize: 16,
                        color: rarityColor.withValues(alpha: 0.5),
                        shadows: [
                          Shadow(
                            color: Colors.white,
                            blurRadius: 4,
                          ),
                        ],
                      ),
                    ),
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
