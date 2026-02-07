import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/theme.dart';
import '../../../domain/entities/word_list.dart';
import '../../providers/vocabulary_provider.dart';
import '../common/pressable_scale.dart';

/// Controls whether the text label appears below, to the left, or to the right of the node circle.
enum LabelPosition { below, left, right }

/// A single node on the learning path representing one word list.
/// Shows a 3D circle with icon, crown badge (if complete), stars (if started),
/// bounce animation + "START" pill (if active), and press-down feedback.
class PathNode extends StatefulWidget {
  const PathNode({
    super.key,
    required this.wordListWithProgress,
    required this.unitColor,
    this.isActive = false,
    this.isLocked = false,
    this.labelPosition = LabelPosition.below,
  });

  final WordListWithProgress wordListWithProgress;
  final Color unitColor;
  final bool isActive;
  final bool isLocked;
  final LabelPosition labelPosition;

  @override
  State<PathNode> createState() => _PathNodeState();
}

class _PathNodeState extends State<PathNode>
    with SingleTickerProviderStateMixin {
  AnimationController? _bounceController;
  late Animation<double> _bounceAnimation;

  @override
  void initState() {
    super.initState();
    _setupBounce();
  }

  @override
  void didUpdateWidget(PathNode oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isActive != widget.isActive) {
      _setupBounce();
    }
  }

  void _setupBounce() {
    if (widget.isActive && !widget.isLocked) {
      _bounceController ??= AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1200),
      );
      _bounceAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
        CurvedAnimation(
          parent: _bounceController!,
          curve: Curves.easeInOut,
        ),
      );
      _bounceController!.repeat(reverse: true);
    } else {
      _bounceController?.stop();
      _bounceController?.dispose();
      _bounceController = null;
    }
  }

  @override
  void dispose() {
    _bounceController?.dispose();
    super.dispose();
  }

  void _handleTap(BuildContext context) {
    if (widget.isLocked) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              'Complete the previous unit to unlock',
              style: GoogleFonts.nunito(fontWeight: FontWeight.w700),
            ),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      return;
    }
    final id = widget.wordListWithProgress.wordList.id;
    context.push('/vocabulary/list/$id');
  }

  @override
  Widget build(BuildContext context) {
    final wordList = widget.wordListWithProgress.wordList;
    final isComplete = widget.wordListWithProgress.isComplete;
    final isStarted = widget.wordListWithProgress.isStarted;
    final isLocked = widget.isLocked;

    final nodeColor = isLocked
        ? AppColors.neutral
        : isComplete
            ? _getStarColor(widget.wordListWithProgress.starCount, widget.unitColor)
            : (isStarted || widget.isActive)
                ? widget.unitColor
                : AppColors.white;

    final shadowColor = _darken(nodeColor, 0.20);

    Widget nodeWidget = _buildNodeCircle(
      wordList: wordList,
      isComplete: isComplete && !isLocked,
      isStarted: isStarted && !isLocked,
      isLocked: isLocked,
      nodeColor: nodeColor,
      shadowColor: shadowColor,
    );

    // Wrap with bounce animation if active and not locked
    if (widget.isActive && !isLocked && _bounceController != null) {
      nodeWidget = AnimatedBuilder(
        animation: _bounceAnimation,
        builder: (context, child) => Transform.scale(
          scale: _bounceAnimation.value,
          child: child,
        ),
        child: nodeWidget,
      );
    }

    final labelStyle = GoogleFonts.nunito(
      fontSize: 11,
      fontWeight: FontWeight.w800,
      color: !isLocked && (isStarted || widget.isActive)
          ? AppColors.black
          : AppColors.neutralText,
    );

    if (widget.labelPosition == LabelPosition.below) {
      return PressableScale(
        pressedScale: 0.92,
        onTap: () => _handleTap(context),
        child: SizedBox(
          width: 92,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              nodeWidget,
              const SizedBox(height: 6),
              if (widget.isActive && !isLocked) _buildStartPill(),
              if (widget.isActive && !isLocked) const SizedBox(height: 2),
              Text(
                wordList.name,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: labelStyle,
              ),
            ],
          ),
        ),
      );
    }

    // Side label layout (left or right)
    // Note: START pill is rendered by _PathRow (parent) so it's in the
    // full-width Stack and tappable outside PathNode's 164px bounds.
    final isLeft = widget.labelPosition == LabelPosition.left;

    final labelWidget = SizedBox(
      width: 80,
      child: Text(
        wordList.name,
        textAlign: isLeft ? TextAlign.right : TextAlign.left,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: labelStyle,
      ),
    );

    final rowChildren = isLeft
        ? [labelWidget, const SizedBox(width: 8), nodeWidget]
        : [nodeWidget, const SizedBox(width: 8), labelWidget];

    return PressableScale(
      pressedScale: 0.92,
      onTap: () => _handleTap(context),
      child: SizedBox(
        width: 164,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: rowChildren,
        ),
      ),
    );
  }

  Widget _buildNodeCircle({
    required WordList wordList,
    required bool isComplete,
    required bool isStarted,
    required bool isLocked,
    required Color nodeColor,
    required Color shadowColor,
  }) {
    final showGlow = widget.isActive && !isLocked;
    final stars = widget.wordListWithProgress.starCount;

    return SizedBox(
      width: 76,
      height: 88, // Extra height for crown overflow + shadow + stars
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          // Glow ring for active node
          if (showGlow)
            Positioned(
              top: 4,
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.30),
                      blurRadius: 14,
                      spreadRadius: 3,
                    ),
                  ],
                ),
              ),
            ),
          // Inner 3D circle
          Positioned(
            top: 4,
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: nodeColor,
                border: !isStarted && !widget.isActive && !isLocked
                    ? Border.all(color: AppColors.neutral, width: 2)
                    : null,
                boxShadow: [
                  BoxShadow(
                    color: isLocked
                        ? AppColors.neutralDark.withValues(alpha: 0.5)
                        : isStarted || isComplete || widget.isActive
                            ? shadowColor
                            : AppColors.neutralDark.withValues(alpha: 0.5),
                    offset: const Offset(0, 4),
                    blurRadius: 0,
                  ),
                ],
              ),
              child: Center(
                child: isLocked
                    ? const Icon(
                        Icons.lock_rounded,
                        color: Colors.white,
                        size: 24,
                      )
                    : isComplete
                        ? const Icon(
                            Icons.check_rounded,
                            color: Colors.white,
                            size: 28,
                          )
                        : Text(
                            wordList.category.icon,
                            style: TextStyle(
                              fontSize: 24,
                              color: isStarted || widget.isActive
                                  ? null
                                  : AppColors.neutralText,
                            ),
                          ),
              ),
            ),
          ),
          // Crown badge removed by user request
          // Stars for nodes with progress
          if (stars > 0 && !isLocked)
            Positioned(
              top: 64,
              child: _buildStars(stars),
            ),
        ],
      ),
    );
  }

  /// Build 3 small stars showing accuracy-based progress (1★=complete, 2★=≥80%, 3★=≥95%).
  Widget _buildStars(int starCount) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        final filled = i < starCount;
        return Icon(
          filled ? Icons.star_rounded : Icons.star_border_rounded,
          size: 14,
          color: filled ? AppColors.wasp : AppColors.neutralDark,
        );
      }),
    );
  }

  Widget _buildStartPill() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
            color: AppColors.primaryDark,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Text(
        'START',
        style: GoogleFonts.nunito(
          fontSize: 13,
          fontWeight: FontWeight.w900,
          color: Colors.white,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  /// Darken a color by reducing its lightness in HSL space.
  Color _darken(Color color, double amount) {
    final hsl = HSLColor.fromColor(color);
    return hsl
        .withLightness((hsl.lightness - amount).clamp(0.0, 1.0))
        .toColor();
  }
  Color _getStarColor(int stars, Color defaultColor) {
    if (stars >= 3) return const Color(0xFFFFD700); // Gold
    if (stars == 2) return const Color(0xFFE0E0E0); // Lighter Silver
    if (stars == 1) return const Color(0xFFCD7F32); // Bronze
    return defaultColor;
  }
}
