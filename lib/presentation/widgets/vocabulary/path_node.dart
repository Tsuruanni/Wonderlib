import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/router.dart';
import '../../../app/theme.dart';
import '../../../domain/entities/word_list.dart';
import '../../providers/vocabulary_provider.dart';
import '../../utils/ui_helpers.dart';
import 'path_special_nodes.dart' show pathNodeLabelStyle;
import '../common/pressable_scale.dart';

/// Controls whether the text label appears to the left or to the right of the node circle.
enum LabelPosition { left, right }

/// A single node on the learning path representing one word list.
/// Shows a 3D circle with icon, crown badge (if complete), stars (if started),
/// bounce animation + "START" pill (if active), and press-down feedback.
class PathNode extends ConsumerStatefulWidget {
  const PathNode({
    super.key,
    required this.wordListWithProgress,
    required this.unitColor,
    this.isActive = false,
    this.isLocked = false,
    this.canStartNewList = true,
    this.labelPosition = LabelPosition.left,
  });

  final WordListWithProgress wordListWithProgress;
  final Color unitColor;
  final bool isActive;
  final bool isLocked;
  /// Whether a NEW word list (no progress) can be started (daily limit not reached).
  final bool canStartNewList;
  final LabelPosition labelPosition;

  @override
  ConsumerState<PathNode> createState() => _PathNodeState();
}

class _PathNodeState extends ConsumerState<PathNode>
    with SingleTickerProviderStateMixin {
  AnimationController? _bounceController;
  late Animation<double> _bounceAnimation;



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
      showAppSnackBar(context, 'Complete previous steps to unlock!');
      return;
    }

    // Check if daily review gate is active
    final drNeeded = ref.read(dailyReviewNeededProvider).valueOrNull ?? false;
    if (drNeeded) {
      if (!context.mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Daily Review'),
          content: const Text('Complete your daily word review first!'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                context.push(AppRoutes.vocabularyDailyReview);
              },
              child: const Text('Go to Daily Review'),
            ),
          ],
        ),
      );
      return;
    }

    final wlp = widget.wordListWithProgress;
    final id = wlp.wordList.id;
    final progress = wlp.progress;

    if (progress == null) {
      // No progress → check daily limit, then start session directly
      if (!widget.canStartNewList) {
        showAppSnackBar(context, 'Daily limit reached. Come back tomorrow!');
        return;
      }
      context.push(AppRoutes.vocabularySessionPath(id));
    } else {
      // Has progress → show stats bottom sheet
      _showProgressSheet(context, wlp);
    }
  }

  void _showProgressSheet(BuildContext context, WordListWithProgress wlp) {
    final progress = wlp.progress!;
    final id = wlp.wordList.id;
    final isPerfect = progress.bestAccuracy != null && progress.bestAccuracy! >= 100;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      backgroundColor: AppColors.white,
      builder: (sheetContext) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.neutral,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),

              // Title
              Text(
                wlp.wordList.name,
                style: GoogleFonts.nunito(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: AppColors.black,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),

              // Stats row
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.neutral, width: 2),
                  boxShadow: const [
                    BoxShadow(color: AppColors.neutral, offset: Offset(0, 3)),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _SheetStat(
                      icon: Icons.repeat_rounded,
                      value: '${progress.totalSessions}',
                      label: 'Sessions',
                    ),
                    if (progress.bestAccuracy != null)
                      _SheetStat(
                        icon: Icons.star_rounded,
                        value: '${progress.bestAccuracy!.toStringAsFixed(0)}%',
                        label: 'Best',
                      ),
                    if (progress.bestScore != null)
                      _SheetStat(
                        icon: Icons.bolt_rounded,
                        value: '${progress.bestScore}',
                        label: 'Top Coin',
                      ),
                  ],
                ),
              ),

              // Stars
              if (wlp.starCount > 0) ...[
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(3, (i) {
                    final filled = i < wlp.starCount;
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Icon(
                        filled ? Icons.star_rounded : Icons.star_border_rounded,
                        color: filled ? AppColors.wasp : AppColors.neutral,
                        size: 32,
                      ),
                    );
                  }),
                ),
              ],

              if (isPerfect) ...[
                // Perfect score — mastered message
                const SizedBox(height: 20),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.green.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.check_circle_rounded,
                          color: Colors.green, size: 22),
                      const SizedBox(width: 10),
                      Text(
                        'Perfect! You\'ve mastered this set',
                        style: GoogleFonts.nunito(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Colors.green.shade800,
                        ),
                      ),
                    ],
                  ),
                ),

                // Word list
                const SizedBox(height: 16),
                Consumer(
                  builder: (context, ref, _) {
                    final wordsAsync = ref.watch(wordsForListProvider(id));
                    return wordsAsync.when(
                      loading: () => const SizedBox.shrink(),
                      error: (_, __) => const SizedBox.shrink(),
                      data: (words) {
                        if (words.isEmpty) return const SizedBox.shrink();
                        return Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          alignment: WrapAlignment.center,
                          children: words.map((w) => Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: widget.unitColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: widget.unitColor.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Text(
                              w.word,
                              style: GoogleFonts.nunito(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: widget.unitColor,
                              ),
                            ),
                          )).toList(),
                        );
                      },
                    );
                  },
                ),
              ] else ...[
                // Coin encouragement + Practice Again button
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline_rounded,
                          color: AppColors.primary, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          progress.bestScore != null && progress.bestScore! > 0
                              ? 'Beat ${progress.bestScore} coins to earn more!'
                              : 'Play again to earn coins!',
                          style: GoogleFonts.nunito(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Practice Again button
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: FilledButton.icon(
                    onPressed: () {
                      Navigator.of(sheetContext).pop();
                      context.push(AppRoutes.vocabularySessionPath(id));
                    },
                    icon: const Icon(Icons.replay_rounded),
                    label: Text(
                      'Practice Again',
                      style: GoogleFonts.nunito(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: widget.unitColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
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

    final labelStyle = pathNodeLabelStyle();

    // Side label layout (left or right)
    final isLeft = widget.labelPosition == LabelPosition.left;

    // Translate text up to align with the visual center of the node (circle) 
    // rather than the container center (which includes space for stars/crown).
    final labelWidget = Transform.translate(
      offset: const Offset(0, -12),
      child: SizedBox(
        width: 140, 
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: isLeft ? Alignment.centerRight : Alignment.centerLeft,
          child: Text(
            wordList.name,
            textAlign: isLeft ? TextAlign.right : TextAlign.left,
            maxLines: 1,
            style: labelStyle,
          ),
        ),
      ),
    );

    final rowChildren = isLeft
        ? [labelWidget, const SizedBox(width: 70), nodeWidget] // Increased gap to 70
        : [nodeWidget, const SizedBox(width: 70), labelWidget]; // Increased gap to 70

    return PressableScale(
      pressedScale: 0.92,
      onTap: () => _handleTap(context),
      child: SizedBox(
        width: 286, // 140 + 70 + 76
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: rowChildren,
        ),
      ),
    );
  }

  late double _rotation;
  
  @override
  void initState() {
    super.initState();
    _setupBounce();
    
    // Calculate random rotation once on init
    final seed = widget.wordListWithProgress.wordList.id.hashCode;
    final random = Random(seed);
    // Rotation (-0.25 to 0.25 radians ~ +/- 14 degrees)
    _rotation = (random.nextDouble() - 0.5) * 0.5;
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
              // Inner 3D Node Shape
              // Wrapped in RepaintBoundary to cache the rasterized circle/shadow
              Positioned(
                top: 4,
                child: RepaintBoundary(
                  child: Transform.rotate(
                    angle: _rotation,
                    child: Container(
                      width: 56.0,
                      height: 56.0,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: nodeColor,
                        border: !isStarted && !widget.isActive && !isLocked
                            ? Border.all(color: AppColors.neutral, width: 2)
                            : null,
                        boxShadow: [
                          BoxShadow(
                            color: isLocked
                                ? AppColors.neutralDark.withValues(alpha: 0.6)
                                : isStarted || isComplete || widget.isActive
                                    ? shadowColor.withValues(alpha: 0.8)
                                    : AppColors.neutralDark.withValues(alpha: 0.6),
                            offset: const Offset(0, 8),
                            blurRadius: 0, 
                          ),
                        ],
                      ),
                      child: Center(
                        child: isComplete
                            ? const Icon(
                                Icons.check_rounded,
                                color: Colors.white,
                                size: 28,
                              )
                            : Text(
                                wordList.category.icon,
                                style: TextStyle(
                                  fontSize: 24,
                                  color: isLocked
                                      ? AppColors.neutralText
                                      : (isStarted || widget.isActive)
                                          ? null
                                          : AppColors.neutralText,
                                ),
                              ),
                      ),
                    ),
                  ),
                ),
              ),
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

/// Mini stat widget for the progress bottom sheet.
class _SheetStat extends StatelessWidget {
  const _SheetStat({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 20, color: AppColors.primary),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.nunito(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: AppColors.black,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.nunito(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: AppColors.neutralText,
          ),
        ),
      ],
    );
  }
}
