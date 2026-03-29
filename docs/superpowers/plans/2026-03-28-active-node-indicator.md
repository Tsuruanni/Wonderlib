# Active Node Indicator — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add an animated arrow indicator to the active learning path node, auto-scroll the screen to that node on open, and ensure bounce animation works on vocabulary nodes.

**Architecture:** A `StateProvider<double?>` shares the active node's Y position from `LearningPath` (calculated during build) to `VocabularyHubScreen` (consumed as `initialScrollOffset`). The arrow is a new animated widget inserted into the existing `Row` layout of `PathNode` and `_SpecialNodeCircle`. The `TickerProviderStateMixin` on `_PathNodeState` changes from `Single` to support two animation controllers (bounce + arrow translate).

**Tech Stack:** Flutter, Riverpod (StateProvider), AnimationController

**Spec:** `docs/superpowers/specs/2026-03-28-active-node-indicator-design.md`

---

## File Map

| File | Action | Responsibility |
|------|--------|----------------|
| `lib/presentation/providers/vocabulary_provider.dart` | Modify | Add `activeNodeYProvider` StateProvider |
| `lib/presentation/widgets/vocabulary/path_node.dart` | Modify | Add arrow widget + translate animation to active node row; change mixin to `TickerProviderStateMixin` |
| `lib/presentation/widgets/vocabulary/path_special_nodes.dart` | Modify | Add arrow widget to `_SpecialNodeCircle` row when active |
| `lib/presentation/widgets/vocabulary/learning_path.dart` | Modify | Record active node Y, write to provider |
| `lib/presentation/screens/vocabulary/vocabulary_hub_screen.dart` | Modify | Add `ScrollController` with `initialScrollOffset` from active Y provider |

---

### Task 1: Add `activeNodeYProvider`

**Files:**
- Modify: `lib/presentation/providers/vocabulary_provider.dart` (top-level providers section)

- [ ] **Step 1: Add the provider**

At the top of `vocabulary_provider.dart`, after the existing imports and before the first provider definition, add:

```dart
/// Y position of the active (current) node in the learning path.
/// Written by LearningPath during build, read by VocabularyHubScreen for initial scroll offset.
final activeNodeYProvider = StateProvider<double?>((ref) => null);
```

- [ ] **Step 2: Verify no analyze errors**

Run: `dart analyze lib/presentation/providers/vocabulary_provider.dart`
Expected: No issues found

- [ ] **Step 3: Commit**

```bash
git add lib/presentation/providers/vocabulary_provider.dart
git commit -m "feat: add activeNodeYProvider for learning path scroll offset"
```

---

### Task 2: Record active node Y in `LearningPath`

**Files:**
- Modify: `lib/presentation/widgets/vocabulary/learning_path.dart`

The `_buildPath` method already has a `y` accumulator and a `foundActive` flag. When we set `isActive = true`, we also record the current `y` into the provider.

- [ ] **Step 1: Write to provider when active node is found**

In `learning_path.dart`, the `_buildPath` method receives a `WidgetRef ref` parameter. After the line `foundActive = true;` (around line 157), add a write to the provider. Also handle daily review active detection.

Find this block in `_buildPath` (~line 154-158):

```dart
        bool isActive = false;
        if (!foundActive && !isItemLocked && !item.isComplete && item is! PathDailyReviewItem) {
          isActive = true;
          foundActive = true;
        }
```

Replace with:

```dart
        bool isActive = false;
        if (!foundActive && !isItemLocked && !item.isComplete && item is! PathDailyReviewItem) {
          isActive = true;
          foundActive = true;
          // Record active node Y for auto-scroll (y is top of connector, +36 for connector height puts us at node top, +40 centers on node)
          ref.read(activeNodeYProvider.notifier).state = y + 36 + 40;
        }
```

Also find the daily review active detection block (~line 263-267):

```dart
          case PathDailyReviewItem(:final isCompleted):
            nodes.add(
              Positioned(
                top: y,
                left: 0,
                right: 0,
                child: PathDailyReviewNode(
                  globalRowIndex: globalRowIndex,
                  unitId: unit.unit.id,
                  isLocked: false, // DR gate is never locked — it IS the gate
                  isComplete: isCompleted,
                  isActive: !isCompleted && !foundActive,
                ),
              ),
            );
            if (!isCompleted && !foundActive) foundActive = true;
```

Replace the last line `if (!isCompleted && !foundActive) foundActive = true;` with:

```dart
            if (!isCompleted && !foundActive) {
              foundActive = true;
              ref.read(activeNodeYProvider.notifier).state = y + 40;
            }
```

- [ ] **Step 2: Reset provider at start of build**

At the very start of the `data:` callback in the `build` method (before calling `_buildPath`), reset the provider so stale values don't persist. Find (~line 66-68):

```dart
        final wordsToday = ref.watch(wordsStartedTodayFromListsProvider).valueOrNull ?? 0;
        final canStartNewList = wordsToday < dailyWordListLimit;
        return _buildPath(context, ref, pathUnits, canStartNewList: canStartNewList);
```

Add a reset before `_buildPath`:

```dart
        final wordsToday = ref.watch(wordsStartedTodayFromListsProvider).valueOrNull ?? 0;
        final canStartNewList = wordsToday < dailyWordListLimit;
        // Reset active node position — will be set during _buildPath if an active node exists
        ref.read(activeNodeYProvider.notifier).state = null;
        return _buildPath(context, ref, pathUnits, canStartNewList: canStartNewList);
```

- [ ] **Step 3: Verify no analyze errors**

Run: `dart analyze lib/presentation/widgets/vocabulary/learning_path.dart`
Expected: No issues found

- [ ] **Step 4: Commit**

```bash
git add lib/presentation/widgets/vocabulary/learning_path.dart
git commit -m "feat: record active node Y position for auto-scroll"
```

---

### Task 3: Auto-scroll `VocabularyHubScreen` to active node

**Files:**
- Modify: `lib/presentation/screens/vocabulary/vocabulary_hub_screen.dart`

Convert `VocabularyHubScreen` from `ConsumerWidget` to `ConsumerStatefulWidget` so we can create a `ScrollController` with a computed `initialScrollOffset`.

- [ ] **Step 1: Convert to ConsumerStatefulWidget and add ScrollController**

Replace the class definition and build method (lines 17-69) with:

```dart
class VocabularyHubScreen extends ConsumerStatefulWidget {
  const VocabularyHubScreen({super.key});

  @override
  ConsumerState<VocabularyHubScreen> createState() => _VocabularyHubScreenState();
}

class _VocabularyHubScreenState extends ConsumerState<VocabularyHubScreen> {
  ScrollController? _scrollController;

  @override
  void dispose() {
    _scrollController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final storyListsAsync = ref.watch(storyWordListsProvider);

    // Create scroll controller once with initial offset centered on active node
    if (_scrollController == null) {
      final activeY = ref.read(activeNodeYProvider);
      final screenHeight = MediaQuery.of(context).size.height;
      final initialOffset = activeY != null
          ? (activeY - screenHeight / 2).clamp(0.0, double.maxFinite)
          : 0.0;
      _scrollController = ScrollController(initialScrollOffset: initialOffset);
    }

    return Scaffold(
      backgroundColor: AppColors.terrain,
      body: TerrainBackground(
        child: SafeArea(
          child: Column(
            children: [
              const TopNavbar(),
              Expanded(
                child: SingleChildScrollView(
                  controller: _scrollController,
                  padding: const EdgeInsets.only(bottom: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const LearningPath(),
                      ...storyListsAsync.when(
                        loading: () => [const SizedBox.shrink()],
                        error: (e, _) => [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                            child: Text('Failed to load word lists', style: TextStyle(color: Colors.red.shade300)),
                          ),
                        ],
                        data: (storyLists) => storyLists.isEmpty
                            ? []
                            : [
                                const _SectionHeader(title: 'My Word Lists'),
                                _VerticalListSection(lists: storyLists),
                              ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Verify no analyze errors**

Run: `dart analyze lib/presentation/screens/vocabulary/vocabulary_hub_screen.dart`
Expected: No issues found

- [ ] **Step 3: Commit**

```bash
git add lib/presentation/screens/vocabulary/vocabulary_hub_screen.dart
git commit -m "feat: auto-scroll vocabulary hub to active node on open"
```

---

### Task 4: Add animated arrow to `PathNode` (vocabulary word list nodes)

**Files:**
- Modify: `lib/presentation/widgets/vocabulary/path_node.dart`

This is the main change. We need:
1. Change `SingleTickerProviderStateMixin` → `TickerProviderStateMixin` (to support 2 animation controllers)
2. Add an arrow translate animation controller
3. Insert the arrow widget into the Row, on the opposite side of the label

- [ ] **Step 1: Change mixin to support multiple tickers**

In `path_node.dart` line 46-47, change:

```dart
class _PathNodeState extends ConsumerState<PathNode>
    with SingleTickerProviderStateMixin {
```

to:

```dart
class _PathNodeState extends ConsumerState<PathNode>
    with TickerProviderStateMixin {
```

- [ ] **Step 2: Add arrow animation controller and animation**

After the existing `_bounceAnimation` declaration (line 49), add the arrow fields:

```dart
  AnimationController? _arrowController;
  late Animation<double> _arrowAnimation;
```

- [ ] **Step 3: Add arrow setup method**

After the `_setupBounce()` method (after line 79), add:

```dart
  void _setupArrow() {
    if (widget.isActive && !widget.isLocked) {
      _arrowController ??= AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 900),
      );
      _arrowAnimation = Tween<double>(begin: 0.0, end: 6.0).animate(
        CurvedAnimation(parent: _arrowController!, curve: Curves.easeInOut),
      );
      _arrowController!.repeat(reverse: true);
    } else {
      _arrowController?.stop();
      _arrowController?.dispose();
      _arrowController = null;
    }
  }
```

- [ ] **Step 4: Call `_setupArrow()` in initState and didUpdateWidget**

In `initState` (line 458-459), after `_setupBounce();`, add:

```dart
    _setupArrow();
```

In `didUpdateWidget` (line 54-59), after `_setupBounce();`, add:

```dart
      _setupArrow();
```

In `dispose()` (line 82-85), before `super.dispose();`, add:

```dart
    _arrowController?.dispose();
```

- [ ] **Step 5: Build the arrow widget**

Add a helper method after `_buildStars` (after line 581):

```dart
  /// Animated arrow indicator — appears on the opposite side of the label,
  /// translates rhythmically toward the node.
  Widget? _buildArrowIndicator() {
    if (!widget.isActive || widget.isLocked || _arrowController == null) {
      return null;
    }

    final isLeft = widget.labelPosition == LabelPosition.left;
    // Arrow on opposite side of label: label left → arrow right, pointing left toward node
    final icon = isLeft ? Icons.double_arrow_rounded : Icons.double_arrow_rounded;
    // Flip direction: if arrow is on the right side, point left (toward node)
    // If arrow is on the left side, point right (toward node)
    final flipX = isLeft ? -1.0 : 1.0; // -1 mirrors horizontally (points left)
    // Translate direction: arrow moves toward the node
    final translateSign = isLeft ? -1.0 : 1.0; // negative = move left, positive = move right

    return AnimatedBuilder(
      animation: _arrowAnimation,
      builder: (context, child) => Transform.translate(
        offset: Offset(_arrowAnimation.value * translateSign, 0),
        child: child,
      ),
      child: Transform(
        alignment: Alignment.center,
        transform: Matrix4.identity()..scale(flipX, 1.0),
        child: Icon(
          icon,
          size: 24,
          color: AppColors.primary.withValues(alpha: 0.9),
        ),
      ),
    );
  }
```

- [ ] **Step 6: Insert arrow into the Row layout**

In the `build` method, replace the `rowChildren` construction (lines 436-438):

```dart
    final rowChildren = isLeft
        ? [labelWidget, const SizedBox(width: 70), nodeWidget] // Increased gap to 70
        : [nodeWidget, const SizedBox(width: 70), labelWidget]; // Increased gap to 70
```

with:

```dart
    final arrowWidget = _buildArrowIndicator();

    final rowChildren = isLeft
        ? [
            labelWidget,
            const SizedBox(width: 70),
            nodeWidget,
            if (arrowWidget != null) ...[const SizedBox(width: 12), arrowWidget],
          ]
        : [
            if (arrowWidget != null) ...[arrowWidget, const SizedBox(width: 12)],
            nodeWidget,
            const SizedBox(width: 70),
            labelWidget,
          ];
```

Also update the `SizedBox` width constraint in the parent to accommodate the arrow. Change line 444:

```dart
      width: 286, // 140 + 70 + 76
```

to:

```dart
      width: (widget.isActive && !widget.isLocked) ? 334 : 286, // 286 + 12 gap + 24 icon + 12 padding
```

- [ ] **Step 7: Verify no analyze errors**

Run: `dart analyze lib/presentation/widgets/vocabulary/path_node.dart`
Expected: No issues found

- [ ] **Step 8: Commit**

```bash
git add lib/presentation/widgets/vocabulary/path_node.dart
git commit -m "feat: add animated arrow indicator to active vocabulary nodes"
```

---

### Task 5: Add animated arrow to `_SpecialNodeCircle` (book, game, treasure, daily review)

**Files:**
- Modify: `lib/presentation/widgets/vocabulary/path_special_nodes.dart`

Apply the same arrow pattern to special nodes. Since `_SpecialNodeCircle` is a `StatelessWidget`, we wrap the arrow in its own small `StatefulWidget`.

- [ ] **Step 1: Create `_AnimatedArrow` widget**

After the `_BounceWrapper` class (after line 315), add:

```dart
/// Animated arrow that translates rhythmically toward the node.
class _AnimatedArrow extends StatefulWidget {
  const _AnimatedArrow({required this.pointsLeft});

  /// If true, arrow points left (toward a node on its left). If false, points right.
  final bool pointsLeft;

  @override
  State<_AnimatedArrow> createState() => _AnimatedArrowState();
}

class _AnimatedArrowState extends State<_AnimatedArrow>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.0, end: 6.0).animate(
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
    final translateSign = widget.pointsLeft ? -1.0 : 1.0;
    final flipX = widget.pointsLeft ? -1.0 : 1.0;

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) => Transform.translate(
        offset: Offset(_animation.value * translateSign, 0),
        child: child,
      ),
      child: Transform(
        alignment: Alignment.center,
        transform: Matrix4.identity()..scale(flipX, 1.0),
        child: Icon(
          Icons.double_arrow_rounded,
          size: 24,
          color: AppColors.primary.withValues(alpha: 0.9),
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Add arrow to `_SpecialNodeCircle` Row**

In `_SpecialNodeCircle.build()`, find the `rowChildren` construction (~line 247-249):

```dart
    final rowChildren = isLeftLabel
        ? [labelWidget, const SizedBox(width: 70), nodeContainer]
        : [nodeContainer, const SizedBox(width: 70), labelWidget];
```

Replace with:

```dart
    final showArrow = isActive && !isLocked && !isComplete;

    final rowChildren = isLeftLabel
        ? [
            labelWidget,
            const SizedBox(width: 70),
            nodeContainer,
            if (showArrow) ...[const SizedBox(width: 12), _AnimatedArrow(pointsLeft: true)],
          ]
        : [
            if (showArrow) ...[_AnimatedArrow(pointsLeft: false), const SizedBox(width: 12)],
            nodeContainer,
            const SizedBox(width: 70),
            labelWidget,
          ];
```

Update the SizedBox width in the Positioned (~line 261-268). Find:

```dart
            Positioned(
              left: leftEdge,
              top: 0,
              child: SizedBox(
                width: 286,
```

Replace with:

```dart
            Positioned(
              left: leftEdge,
              top: 0,
              child: SizedBox(
                width: showArrow ? 334 : 286,
```

- [ ] **Step 3: Add arrow to `PathTreasureNode` Row (custom layout)**

`PathTreasureNode` has its own Row layout instead of using `_SpecialNodeCircle`. Find its `rowChildren` (~line 538-540):

```dart
    final rowChildren = isLeftLabel
        ? [labelWidget, const SizedBox(width: 70), nodeContainer]
        : [nodeContainer, const SizedBox(width: 70), labelWidget];
```

Replace with:

```dart
    final showArrow = isActive && !isLocked && !isUnitComplete;

    final rowChildren = isLeftLabel
        ? [
            labelWidget,
            const SizedBox(width: 70),
            nodeContainer,
            if (showArrow) ...[const SizedBox(width: 12), _AnimatedArrow(pointsLeft: true)],
          ]
        : [
            if (showArrow) ...[_AnimatedArrow(pointsLeft: false), const SizedBox(width: 12)],
            nodeContainer,
            const SizedBox(width: 70),
            labelWidget,
          ];
```

Also update the treasure node's SizedBox width (~line 564). Find:

```dart
                width: 286,
```

Replace with:

```dart
                width: showArrow ? 334 : 286,
```

- [ ] **Step 4: Verify no analyze errors**

Run: `dart analyze lib/presentation/widgets/vocabulary/path_special_nodes.dart`
Expected: No issues found

- [ ] **Step 5: Commit**

```bash
git add lib/presentation/widgets/vocabulary/path_special_nodes.dart
git commit -m "feat: add animated arrow indicator to active special nodes"
```

---

### Task 6: Final verification

- [ ] **Step 1: Run full analyze**

Run: `dart analyze lib/`
Expected: No issues found (or only pre-existing warnings)

- [ ] **Step 2: Manual test checklist**

Run the app and navigate to the vocabulary hub:

1. **Arrow visible** — active node has a chevron arrow on the opposite side of the text label
2. **Arrow direction correct** — when text is left, arrow is right pointing left; and vice versa
3. **Arrow animates** — rhythmic translate toward the node, ~6px movement
4. **Bounce works** — active vocabulary node bounces (scale 1.0→1.08)
5. **Auto-scroll** — screen opens with active node centered vertically
6. **No arrow on other nodes** — completed, locked, and inactive nodes have no arrow
7. **Special nodes** — if active node is a book/game/treasure/daily review, arrow also appears
8. **All complete** — when all nodes are complete, page opens at top (no crash)

- [ ] **Step 3: Commit any fixes**

If any issues found during testing, fix and commit.
