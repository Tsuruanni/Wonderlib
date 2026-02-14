import 'package:flutter/material.dart';

/// A subtle light background wrapper.
///
/// Previously contained doodle icons; now provides a clean #F9FAFB fill.
class SubtleBackground extends StatelessWidget {
  const SubtleBackground({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(color: const Color(0xFFF9FAFB)),
        child,
      ],
    );
  }
}
