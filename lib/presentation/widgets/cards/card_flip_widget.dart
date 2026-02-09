import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/theme.dart';
import '../../../domain/entities/card.dart';
import 'myth_card_widget.dart';

/// A 3D card flip animation widget.
///
/// Shows a card back (mythic pattern) that flips to reveal the full card.
/// Uses `Transform` with `Matrix4.rotationY` for the 3D perspective effect.
class CardFlipWidget extends StatefulWidget {
  const CardFlipWidget({
    super.key,
    required this.card,
    required this.isRevealed,
    this.quantity = 1,
    this.isNew = false,
    this.onFlip,
    this.index = 0,
  });

  final MythCard card;
  final bool isRevealed;
  final int quantity;
  final bool isNew;
  final VoidCallback? onFlip;
  final int index;

  @override
  State<CardFlipWidget> createState() => _CardFlipWidgetState();
}

class _CardFlipWidgetState extends State<CardFlipWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _flipAnimation;
  late Animation<double> _scaleAnimation;
  bool _showFront = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _flipAnimation = Tween<double>(begin: 0, end: math.pi).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.08), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.08, end: 1.0), weight: 50),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    // At halfway point, switch from back to front
    _controller.addListener(() {
      if (_controller.value >= 0.5 && !_showFront) {
        setState(() => _showFront = true);
      }
    });
  }

  @override
  void didUpdateWidget(CardFlipWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isRevealed && !oldWidget.isRevealed) {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (!widget.isRevealed) {
          widget.onFlip?.call();
        }
      },
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001) // perspective
              ..rotateY(_flipAnimation.value)
              ..scale(_scaleAnimation.value, _scaleAnimation.value),
            child: _showFront ? _buildFront() : _buildBack(),
          );
        },
      ),
    );
  }

  Widget _buildFront() {
    // Mirror the front so it's not backwards after flip
    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.identity()..rotateY(math.pi),
      child: MythCardWidget(
        card: widget.card,
        quantity: widget.quantity,
        showNewBadge: widget.isNew,
      ),
    );
  }

  Widget _buildBack() {
    return AspectRatio(
      aspectRatio: 0.7, // ~ 2.5/3.5 standard card ratio
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF1E2A38),
              Color(0xFF2C3E50),
              Color(0xFF1E2A38),
            ],
          ),
          border: Border.all(
            color: AppColors.cardEpic.withValues(alpha: 0.5),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.cardEpicDark.withValues(alpha: 0.5),
              offset: const Offset(0, 4),
              blurRadius: 8,
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Decorative circles
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.cardEpic.withValues(alpha: 0.1),
                  width: 2,
                ),
              ),
            ),
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.cardEpic.withValues(alpha: 0.2),
                  width: 2,
                ),
              ),
            ),
            
            // Central Content
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Mythic symbol
                Text(
                  '\u2726',
                  style: TextStyle(
                    fontSize: 40,
                    color: AppColors.cardEpic.withValues(alpha: 0.8),
                    shadows: [
                      Shadow(
                        color: AppColors.cardEpic,
                        blurRadius: 10,
                      )
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'TAP TO REVEAL',
                  style: GoogleFonts.nunito(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: AppColors.white.withValues(alpha: 0.7),
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
