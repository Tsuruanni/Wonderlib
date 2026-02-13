import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

class FeedbackAnimation extends StatelessWidget {
  const FeedbackAnimation({
    super.key,
    required this.isCorrect,
    this.size = 150.0,
  });

  final bool isCorrect;
  final double size;

  @override
  Widget build(BuildContext context) {
    final assetName = isCorrect
        ? 'assets/animations/animation_success.json'
        : 'assets/animations/animation_error.json';

    return Center(
      child: Lottie.asset(
        assetName,
        width: size,
        height: size,
        repeat: false,
        fit: BoxFit.contain,
      ),
    );
  }
}
