import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../domain/entities/book_quiz.dart';
import '../../../../app/theme.dart';

/// Draggable/reorderable list of events for sequencing questions.
///
/// Events shown as numbered 3D cards that can be dragged to reorder.
/// Uses [ReorderableListView].
class BookQuizEventSequencing extends StatefulWidget {
  const BookQuizEventSequencing({
    super.key,
    required this.content,
    required this.onAnswer,
    this.currentOrder,
  });

  final EventSequencingContent content;
  final void Function(List<int> order) onAnswer;
  final List<int>? currentOrder;

  @override
  State<BookQuizEventSequencing> createState() =>
      _BookQuizEventSequencingState();
}

class _BookQuizEventSequencingState extends State<BookQuizEventSequencing> {
  /// Current order of event indices.
  late List<int> _order;

  @override
  void initState() {
    super.initState();
    if (widget.currentOrder != null && widget.currentOrder!.isNotEmpty) {
      _order = List<int>.from(widget.currentOrder!);
    } else {
      // Shuffle so events don't start in the correct order
      _order = List<int>.generate(widget.content.events.length, (i) => i);
      _order.shuffle();
      // Register shuffled order as the initial answer so submit isn't blocked
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.onAnswer(List<int>.from(_order));
      });
    }
  }

  @override
  void didUpdateWidget(BookQuizEventSequencing oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentOrder != oldWidget.currentOrder &&
        widget.currentOrder != null) {
      _order = List<int>.from(widget.currentOrder!);
    }
  }

  void _onReorder(int oldIndex, int newIndex) {
    HapticFeedback.mediumImpact();
    setState(() {
      if (oldIndex < newIndex) {
        newIndex -= 1;
      }
      final item = _order.removeAt(oldIndex);
      _order.insert(newIndex, item);
    });
    widget.onAnswer(List<int>.from(_order));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Instruction hint
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            children: [
              Icon(
                Icons.swap_vert_rounded,
                size: 18,
                color: Theme.of(context).colorScheme.outline,
              ),
              const SizedBox(width: 6),
              Text(
                'Drag and drop to reorder',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Reorderable list
        Theme(
            data: Theme.of(context).copyWith(
              canvasColor: Colors.transparent,
              shadowColor: Colors.transparent,
            ),
          child: _buildReorderableList(),
        ),
      ],
    ).animate().fadeIn(duration: 300.ms);
  }

  Widget _buildReorderableList() {
    return ReorderableListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      buildDefaultDragHandles: false,
      // Custom proxy decorator for drag appearance
      proxyDecorator: (child, index, animation) {
        return AnimatedBuilder(
          animation: animation,
          builder: (context, child) {
            final double animValue = Curves.easeInOut.transform(animation.value);
            final double elevation = lerpDouble(0, 6, animValue)!;
            return Material(
              color: Colors.transparent,
              elevation: elevation,
              child: child,
            );
          },
          child: child,
        );
      },
      itemCount: _order.length,
      onReorder: _onReorder,
      itemBuilder: (context, index) {
        final eventIndex = _order[index];
        final eventText = widget.content.events[eventIndex];

        return ReorderableDragStartListener(
          key: ValueKey(eventIndex),
          index: index,
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            child: _EventCard3D(
              position: index + 1,
              text: eventText,
            ),
          ),
        );
      },
    );
  }
}

class _EventCard3D extends StatelessWidget {
  const _EventCard3D({
    required this.position,
    required this.text,
  });

  final int position;
  final String text;

  @override
  Widget build(BuildContext context) {
    const double depth = 4.0;

    // Always looks "unpressed" since drag handles interaction
    return SizedBox(
      height: 72 + depth, // Fixed height for consistency during drag
      child: Stack(
        children: [
          // Bottom Layer
          Positioned(
             left: 0,
            right: 0,
            bottom: 0,
            top: depth,
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.gray200,
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          // Top Layer
          Positioned(
            top: 0,
            bottom: depth,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.gray200,
                  width: 2,
                ),
              ),
              child: Row(
                children: [
                   // Position number badge
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                         BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.3),
                          offset: const Offset(0, 2),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        '$position',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                          color: Colors.white,
                          fontFamily: 'Nunito',
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Event text
                  Expanded(
                    child: Text(
                      text,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: AppColors.gray600,
                        fontFamily: 'Nunito',
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Drag handle
                  Icon(
                    Icons.drag_handle_rounded,
                    color: AppColors.gray400,
                    size: 24,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
