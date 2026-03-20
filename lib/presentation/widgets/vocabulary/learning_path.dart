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

      // --- Unified items loop (word lists + books, interleaved by sort_order) ---
      final locks = calculateLocks(
        items: unit.items,
        sequentialLock: unit.sequentialLock,
        booksExemptFromLock: unit.booksExemptFromLock,
        isUnitLocked: isUnitLocked,
      );

      for (int itemIdx = 0; itemIdx < unit.items.length; itemIdx++) {
        final item = unit.items[itemIdx];
        final isItemLocked = locks[itemIdx];

        final currentNodeCenterXs = _nodeCenterXs(
          globalRowIndex: globalRowIndex,
          screenWidth: screenWidth,
        );

        if (currentNodeCenterXs.isNotEmpty) {
          addPathPoint(currentNodeCenterXs[0], y + 40 + 36);
        }

        // Active detection — first unlocked + incomplete node in the path
        bool isActive = false;
        if (!foundActive && !isItemLocked && !item.isComplete) {
          isActive = true;
          foundActive = true;
        }

        // Connector from previous node
        bool prevCompleted;
        if (isItemLocked) {
          prevCompleted = false;
        } else if (itemIdx == 0) {
          prevCompleted = unitIdx > 0 ? units[unitIdx - 1].isAllComplete : false;
        } else {
          prevCompleted = !isItemLocked;
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

        // Render based on item type
        switch (item) {
          case PathWordListItem(:final wordListWithProgress):
            nodes.add(
              Positioned(
                top: y,
                left: 0,
                right: 0,
                child: PathRow(
                  wordListWithProgress: wordListWithProgress,
                  globalRowIndex: globalRowIndex,
                  unitColor: unit.unit.parsedColor,
                  isActive: isActive,
                  isLocked: isItemLocked,
                  canStartNewList: canStartNewList,
                ),
              ),
            );

          case PathBookItem(:final bookWithProgress):
            nodes.add(
              Positioned(
                top: y,
                left: 0,
                right: 0,
                child: PathBookNode(
                  globalRowIndex: globalRowIndex,
                  bookTitle: bookWithProgress.book.title,
                  bookId: bookWithProgress.bookId,
                  isLocked: isItemLocked,
                  isComplete: bookWithProgress.isCompleted,
                  isActive: isActive,
                ),
              ),
            );
        }

        y += 80.0;
        prevNodeCenterXs = currentNodeCenterXs;
        globalRowIndex++;
      }

      // --- Sequential special node locking ---
      // "allRequiredDone" checks items that participate in locking (exempt books excluded)
      final allRequiredDone = unit.items
          .where((i) => !(i is PathBookItem && unit.booksExemptFromLock))
          .every((i) => i.isComplete);
      final reviewDone = unit.completedNodeTypes.contains('daily_review');
      final gameDone = unit.completedNodeTypes.contains('game');
      final treasureDone = unit.completedNodeTypes.contains('treasure');

      final reviewLocked = isUnitLocked || !allRequiredDone;
      final gameLocked = isUnitLocked || !reviewDone;
      final treasureLocked = isUnitLocked || !gameDone;

      // Active detection for special nodes
      bool reviewActive = false;
      bool gameActive = false;
      bool treasureActive = false;

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

      // Connector from last item to Daily Review
      final preReviewComplete = allRequiredDone && !isUnitLocked;

      // --- Daily Review Node ---
      y = _addSpecialNode(
        nodes: nodes,
        connectors: connectors,
        pathPoints: pathPoints,
        prevCenterXs: prevNodeCenterXs,
        globalRowIndex: globalRowIndex,
        screenWidth: screenWidth,
        y: y,
        connectorCompleted: preReviewComplete,
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
