import 'package:flutter/material.dart';

/// Animated combo counter showing streak multiplier
class VocabComboIndicator extends StatefulWidget {
  const VocabComboIndicator({
    super.key,
    required this.combo,
  });

  final int combo;

  @override
  State<VocabComboIndicator> createState() => _VocabComboIndicatorState();
}

class _VocabComboIndicatorState extends State<VocabComboIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  int _previousCombo = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.3), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.3, end: 1.0), weight: 50),
    ]).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void didUpdateWidget(VocabComboIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.combo > _previousCombo && widget.combo >= 2) {
      _controller.forward(from: 0);
    }
    _previousCombo = widget.combo;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.combo < 2) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final comboColor = _getComboColor(widget.combo);

    return ScaleTransition(
      scale: _scaleAnimation,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: comboColor.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: comboColor.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.local_fire_department, color: comboColor, size: 18),
            const SizedBox(width: 4),
            Text(
              'x${widget.combo}',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: comboColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getComboColor(int combo) {
    if (combo >= 5) return Colors.deepOrange;
    if (combo >= 4) return Colors.orange;
    if (combo >= 3) return Colors.amber.shade700;
    return Colors.amber;
  }
}
