import 'package:flutter/material.dart';

/// Wraps content with a max width, aligned to the start (left).
/// Use for screens that shouldn't stretch on wide displays.
class ResponsiveConstraint extends StatelessWidget {
  const ResponsiveConstraint({
    super.key,
    this.maxWidth = 600,
    this.padding,
    required this.child,
  });

  final double maxWidth;
  final EdgeInsetsGeometry? padding;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: padding != null ? Padding(padding: padding!, child: child) : child,
      ),
    );
  }
}

/// A grid that automatically calculates column count based on available width.
/// Use for card grids, stat grids, and any list that should expand on wider screens.
class ResponsiveGrid extends StatelessWidget {
  const ResponsiveGrid({
    super.key,
    required this.children,
    this.minItemWidth = 160,
    this.maxColumns,
    this.spacing = 12,
    this.childAspectRatio = 1.4,
  });

  final List<Widget> children;

  /// Minimum width for each grid item. Column count = availableWidth / minItemWidth.
  final double minItemWidth;

  /// Optional cap on the number of columns.
  final int? maxColumns;

  final double spacing;
  final double childAspectRatio;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        int columns = (constraints.maxWidth / minItemWidth).floor().clamp(1, 6);
        if (maxColumns != null && columns > maxColumns!) {
          columns = maxColumns!;
        }
        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: columns,
          mainAxisSpacing: spacing,
          crossAxisSpacing: spacing,
          childAspectRatio: childAspectRatio,
          children: children,
        );
      },
    );
  }
}

/// A row that wraps items evenly, expanding to fill available width.
/// Use for action buttons that should go from 2x2 to 4x1 on wider screens.
class ResponsiveWrap extends StatelessWidget {
  const ResponsiveWrap({
    super.key,
    required this.children,
    this.minItemWidth = 150,
    this.spacing = 12,
    this.runSpacing = 12,
  });

  final List<Widget> children;
  final double minItemWidth;
  final double spacing;
  final double runSpacing;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        var itemsPerRow =
            (constraints.maxWidth / (minItemWidth + spacing)).floor().clamp(1, children.length);

        // Avoid orphan items: if last row would have a single item,
        // reduce columns so items distribute more evenly (e.g. 3+1 → 2+2)
        if (itemsPerRow > 1 && children.length % itemsPerRow == 1) {
          itemsPerRow = itemsPerRow - 1;
        }

        final itemWidth =
            (constraints.maxWidth - (spacing * (itemsPerRow - 1))) / itemsPerRow;

        return Wrap(
          spacing: spacing,
          runSpacing: runSpacing,
          children: children
              .map((child) => SizedBox(width: itemWidth, child: child))
              .toList(),
        );
      },
    );
  }
}
