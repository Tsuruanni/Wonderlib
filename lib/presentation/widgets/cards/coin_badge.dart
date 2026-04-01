import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/theme.dart';

/// A compact coin balance badge: gold coin icon + amount.
///
/// Used in the app bar and card collection header.
class CoinBadge extends StatelessWidget {
  const CoinBadge({
    super.key,
    required this.coins,
    this.fontSize = 14,
  });

  final int coins;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.waspBackground,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.wasp.withValues(alpha: 0.4),
          width: 1.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            'assets/icons/gem_outline_256.png',
            width: fontSize + 4,
            height: fontSize + 4,
            filterQuality: FilterQuality.high,
          ),
          const SizedBox(width: 4),
          Text(
            _formatCoins(coins),
            style: GoogleFonts.nunito(
              fontSize: fontSize,
              fontWeight: FontWeight.w800,
              color: AppColors.waspDark,
            ),
          ),
        ],
      ),
    );
  }

  String _formatCoins(int coins) {
    if (coins >= 10000) {
      return '${(coins / 1000).toStringAsFixed(1)}K';
    }
    return coins.toString();
  }
}
