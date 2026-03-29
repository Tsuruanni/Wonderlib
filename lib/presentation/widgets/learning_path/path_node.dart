import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/theme.dart';

/// Node types on the learning path.
enum NodeType {
  wordList(Icons.menu_book_rounded, AppColors.secondary, Color(0xFF1899D6)),
  book(Icons.auto_stories_rounded, Color(0xFF1565C0), Color(0xFFE3F2FD)),
  game(Icons.sports_esports_rounded, Color(0xFF7B1FA2), Color(0xFFF3E5F5)),
  treasure(Icons.card_giftcard_rounded, AppColors.cardLegendary, Color(0xFFFFF8E1)),
  review(Icons.style_rounded, Color(0xFFE65100), Color(0xFFFFF3E0));

  const NodeType(this.icon, this.color, this.bgColor);
  final IconData icon;
  final Color color;
  final Color bgColor;
}

/// Visual state of a node.
enum NodeState { locked, available, active, completed }

/// Universal node widget for the learning path.
/// Renders all node types and states. Receives all data as props — no providers.
class PathNode extends StatelessWidget {
  const PathNode({
    super.key,
    required this.type,
    required this.state,
    this.label,
    this.onTap,
    this.starCount = 0,
  });

  final NodeType type;
  final NodeState state;
  final String? label;
  final VoidCallback? onTap;
  final int starCount;

  static const _size = 64.0;

  @override
  Widget build(BuildContext context) {
    final isLocked = state == NodeState.locked;
    final isCompleted = state == NodeState.completed;

    return GestureDetector(
      onTap: isLocked ? null : onTap,
      child: SizedBox(
        width: 140,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Node circle
            _NodeCircle(
              type: type,
              state: state,
              size: _size,
            ),
            // Star row (only for word lists with progress)
            if (type == NodeType.wordList && starCount > 0 && !isLocked)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: _StarRow(count: starCount, color: type.color),
              ),
            // Label
            if (label != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  label!,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.nunito(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isLocked
                        ? AppColors.neutralText
                        : isCompleted
                            ? AppColors.primary
                            : AppColors.black,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// The circular node icon.
class _NodeCircle extends StatelessWidget {
  const _NodeCircle({
    required this.type,
    required this.state,
    required this.size,
  });

  final NodeType type;
  final NodeState state;
  final double size;

  @override
  Widget build(BuildContext context) {
    final isLocked = state == NodeState.locked;
    final isCompleted = state == NodeState.completed;

    final bgColor = isLocked ? AppColors.neutral : type.bgColor;
    final iconColor = isLocked ? AppColors.neutralText : type.color;
    final borderColor = isLocked
        ? AppColors.neutral
        : isCompleted
            ? AppColors.primary
            : type.color;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bgColor,
        shape: BoxShape.circle,
        border: Border.all(color: borderColor, width: 3),
        boxShadow: isLocked
            ? null
            : [
                BoxShadow(
                  color: borderColor.withValues(alpha: 0.3),
                  offset: const Offset(0, 4),
                  blurRadius: 0,
                ),
              ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(
            isLocked ? Icons.lock_rounded : type.icon,
            color: iconColor,
            size: size * 0.45,
          ),
          // Completed check overlay
          if (isCompleted)
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: const Icon(Icons.check_rounded, color: Colors.white, size: 14),
              ),
            ),
        ],
      ),
    );
  }
}

/// Row of 1-3 stars below a word list node.
class _StarRow extends StatelessWidget {
  const _StarRow({required this.count, required this.color});

  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        final filled = i < count;
        return Icon(
          filled ? Icons.star_rounded : Icons.star_outline_rounded,
          size: 16,
          color: filled ? color : AppColors.neutral,
        );
      }),
    );
  }
}
