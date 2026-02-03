import 'package:flutter/material.dart';
import 'package:widgetbook/widgetbook.dart';

import 'package:readeng/presentation/widgets/common/stat_item.dart';
import 'package:readeng/presentation/widgets/common/xp_badge.dart';

/// Common widgets for Widgetbook
final commonWidgets = [
  // Stat Item
  WidgetbookComponent(
    name: 'StatItem',
    useCases: [
      WidgetbookUseCase(
        name: 'Basic',
        builder: (context) => const StatItem(
          value: '1,250',
          label: 'XP Points',
        ),
      ),
      WidgetbookUseCase(
        name: 'With Icon',
        builder: (context) => const StatItem(
          value: '15',
          label: 'Day Streak',
          icon: Icons.local_fire_department,
          color: Colors.orange,
        ),
      ),
      WidgetbookUseCase(
        name: 'Multiple Stats',
        builder: (context) => const Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            StatItem(
              value: '1,250',
              label: 'XP',
              icon: Icons.star,
              color: Colors.amber,
            ),
            StatItem(
              value: '15',
              label: 'Streak',
              icon: Icons.local_fire_department,
              color: Colors.orange,
            ),
            StatItem(
              value: '7',
              label: 'Level',
              icon: Icons.trending_up,
              color: Colors.purple,
            ),
          ],
        ),
      ),
      WidgetbookUseCase(
        name: 'With Knobs',
        builder: (context) => StatItem(
          value: context.knobs.string(
            label: 'Value',
            initialValue: '100',
          ),
          label: context.knobs.string(
            label: 'Label',
            initialValue: 'Points',
          ),
          icon: context.knobs.boolean(
            label: 'Show Icon',
            initialValue: true,
          )
              ? Icons.star
              : null,
          color: Colors.amber,
        ),
      ),
    ],
  ),

  // XP Badge
  WidgetbookComponent(
    name: 'XPBadge',
    useCases: [
      WidgetbookUseCase(
        name: 'Animated (+10 XP)',
        builder: (context) => Center(
          child: XPBadge(
            xp: 10,
            onComplete: () {},
          ),
        ),
      ),
      WidgetbookUseCase(
        name: 'Animated (+50 XP)',
        builder: (context) => Center(
          child: XPBadge(
            xp: 50,
            onComplete: () {},
          ),
        ),
      ),
      WidgetbookUseCase(
        name: 'With Knobs',
        builder: (context) => Center(
          child: XPBadge(
            xp: context.knobs.int.slider(
              label: 'XP Amount',
              initialValue: 25,
              min: 5,
              max: 100,
            ),
            onComplete: () {},
          ),
        ),
      ),
    ],
  ),
];
