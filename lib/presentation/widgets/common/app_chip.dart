import 'package:flutter/material.dart';

import '../../../app/text_styles.dart';
import '../../../app/theme.dart';

/// Duolingo-style tinted pill chip.
///
/// Static label with a tinted background and a solid text color. Use for
/// status labels (COMPLETED / IN PROGRESS), counters (ATTEMPT #3), category
/// tags (NEW / PREMIUM), and similar one-shot pills.
///
/// For animated / stateful chips (XP badge, combo celebration) use their
/// dedicated widgets instead.
enum AppChipVariant {
  success,   // green — AppColors.primary
  info,      // blue — AppColors.secondary
  danger,    // red — AppColors.danger
  warning,   // orange — AppColors.streakOrange
  premium,   // gold — AppColors.wasp
  neutral,   // gray
  custom,    // use `customColor`
}

enum AppChipSize { sm, md, lg }

class AppChip extends StatelessWidget {
  const AppChip({
    super.key,
    required this.label,
    this.variant = AppChipVariant.neutral,
    this.size = AppChipSize.md,
    this.icon,
    this.uppercase = true,
    this.customColor,
  }) : assert(
          variant != AppChipVariant.custom || customColor != null,
          'customColor is required when variant is AppChipVariant.custom',
        );

  final String label;
  final AppChipVariant variant;
  final AppChipSize size;
  final Widget? icon;
  final bool uppercase;
  final Color? customColor;

  @override
  Widget build(BuildContext context) {
    final colors = _colors();
    final spec = _sizeSpec();

    return Container(
      padding: spec.padding,
      decoration: BoxDecoration(
        color: colors.bg,
        borderRadius: BorderRadius.circular(spec.radius),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            icon!,
            SizedBox(width: spec.gap),
          ],
          Text(
            uppercase ? label.toUpperCase() : label,
            style: AppTextStyles.caption(color: colors.fg).copyWith(
              fontSize: spec.fontSize,
              fontWeight: spec.fontWeight,
              letterSpacing: uppercase ? 0.5 : 0,
              height: 1.0,
            ),
          ),
        ],
      ),
    );
  }

  _ChipColors _colors() {
    switch (variant) {
      case AppChipVariant.success:
        return const _ChipColors(fg: AppColors.primary, bg: Color(0x1F58CC02));
      case AppChipVariant.info:
        return const _ChipColors(fg: AppColors.secondary, bg: Color(0x1F1CB0F6));
      case AppChipVariant.danger:
        return const _ChipColors(fg: AppColors.danger, bg: Color(0x1FFF4B4B));
      case AppChipVariant.warning:
        return const _ChipColors(fg: AppColors.streakOrange, bg: Color(0x1FFF9600));
      case AppChipVariant.premium:
        return const _ChipColors(fg: AppColors.waspDark, bg: Color(0x26FFC800));
      case AppChipVariant.neutral:
        return const _ChipColors(fg: AppColors.gray600, bg: AppColors.gray100);
      case AppChipVariant.custom:
        return _ChipColors(
          fg: customColor!,
          bg: customColor!.withValues(alpha: 0.12),
        );
    }
  }

  _ChipSizeSpec _sizeSpec() {
    switch (size) {
      case AppChipSize.sm:
        return const _ChipSizeSpec(
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          radius: 6,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          gap: 4,
        );
      case AppChipSize.md:
        return const _ChipSizeSpec(
          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          radius: 10,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          gap: 6,
        );
      case AppChipSize.lg:
        return const _ChipSizeSpec(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          radius: 20,
          fontSize: 14,
          fontWeight: FontWeight.w800,
          gap: 8,
        );
    }
  }
}

class _ChipColors {
  const _ChipColors({required this.fg, required this.bg});
  final Color fg;
  final Color bg;
}

class _ChipSizeSpec {
  const _ChipSizeSpec({
    required this.padding,
    required this.radius,
    required this.fontSize,
    required this.fontWeight,
    required this.gap,
  });
  final EdgeInsets padding;
  final double radius;
  final double fontSize;
  final FontWeight fontWeight;
  final double gap;
}
