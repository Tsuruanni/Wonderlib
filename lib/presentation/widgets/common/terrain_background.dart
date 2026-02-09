import 'package:flutter/material.dart';
import '../../../app/theme.dart';

class TerrainBackground extends StatelessWidget {
  const TerrainBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Solid background color (fallback)
        Container(color: AppColors.terrain),
        
        // Repeating Image Pattern
        Positioned.fill(
          child: Image.asset(
            'assets/images/forest_texture.png',
            repeat: ImageRepeat.repeat,
            fit: BoxFit.none, // Ensures it repeats at original size
          ),
        ),

        // Content
        Positioned.fill(child: child),
      ],
    );
  }
}
