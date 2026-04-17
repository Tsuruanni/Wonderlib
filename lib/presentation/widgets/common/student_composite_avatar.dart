import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../data/models/avatar/equipped_avatar_model.dart';
import '../../../domain/entities/teacher.dart';
import 'avatar_widget.dart';

/// Renders a StudentSummary's avatar using the composite cache when present,
/// falling back to the legacy avatarUrl + first-letter initial otherwise.
/// Used in teacher-facing surfaces (leaderboard, class detail).
class StudentCompositeAvatar extends StatelessWidget {
  const StudentCompositeAvatar({
    super.key,
    required this.student,
    this.size = 40,
  });

  final StudentSummary student;
  final double size;

  @override
  Widget build(BuildContext context) {
    final cache = student.avatarEquippedCache;
    if (cache != null && cache.isNotEmpty) {
      final avatar = EquippedAvatarModel.fromJson(cache).toEntity();
      if (!avatar.isEmpty) {
        return AvatarWidget(
          avatar: avatar,
          size: size,
          fallbackInitials: student.firstName.isNotEmpty
              ? student.firstName[0].toUpperCase()
              : null,
        );
      }
    }
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: AppColors.primary.withValues(alpha: 0.15),
      backgroundImage:
          student.avatarUrl != null ? NetworkImage(student.avatarUrl!) : null,
      child: student.avatarUrl == null
          ? Text(
              student.firstName.isNotEmpty
                  ? student.firstName[0].toUpperCase()
                  : '?',
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w800,
                fontSize: size * 0.4,
              ),
            )
          : null,
    );
  }
}
