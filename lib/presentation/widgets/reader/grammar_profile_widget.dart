import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/theme.dart';

/// Placeholder for the upcoming Grammar Profile feature shown as a right-side
/// column in the teacher reader view. Content to be filled in later — for now
/// just a labelled empty card so the layout can be validated.
class GrammarProfileWidget extends StatelessWidget {
  const GrammarProfileWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 320,
      decoration: const BoxDecoration(
        color: AppColors.white,
        border: Border(
          left: BorderSide(color: AppColors.neutral, width: 2),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Grammar Profile',
                style: GoogleFonts.nunito(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.black,
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: Center(
                  child: Text(
                    'Coming soon',
                    style: GoogleFonts.nunito(
                      fontSize: 13,
                      color: AppColors.neutralText,
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
