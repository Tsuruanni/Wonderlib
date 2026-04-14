import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/theme.dart';
import '../../utils/app_icons.dart';

/// Data needed to display the word list progress bottom sheet.
class NodeProgressData {
  const NodeProgressData({
    required this.name,
    required this.totalSessions,
    this.bestAccuracy,
    this.bestScore,
    required this.starCount,
    required this.unitColor,
  });

  final String name;
  final int totalSessions;
  final double? bestAccuracy;
  final int? bestScore;
  final int starCount;
  final Color unitColor;
}

/// Shows a bottom sheet with word list progress details.
/// All data passed as props — no provider reads.
void showNodeProgressSheet(
  BuildContext context, {
  required NodeProgressData data,
  required VoidCallback onPractice,
}) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (context) => _ProgressSheetContent(
      data: data,
      onPractice: onPractice,
    ),
  );
}

class _ProgressSheetContent extends StatelessWidget {
  const _ProgressSheetContent({
    required this.data,
    required this.onPractice,
  });

  final NodeProgressData data;
  final VoidCallback onPractice;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: AppColors.neutral,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Title
          Text(
            data.name,
            style: GoogleFonts.nunito(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.black,
            ),
          ),
          const SizedBox(height: 12),
          // Stars
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(3, (i) {
              final filled = i < data.starCount;
              return filled
                  ? AppIcons.star(size: 32)
                  : Icon(
                      Icons.star_outline_rounded,
                      size: 32,
                      color: AppColors.neutral,
                    );
            }),
          ),
          const SizedBox(height: 16),
          // Stats row
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _StatColumn(
                  icon: Icon(Icons.repeat_rounded, color: AppColors.neutralText, size: 20),
                  value: '${data.totalSessions}',
                  label: 'Sessions',
                ),
                _StatColumn(
                  icon: AppIcons.star(size: 20),
                  value: data.bestAccuracy != null
                      ? '${data.bestAccuracy!.toInt()}%'
                      : '--',
                  label: 'Best',
                ),
                _StatColumn(
                  icon: Icon(Icons.bolt_rounded, color: AppColors.neutralText, size: 20),
                  value: data.bestScore != null ? '${data.bestScore}' : '--',
                  label: 'Top Coins',
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // Practice button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                onPractice();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: data.unitColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              child: Text(
                'PRACTICE',
                style: GoogleFonts.nunito(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatColumn extends StatelessWidget {
  const _StatColumn({
    required this.icon,
    required this.value,
    required this.label,
  });

  final Widget icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        icon,
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.nunito(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppColors.black,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.nunito(
            fontSize: 11,
            color: AppColors.neutralText,
          ),
        ),
      ],
    );
  }
}
