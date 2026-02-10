import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/theme.dart';
import '../../providers/vocabulary_provider.dart';
import '../../utils/ui_helpers.dart';
import 'path_painters.dart';
import 'path_row.dart';
import 'path_special_nodes.dart';

/// Duolingo-style vertical learning path.
/// Renders units as sections with word list nodes in a zigzag pattern.
class LearningPath extends ConsumerWidget {
  const LearningPath({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pathDataAsync = ref.watch(learningPathProvider);

    return pathDataAsync.when(
      loading: () => const SizedBox(
        height: 200,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, s) => Padding(
        padding: const EdgeInsets.all(20),
        child: Text(
          'Could not load learning path',
          style: GoogleFonts.nunito(color: AppColors.neutralText),
          textAlign: TextAlign.center,
        ),
      ),
      data: (pathUnits) {
        if (pathUnits.isEmpty) return const SizedBox.shrink();
        final wordsToday = ref.watch(wordsStartedTodayFromListsProvider).valueOrNull ?? 0;
        final canStartNewList = wordsToday < dailyWordListLimit;
        return _buildPath(context, ref, pathUnits, canStartNewList: canStartNewList);
      },
    );
  }

  Widget _buildPath(BuildContext context, WidgetRef ref, List<PathUnitData> units, {required bool canStartNewList}) {
    final screenWidth = MediaQuery.of(context).size.width;
    final connectors = <Widget>[];
    final nodes = <Widget>[];
    int globalRowIndex = 0;
    bool foundActive = false;
    double y = 0;

    final pathPoints = <Offset>[];
    void addPathPoint(double centerX, double currentY) {
      pathPoints.add(Offset(centerX, currentY));
    }

    List<double> prevNodeCenterXs = [screenWidth / 2];

    for (int unitIdx = 0; unitIdx < units.length; unitIdx++) {
      final unit = units[unitIdx];
      final isUnitLocked = unitIdx > 0 && !units[unitIdx - 1].isAllComplete;

      // --- Unit banner (centered) ---
      final unitCenterXs = [screenWidth / 2];

      addPathPoint(unitCenterXs[0], y + 28);

      if (unitIdx > 0) {
        final prevCompleted = !isUnitLocked && units[unitIdx - 1].isAllComplete;
        connectors.add(
          Positioned(
            top: y,
            left: 0,
            right: 0,
            child: PathConnector(
              startXs: prevNodeCenterXs,
              endXs: unitCenterXs,
              isCompleted: prevCompleted,
            ),
          ),
        );
        y += 36;
      }

      nodes.add(
        Positioned(
          top: y,
          left: 0,
          right: 0,
          child: PathUnitBanner(
            unit: unit.unit,
            unitIndex: unitIdx + 1,
            isLocked: isUnitLocked,
          ),
        ),
      );
      y += 56;

      prevNodeCenterXs = unitCenterXs;
      globalRowIndex++;

      // --- Word rows (sequential locking within unit) ---
      for (int rowIdx = 0; rowIdx < unit.rows.length; rowIdx++) {
        final row = unit.rows[rowIdx];

        final currentNodeCenterXs = _nodeCenterXs(
          globalRowIndex: globalRowIndex,
          screenWidth: screenWidth,
        );

        if (currentNodeCenterXs.isNotEmpty) {
          addPathPoint(currentNodeCenterXs[0], y + 40 + 36);
        }

        // Sequential lock: row N locked until row N-1 is complete
        final isRowLocked = isUnitLocked ||
            (rowIdx > 0 && !unit.rows[rowIdx - 1].items.every((i) => i.isComplete));

        bool prevCompleted;
        if (isRowLocked) {
          prevCompleted = false;
        } else if (rowIdx == 0) {
          prevCompleted = unitIdx > 0 ? units[unitIdx - 1].isAllComplete : false;
        } else {
          prevCompleted = unit.rows[rowIdx - 1].items.every((i) => i.isComplete);
        }

        connectors.add(
          Positioned(
            top: y,
            left: 0,
            right: 0,
            child: PathConnector(
              startXs: prevNodeCenterXs,
              endXs: currentNodeCenterXs,
              isCompleted: prevCompleted,
            ),
          ),
        );
        y += 36;

        // Active detection — first unlocked + incomplete node in the path
        final activeFlags = <bool>[];
        for (final item in row.items) {
          if (!isRowLocked && !foundActive && !item.isComplete) {
            activeFlags.add(true);
            foundActive = true;
          } else {
            activeFlags.add(false);
          }
        }

        nodes.add(
          Positioned(
            top: y,
            left: 0,
            right: 0,
            child: PathRow(
              row: row,
              globalRowIndex: globalRowIndex,
              unitColor: unit.unit.parsedColor,
              activeFlags: activeFlags,
              isLocked: isRowLocked,
              canStartNewList: canStartNewList,
            ),
          ),
        );
        y += 80.0;

        prevNodeCenterXs = currentNodeCenterXs;
        globalRowIndex++;
      }

      // --- Sequential special node locking ---
      final allListsDone = unit.isAllListsComplete;
      final flipbookDone = unit.completedNodeTypes.contains('flipbook');
      final reviewDone = unit.completedNodeTypes.contains('daily_review');
      final gameDone = unit.completedNodeTypes.contains('game');
      final treasureDone = unit.completedNodeTypes.contains('treasure');

      final flipbookLocked = isUnitLocked || !allListsDone;
      final reviewLocked = false; // TODO: restore → isUnitLocked || !flipbookDone;
      final gameLocked = isUnitLocked || !reviewDone;
      final treasureLocked = isUnitLocked || !gameDone;

      // Active detection for special nodes
      bool flipbookActive = false;
      bool reviewActive = false;
      bool gameActive = false;
      bool treasureActive = false;

      if (!foundActive && !flipbookLocked && !flipbookDone) {
        flipbookActive = true;
        foundActive = true;
      }
      if (!foundActive && !reviewLocked && !reviewDone) {
        reviewActive = true;
        foundActive = true;
      }
      if (!foundActive && !gameLocked && !gameDone) {
        gameActive = true;
        foundActive = true;
      }
      if (!foundActive && !treasureLocked && !treasureDone) {
        treasureActive = true;
        foundActive = true;
      }

      // Previous node completion for connector coloring
      final lastListComplete = allListsDone && !isUnitLocked;

      // --- Flipbook Node ---
      y = _addSpecialNode(
        nodes: nodes,
        connectors: connectors,
        pathPoints: pathPoints,
        prevCenterXs: prevNodeCenterXs,
        globalRowIndex: globalRowIndex,
        screenWidth: screenWidth,
        y: y,
        connectorCompleted: lastListComplete,
        builder: (idx) => PathFlipbookNode(
          globalRowIndex: idx,
          isLocked: flipbookLocked,
          isComplete: flipbookDone,
          isActive: flipbookActive,
          onComplete: () => completePathNode(ref, unit.unit.id, 'flipbook'),
        ),
      );
      prevNodeCenterXs = _nodeCenterXs(globalRowIndex: globalRowIndex, screenWidth: screenWidth);
      globalRowIndex++;

      // --- Daily Review Node ---
      y = _addSpecialNode(
        nodes: nodes,
        connectors: connectors,
        pathPoints: pathPoints,
        prevCenterXs: prevNodeCenterXs,
        globalRowIndex: globalRowIndex,
        screenWidth: screenWidth,
        y: y,
        connectorCompleted: flipbookDone && !isUnitLocked,
        builder: (idx) => PathDailyReviewNode(
          globalRowIndex: idx,
          unitId: unit.unit.id,
          isLocked: reviewLocked,
          isComplete: reviewDone,
          isActive: reviewActive,
        ),
      );
      prevNodeCenterXs = _nodeCenterXs(globalRowIndex: globalRowIndex, screenWidth: screenWidth);
      globalRowIndex++;

      // --- Game Node ---
      y = _addSpecialNode(
        nodes: nodes,
        connectors: connectors,
        pathPoints: pathPoints,
        prevCenterXs: prevNodeCenterXs,
        globalRowIndex: globalRowIndex,
        screenWidth: screenWidth,
        y: y,
        connectorCompleted: reviewDone && !isUnitLocked,
        builder: (idx) => PathGameNode(
          globalRowIndex: idx,
          isLocked: gameLocked,
          isComplete: gameDone,
          isActive: gameActive,
          onComplete: () => completePathNode(ref, unit.unit.id, 'game'),
        ),
      );
      prevNodeCenterXs = _nodeCenterXs(globalRowIndex: globalRowIndex, screenWidth: screenWidth);
      globalRowIndex++;

      // --- Treasure Chest ---
      final treasureCenterXs = _nodeCenterXs(
        globalRowIndex: globalRowIndex,
        screenWidth: screenWidth,
      );
      if (treasureCenterXs.isNotEmpty) {
        addPathPoint(treasureCenterXs[0], y + 36 + 50);
      }

      connectors.add(
        Positioned(
          top: y,
          left: 0,
          right: 0,
          child: PathConnector(
            startXs: prevNodeCenterXs,
            endXs: treasureCenterXs,
            isCompleted: gameDone && !isUnitLocked,
          ),
        ),
      );
      y += 36;
      nodes.add(
        Positioned(
          top: y,
          left: 0,
          right: 0,
          child: PathTreasureNode(
            isUnitComplete: unit.isAllComplete,
            globalRowIndex: globalRowIndex,
            isLocked: treasureLocked,
            isActive: treasureActive,
            onComplete: () => completePathNode(ref, unit.unit.id, 'treasure'),
          ),
        ),
      );
      y += 80;
      prevNodeCenterXs = treasureCenterXs;
      globalRowIndex++;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: SizedBox(
        height: y,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Background Path
            Positioned.fill(
              child: CustomPaint(
                painter: PathBackgroundPainter(points: pathPoints),
              ),
            ),

            // Connectors (Lines between nodes)
            ...connectors,

            // Nodes (Buttons, Banners, etc)
            ...nodes,
          ],
        ),
      ),
    );
  }

  /// Helper to add a special node with connector.
  /// Returns the updated y position.
  double _addSpecialNode({
    required List<Widget> nodes,
    required List<Widget> connectors,
    required List<Offset> pathPoints,
    required List<double> prevCenterXs,
    required int globalRowIndex,
    required double screenWidth,
    required double y,
    required Widget Function(int globalRowIndex) builder,
    bool connectorCompleted = false,
  }) {
    final centerXs = _nodeCenterXs(
      globalRowIndex: globalRowIndex,
      screenWidth: screenWidth,
    );
    if (centerXs.isNotEmpty) {
      pathPoints.add(Offset(centerXs[0], y + 36 + 28));
    }

    connectors.add(
      Positioned(
        top: y,
        left: 0,
        right: 0,
        child: PathConnector(
          startXs: prevCenterXs,
          endXs: centerXs,
          isCompleted: connectorCompleted,
        ),
      ),
    );
    y += 36;
    nodes.add(
      Positioned(
        top: y,
        left: 0,
        right: 0,
        child: builder(globalRowIndex),
      ),
    );
    y += 80;
    return y;
  }

  /// Returns the node center X position for a single-node row.
  List<double> _nodeCenterXs({
    required int globalRowIndex,
    required double screenWidth,
  }) {
    const nodeWidth = 92.0;
    final centerX = screenWidth / 2;
    final amplitude = screenWidth * 0.2;
    final sineOffset = sin(globalRowIndex * pi / 3) * amplitude;
    final rowCenterX = centerX + sineOffset;
    return [rowCenterX.clamp(nodeWidth / 2, screenWidth - nodeWidth / 2)];
  }
}
