import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/theme.dart';
import '../../providers/teacher_preview_provider.dart';

/// Thin banner rendered beneath the reader AppBar when the current user is a
/// teacher. Communicates that answers are revealed and no progress is saved,
/// so the teacher cannot mistake the preview state for a broken student view.
class TeacherPreviewBanner extends ConsumerWidget {
  const TeacherPreviewBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPreview = ref.watch(isTeacherPreviewModeProvider);
    if (!isPreview) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: AppColors.wasp.withValues(alpha: 0.18),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.visibility_outlined,
            size: 16,
            color: AppColors.waspDark,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              'Teacher Preview — answers shown, no progress saved',
              style: GoogleFonts.nunito(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.waspDark,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
