import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';

import '../../../app/router.dart';
import '../../../app/theme.dart';
import '../../../domain/entities/vocabulary_unit.dart';
import '../common/pressable_scale.dart';

// ============================================================
// Shared helpers
// ============================================================

/// Deterministic rotation for a node.
double _nodeRotation(int globalRowIndex, int seed) {
  final random = Random(globalRowIndex * seed);
  return (random.nextDouble() - 0.5) * 0.5;
}

/// Sine offset for a given row index (shared with PathRow).
double _sineOffset(double screenWidth, int globalRowIndex) {
  final amplitude = screenWidth * 0.2;
  return sin(globalRowIndex * pi / 3) * amplitude;
}

/// Calculates left position for the 286px-wide Row container,
/// matching PathRow._nodeLeft() exactly.
double _rowLeftEdge(double screenWidth, int globalRowIndex, bool isLeftLabel) {
  const sideWidth = 286.0;
  final sineOffset = _sineOffset(screenWidth, globalRowIndex);
  final centerX = screenWidth / 2;
  final rowCenterX = centerX + sineOffset;
  final x = rowCenterX.clamp(sideWidth / 2, screenWidth - sideWidth / 2);
  double leftEdge;
  if (!isLeftLabel) {
    leftEdge = x - 38;
  } else {
    leftEdge = x - 248;
  }
  return leftEdge.clamp(0, screenWidth - sideWidth);
}

void _showLockedSnackbar(BuildContext context) {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Complete previous steps to unlock!')),
  );
}

// ============================================================
// Unit Banner
// ============================================================

/// Centered unit banner — a wide pill with unit number and name.
class PathUnitBanner extends StatelessWidget {
  const PathUnitBanner({
    super.key,
    required this.unit,
    required this.unitIndex,
    this.isLocked = false,
  });

  final VocabularyUnit unit;
  final int unitIndex;
  final bool isLocked;

  @override
  Widget build(BuildContext context) {
    final color = isLocked ? AppColors.neutral : unit.parsedColor;

    return SizedBox(
      height: 56,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'UNIT $unitIndex',
                style: GoogleFonts.nunito(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: Colors.white.withValues(alpha: 0.9),
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                unit.name,
                style: GoogleFonts.nunito(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              if (isLocked) ...[
                const SizedBox(width: 8),
                const Icon(Icons.lock, color: Colors.white, size: 16),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// Special Node Base — shared circle layout
// ============================================================

/// Shared label style for special nodes (matches PathNode label style exactly).
TextStyle _nodeLabelStyle() => GoogleFonts.patrickHand(
      fontSize: 22,
      fontWeight: FontWeight.w700,
      color: Colors.white,
      letterSpacing: 0.5,
      shadows: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.6),
          offset: const Offset(0, 2),
          blurRadius: 4,
        ),
      ],
    );

/// Reusable circle node with lock/complete/active states and side label.
/// Uses the same Row-based layout as PathNode (label left/right of circle).
class _SpecialNodeCircle extends StatelessWidget {
  const _SpecialNodeCircle({
    required this.globalRowIndex,
    required this.seedMultiplier,
    required this.bgColor,
    required this.icon,
    required this.iconColor,
    required this.label,
    this.isLocked = false,
    this.isComplete = false,
    this.isActive = false,
    this.onTap,
  });

  final int globalRowIndex;
  final int seedMultiplier;
  final Color bgColor;
  final IconData icon;
  final Color iconColor;
  final String label;
  final bool isLocked;
  final bool isComplete;
  final bool isActive;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final sineOffset = _sineOffset(screenWidth, globalRowIndex);
    final isLeftLabel = sineOffset > 0;
    final rotation = _nodeRotation(globalRowIndex, seedMultiplier);

    // Visual states — show original icon in gray when locked (no lock icon)
    final effectiveBg = isLocked ? AppColors.neutral : bgColor;
    final effectiveIcon = isComplete ? Icons.check_rounded : icon;
    final effectiveIconColor = isLocked
        ? AppColors.neutralText
        : isComplete
            ? Colors.white
            : iconColor;

    // Border color: green ring for complete, neutral otherwise
    final borderColor = isComplete && !isLocked
        ? AppColors.primary
        : AppColors.neutral;

    // Background for complete state
    final circleBg = isComplete && !isLocked
        ? AppColors.primary
        : effectiveBg;

    Widget circleWidget = Transform.rotate(
      angle: rotation,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: circleBg,
          border: Border.all(color: borderColor, width: 2),
          boxShadow: [
            BoxShadow(
              color: AppColors.neutralDark.withValues(alpha: 0.6),
              offset: const Offset(0, 8),
              blurRadius: 0,
            ),
          ],
        ),
        child: Center(
          child: Icon(effectiveIcon, color: effectiveIconColor, size: 28),
        ),
      ),
    );

    // Bounce animation for active node
    if (isActive && !isLocked && !isComplete) {
      circleWidget = _BounceWrapper(child: circleWidget);
    }

    // Wrap circle in 76px container to match PathNode sizing
    final nodeContainer = SizedBox(
      width: 76,
      height: 76,
      child: Center(child: circleWidget),
    );

    // Side label (same style & layout as PathNode)
    final labelWidget = SizedBox(
      width: 140,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: isLeftLabel ? Alignment.centerRight : Alignment.centerLeft,
        child: Text(
          label,
          textAlign: isLeftLabel ? TextAlign.right : TextAlign.left,
          maxLines: 1,
          style: _nodeLabelStyle(),
        ),
      ),
    );

    final rowChildren = isLeftLabel
        ? [labelWidget, const SizedBox(width: 70), nodeContainer]
        : [nodeContainer, const SizedBox(width: 70), labelWidget];

    final leftEdge = _rowLeftEdge(screenWidth, globalRowIndex, isLeftLabel);

    return PressableScale(
      onTap: onTap,
      child: SizedBox(
        height: 80,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: leftEdge,
              top: 0,
              child: SizedBox(
                width: 286,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: rowChildren,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Simple bounce animation widget (matches PathNode's bounce).
class _BounceWrapper extends StatefulWidget {
  const _BounceWrapper({required this.child});
  final Widget child;

  @override
  State<_BounceWrapper> createState() => _BounceWrapperState();
}

class _BounceWrapperState extends State<_BounceWrapper>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(scale: _animation, child: widget.child);
  }
}

// ============================================================
// Flipbook Node
// ============================================================

class PathFlipbookNode extends StatelessWidget {
  const PathFlipbookNode({
    super.key,
    required this.globalRowIndex,
    this.isLocked = false,
    this.isComplete = false,
    this.isActive = false,
    this.onComplete,
  });

  final int globalRowIndex;
  final bool isLocked;
  final bool isComplete;
  final bool isActive;
  final VoidCallback? onComplete;

  @override
  Widget build(BuildContext context) {
    return _SpecialNodeCircle(
      globalRowIndex: globalRowIndex,
      seedMultiplier: 999,
      bgColor: const Color(0xFFE0F7FA),
      icon: Icons.menu_book_rounded,
      iconColor: const Color(0xFF006064),
      label: 'Flipbook',
      isLocked: isLocked,
      isComplete: isComplete,
      isActive: isActive,
      onTap: () {
        if (isLocked) {
          _showLockedSnackbar(context);
          return;
        }
        if (!isComplete) {
          HapticFeedback.mediumImpact();
          onComplete?.call();
        }
      },
    );
  }
}

// ============================================================
// Daily Review Node
// ============================================================

class PathDailyReviewNode extends StatelessWidget {
  const PathDailyReviewNode({
    super.key,
    required this.globalRowIndex,
    required this.unitId,
    this.isLocked = false,
    this.isComplete = false,
    this.isActive = false,
  });

  final int globalRowIndex;
  final String unitId;
  final bool isLocked;
  final bool isComplete;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return _SpecialNodeCircle(
      globalRowIndex: globalRowIndex,
      seedMultiplier: 555,
      bgColor: const Color(0xFFFFF3E0),
      icon: Icons.style_rounded,
      iconColor: const Color(0xFFE65100),
      label: 'Review',
      isLocked: isLocked,
      isComplete: isComplete,
      isActive: isActive,
      onTap: () {
        if (isLocked) {
          _showLockedSnackbar(context);
          return;
        }
        // Navigate to unit review (even if already complete — allow re-review)
        context.push(AppRoutes.vocabularyUnitReviewPath(unitId));
      },
    );
  }
}

// ============================================================
// Game Node
// ============================================================

class PathGameNode extends StatelessWidget {
  const PathGameNode({
    super.key,
    required this.globalRowIndex,
    this.isLocked = false,
    this.isComplete = false,
    this.isActive = false,
    this.onComplete,
  });

  final int globalRowIndex;
  final bool isLocked;
  final bool isComplete;
  final bool isActive;
  final VoidCallback? onComplete;

  @override
  Widget build(BuildContext context) {
    return _SpecialNodeCircle(
      globalRowIndex: globalRowIndex,
      seedMultiplier: 777,
      bgColor: const Color(0xFFF3E5F5),
      icon: Icons.sports_esports_rounded,
      iconColor: const Color(0xFF7B1FA2),
      label: 'Game',
      isLocked: isLocked,
      isComplete: isComplete,
      isActive: isActive,
      onTap: () {
        if (isLocked) {
          _showLockedSnackbar(context);
          return;
        }
        if (!isComplete) {
          HapticFeedback.mediumImpact();
          onComplete?.call();
        }
      },
    );
  }
}

// ============================================================
// Treasure Node
// ============================================================

class PathTreasureNode extends StatelessWidget {
  const PathTreasureNode({
    super.key,
    required this.isUnitComplete,
    required this.globalRowIndex,
    this.isLocked = false,
    this.isActive = false,
    this.onComplete,
  });

  final bool isUnitComplete;
  final int globalRowIndex;
  final bool isLocked;
  final bool isActive;
  final VoidCallback? onComplete;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final sineOffset = _sineOffset(screenWidth, globalRowIndex);
    final isLeftLabel = sineOffset > 0;

    // Build the visual content (circle or Lottie)
    Widget nodeVisual;
    if (isLocked) {
      // Locked: gray circle with treasure icon in gray
      nodeVisual = Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.neutral,
          border: Border.all(color: AppColors.neutral, width: 2),
          boxShadow: [
            BoxShadow(
              color: AppColors.neutralDark.withValues(alpha: 0.6),
              offset: const Offset(0, 8),
              blurRadius: 0,
            ),
          ],
        ),
        child: const Center(
          child: Icon(Icons.card_giftcard_rounded, color: AppColors.neutralText, size: 28),
        ),
      );
    } else {
      // Unlocked: Lottie treasure animation
      nodeVisual = Lottie.asset(
        'assets/animations/Treasure Box Animation.json',
        width: 76,
        height: 76,
        fit: BoxFit.contain,
      );
      if (isActive) {
        nodeVisual = _BounceWrapper(child: nodeVisual);
      }
    }

    // Wrap in 76px container to match PathNode sizing
    final nodeContainer = SizedBox(
      width: 76,
      height: 76,
      child: Center(child: nodeVisual),
    );

    // Side label
    final labelWidget = SizedBox(
      width: 140,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: isLeftLabel ? Alignment.centerRight : Alignment.centerLeft,
        child: Text(
          'Treasure',
          textAlign: isLeftLabel ? TextAlign.right : TextAlign.left,
          maxLines: 1,
          style: _nodeLabelStyle(),
        ),
      ),
    );

    final rowChildren = isLeftLabel
        ? [labelWidget, const SizedBox(width: 70), nodeContainer]
        : [nodeContainer, const SizedBox(width: 70), labelWidget];

    final leftEdge = _rowLeftEdge(screenWidth, globalRowIndex, isLeftLabel);

    return PressableScale(
      onTap: () {
        if (isLocked) {
          _showLockedSnackbar(context);
          return;
        }
        if (!isUnitComplete) {
          HapticFeedback.mediumImpact();
          onComplete?.call();
        }
      },
      child: SizedBox(
        height: 80,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: leftEdge,
              top: 0,
              child: SizedBox(
                width: 286,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: rowChildren,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
