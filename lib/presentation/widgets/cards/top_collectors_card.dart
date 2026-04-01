import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/theme.dart';
import '../../../domain/entities/card.dart';
import '../../providers/auth_provider.dart';
import '../../providers/card_provider.dart';

class TopCollectorsCard extends ConsumerWidget {
  const TopCollectorsCard({super.key});

  static const _medalIcons = ['🥇', '🥈', '🥉'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(classTopCollectorsProvider);

    return async.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (result) {
        if (result.top3.isEmpty) return const SizedBox.shrink();

        final userId = ref.watch(currentUserIdProvider);
        final callerInTop3 =
            result.top3.any((e) => e.userId == userId);

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
                'Top Collectors',
                style: GoogleFonts.nunito(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: AppColors.black,
                ),
              ),
              const SizedBox(height: 12),
              for (final entry in result.top3) ...[
                _buildRow(
                  entry,
                  isCurrentUser: entry.userId == userId,
                ),
                if (entry != result.top3.last ||
                    (!callerInTop3 && result.caller != null))
                  const SizedBox(height: 8),
              ],
              if (!callerInTop3 && result.caller != null) ...[
                const Divider(height: 16),
                _buildRow(
                  result.caller!,
                  isCurrentUser: true,
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildRow(TopCollectorEntry entry, {required bool isCurrentUser}) {
    final medal = entry.rank <= 3 ? _medalIcons[entry.rank - 1] : null;

    return Row(
      children: [
        SizedBox(
          width: 28,
          child: medal != null
              ? Text(medal, style: const TextStyle(fontSize: 18))
              : Text(
                  '#${entry.rank}',
                  style: GoogleFonts.nunito(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.neutralText,
                  ),
                ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            entry.firstName,
            style: GoogleFonts.nunito(
              fontSize: 14,
              fontWeight: isCurrentUser ? FontWeight.w800 : FontWeight.w600,
              color: isCurrentUser ? AppColors.secondary : AppColors.black,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Text(
          '${entry.uniqueCards} cards',
          style: GoogleFonts.nunito(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.neutralText,
          ),
        ),
      ],
    );
  }
}
