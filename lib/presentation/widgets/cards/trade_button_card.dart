import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/router.dart';
import '../../../app/theme.dart';
import '../../providers/card_trade_provider.dart';

class TradeButtonCard extends ConsumerWidget {
  const TradeButtonCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canTrade = ref.watch(canTradeProvider);
    if (!canTrade) return const SizedBox.shrink();

    return GestureDetector(
      onTap: () => context.push(AppRoutes.cardTrade),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: const LinearGradient(
            colors: [Color(0xFF00B894), Color(0xFF00CEC9)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Row(
          children: [
            const Icon(Icons.swap_horiz_rounded, color: Colors.white, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Trade Duplicates',
                style: GoogleFonts.nunito(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Colors.white70, size: 22),
          ],
        ),
      ),
    );
  }
}
