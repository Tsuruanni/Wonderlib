import 'dart:math';

import 'package:flutter/material.dart';

import '../../providers/vocabulary_provider.dart';
import 'path_node.dart';

/// Positions a single PathNode in a zigzag pattern with a side label.
class PathRow extends StatelessWidget {
  const PathRow({
    super.key,
    required this.row,
    required this.globalRowIndex,
    required this.unitColor,
    required this.activeFlags,
    this.isLocked = false,
    this.canStartNewList = true,
  });

  final PathRowData row;
  final int globalRowIndex;
  final Color unitColor;
  final List<bool> activeFlags;
  final bool isLocked;
  final bool canStartNewList;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final item = row.items.first;

    final amplitude = screenWidth * 0.2;
    final sineOffset = sin(globalRowIndex * pi / 3) * amplitude;
    final labelPosition =
        sineOffset > 0 ? LabelPosition.left : LabelPosition.right;

    final nodeLeft =
        _nodeLeft(screenWidth: screenWidth, labelPosition: labelPosition);
    final isActive = activeFlags.isNotEmpty && activeFlags[0];
    return SizedBox(
      height: 80.0,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: nodeLeft,
            top: 0,
            child: PathNode(
              wordListWithProgress: item,
              unitColor: unitColor,
              isActive: isActive,
              isLocked: isLocked,
              canStartNewList: canStartNewList,
              labelPosition: labelPosition,
            ),
          ),
        ],
      ),
    );
  }

  double _nodeLeft({
    required double screenWidth,
    required LabelPosition labelPosition,
  }) {
    const sideWidth = 286.0; // 140 label + 70 gap + 76 node
    final centerX = screenWidth / 2;
    final amplitude = screenWidth * 0.2;
    final sineOffset = sin(globalRowIndex * pi / 3) * amplitude;
    final rowCenterX = centerX + sineOffset;

    final x = rowCenterX.clamp(sideWidth / 2, screenWidth - sideWidth / 2);
    double leftEdge;
    if (labelPosition == LabelPosition.right) {
      leftEdge = x - 38;
    } else {
      leftEdge = x - 248;
    }
    return leftEdge.clamp(0, screenWidth - sideWidth);
  }
}
