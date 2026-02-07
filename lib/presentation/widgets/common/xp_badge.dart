import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

class XPBadge extends StatelessWidget {
  const XPBadge({
    super.key,
    required this.xp,
    required this.onComplete,
  });

  final int xp;
  final VoidCallback onComplete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFFFC800), // Gold/Yellow
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFE5A100), // Darker Gold
          width: 2,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x66E5A100),
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.monetization_on,
            color: Colors.white,
            size: 20,
          ),
          const SizedBox(width: 4),
          Text(
            '+$xp',
            style: GoogleFonts.nunito(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: Colors.white, // Dark Brown text on Gold
              shadows: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  offset: const Offset(0, 1),
                  blurRadius: 0,
                ),
              ],
            ),
          ),
        ],
      ),
    )
    .animate(onComplete: (controller) => onComplete())
    .scale(
      duration: 400.ms,
      curve: Curves.elasticOut,
      begin: const Offset(0.5, 0.5),
      end: const Offset(1, 1),
    )
    .moveY(
      delay: 500.ms,
      duration: 600.ms,
      begin: 0,
      end: -40, // Float up
      curve: Curves.easeOut,
    )
    .fadeOut(
      delay: 800.ms,
      duration: 300.ms,
    );
  }
}
