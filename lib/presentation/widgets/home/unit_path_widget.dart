import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../app/theme.dart';
import '../common/game_button.dart';

class LessonNodeData {
  final String id;
  final IconData icon;
  final bool isLocked;
  final bool isCompleted;
  final bool isCurrent;
  final Color color;
  final VoidCallback onTap;

  LessonNodeData({
    required this.id,
    required this.icon,
    this.isLocked = false,
    this.isCompleted = false,
    this.isCurrent = false,
    this.color = AppColors.primary,
    required this.onTap,
  });
}

class UnitPathWidget extends StatelessWidget {
  final List<LessonNodeData> nodes;
  final String unitTitle;
  final String unitDescription;
  final Color unitColor;

  const UnitPathWidget({
    super.key,
    required this.nodes,
    required this.unitTitle,
    required this.unitDescription,
    this.unitColor = AppColors.primary,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _UnitHeader(title: unitTitle, description: unitDescription, color: unitColor),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: nodes.length,
          itemBuilder: (context, index) {
            final node = nodes[index];
            // Calculate sine wave offset
            // We want a wave that goes left-right-center
            final double offset = sin(index * 1.5) * 80; 
            
            return Padding(
              padding: const EdgeInsets.only(bottom: 24.0),
              child: Transform.translate(
                offset: Offset(offset, 0),
                child: Center(
                  child: _PathNode(node: node),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _UnitHeader extends StatelessWidget {
  final String title;
  final String description;
  final Color color;

  const _UnitHeader({
    required this.title,
    required this.description,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.2), width: 2),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title.toUpperCase(),
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                    fontFamily: 'Nunito',
                    letterSpacing: 1.0,
                  ),
                ),
                Text(
                  description,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 16,
                    fontFamily: 'Nunito',
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.menu_book, color: Colors.white, size: 40)
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .rotate(begin: -0.05, end: 0.05, duration: 2000.ms),
        ],
      ),
    );
  }
}

class _PathNode extends StatelessWidget {
  final LessonNodeData node;

  const _PathNode({required this.node});

  @override
  Widget build(BuildContext context) {
    // We create a circular Game Button
    final double size = 70;
    
    // Calculate effective color for 3D effect
    final Color faceColor = node.isLocked ? AppColors.neutral : node.color;
    final Color sideColor = node.isLocked 
        ? AppColors.neutralDark 
        : Color.lerp(node.color, Colors.black, 0.2)!;

    return GestureDetector(
      onTap: node.isLocked ? null : node.onTap,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          // Crown/Star if completed?
          if (node.isCompleted)
            Positioned(
              right: -8,
              top: -8,
              child: Bounce(
                child: Icon(Icons.star_rounded, color: AppColors.wasp, size: 30),
              ),
            ),
            
          // The Button Body
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: faceColor,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: sideColor,
                  offset: const Offset(0, 6), // The "3D" depth
                  blurRadius: 0,
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Icon(
              node.isLocked ? Icons.lock : node.icon,
              color: Colors.white,
              size: 32,
            ),
          ),
          
          // Current Indicator label?
          if (node.isCurrent)
            Positioned(
              top: -35,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.neutral, width: 2),
                ),
                child: Text(
                  'START',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ).animate().moveY(begin: 5, end: 0, duration: 500.ms, curve: Curves.easeOutBack),
            ),
        ],
      ).animate(
        onPlay: (c) => node.isCurrent ? c.repeat(reverse: true) : null,
      ).scale(
        begin: const Offset(1, 1),
        end: node.isCurrent ? const Offset(1.05, 1.05) : const Offset(1, 1),
        duration: 1500.ms,
      ),
    );
  }
}

class Bounce extends StatelessWidget {
  final Widget child;
  const Bounce({super.key, required this.child});
  @override
  Widget build(BuildContext context) {
    return child.animate(onPlay: (c) => c.repeat(reverse: true))
        .moveY(begin: 0, end: -5, duration: 1000.ms);
  }
}
