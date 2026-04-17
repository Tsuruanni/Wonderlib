import 'package:flutter/material.dart';
import 'package:owlio_shared/owlio_shared.dart';

/// Small circular badge showing a student's league tier (bronze → diamond).
/// Extracted from StudentProfileDialog so it can be reused in the teacher
/// Leaderboard report and any future surfaces.
class LeagueTierBadge extends StatelessWidget {
  const LeagueTierBadge({
    super.key,
    required this.tier,
    this.size = 32,
  });

  final LeagueTier tier;
  final double size;

  static Color tierColor(LeagueTier tier) {
    return switch (tier) {
      LeagueTier.diamond => const Color(0xFF00BFFF),
      LeagueTier.platinum => const Color(0xFFE5E4E2),
      LeagueTier.gold => const Color(0xFFFFD700),
      LeagueTier.silver => const Color(0xFFC0C0C0),
      LeagueTier.bronze => const Color(0xFFCD7F32),
    };
  }

  static String tierAsset(LeagueTier tier) {
    return switch (tier) {
      LeagueTier.bronze => 'assets/icons/rank-bronze-1_large.png',
      LeagueTier.silver => 'assets/icons/rank-silver-2_large.png',
      LeagueTier.gold => 'assets/icons/rank-gold-3_large.png',
      LeagueTier.platinum => 'assets/icons/rank-platinum-5_large.png',
      LeagueTier.diamond => 'assets/icons/rank-diamond-7_large.png',
    };
  }

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tier.label,
      child: Image.asset(
        tierAsset(tier),
        width: size,
        height: size,
        fit: BoxFit.contain,
      ),
    );
  }
}
