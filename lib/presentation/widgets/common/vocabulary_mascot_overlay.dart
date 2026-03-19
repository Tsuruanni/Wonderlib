import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:rive/rive.dart' hide Image;

/// Asset pools for mascot animations.
const incorrectMascotAssets = [
  'assets/animations/mascot/confused-owl-mascot.riv',
  'assets/animations/mascot/frightened-owl-mascot.riv',
  'assets/animations/mascot/angry-owl-mascot.riv',
  'assets/animations/mascot/crying-owl-mascot-animation.riv',
];

const correctMascotAssets = [
  'assets/animations/mascot/cool-owl-mascot.riv',
  'assets/animations/mascot/flying-owl-mascot-animation.riv',
  'assets/animations/mascot/kips-owl-mascot-animation.riv',
];

/// Picks mascots from a shuffled pool, cycling through all before repeating.
class MascotPicker {
  MascotPicker(List<String> assets)
      : _assets = List.of(assets)..shuffle(Random());

  final List<String> _assets;
  int _index = 0;

  String next() {
    final asset = _assets[_index % _assets.length];
    _index++;
    return asset;
  }
}

/// Plays a Rive mascot animation once, freezes on the last frame,
/// then slides left to exit.
///
/// Animation lifecycle:
///   1. Entrance: slides up from below (400ms, syncs with feedback panel)
///   2. Play: Rive animation runs (~1500ms)
///   3. Freeze: captures frame via RepaintBoundary → static RawImage
///   4. Exit: slides left and disappears (1100ms)
class MascotOverlay extends StatefulWidget {
  const MascotOverlay({
    super.key,
    required this.asset,
    this.size = 198.0,
    this.playDuration = const Duration(milliseconds: 1500),
    this.slideRight = false,
    this.exitSlide = true,
    this.freeze = true,
  });

  final String asset;
  final double size;
  /// How long the Rive animation plays before freezing.
  final Duration playDuration;
  /// If true, exits to the right instead of left.
  final bool slideRight;
  /// If false, the mascot stays frozen in place (no exit slide).
  final bool exitSlide;
  /// If false, the animation keeps playing (no freeze/capture).
  final bool freeze;

  @override
  State<MascotOverlay> createState() => _MascotOverlayState();
}

class _MascotOverlayState extends State<MascotOverlay> {
  final _repaintKey = GlobalKey();
  ui.Image? _frozenFrame;
  bool _frozen = false;
  bool _entered = false;
  bool _exiting = false;

  @override
  void initState() {
    super.initState();
    // After one frame, trigger the entrance slide-up (starts from below)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _entered = true);
    });
    if (widget.freeze) {
      // Freeze after entrance (400ms) + animation play
      Future.delayed(
        Duration(milliseconds: 400 + widget.playDuration.inMilliseconds),
        _captureFrame,
      );
    }
  }

  Future<void> _captureFrame() async {
    if (!mounted) return;
    final boundary = _repaintKey.currentContext?.findRenderObject()
        as RenderRepaintBoundary?;
    if (boundary == null) return;
    final image = await boundary.toImage(pixelRatio: 2.0);
    if (mounted) {
      setState(() {
        _frozenFrame = image;
        _frozen = true;
      });
      if (widget.exitSlide) {
        // Wait one frame so frozen image builds at Offset.zero, then slide
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() => _exiting = true);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;

    // Phase 3: Frozen → slide left
    if (_frozen && _frozenFrame != null) {
      return AnimatedSlide(
        offset: _exiting
            ? Offset(widget.slideRight ? 1.5 : -1.5, 0)
            : Offset.zero,
        duration: const Duration(milliseconds: 730),
        curve: Curves.easeInCubic,
        child: SizedBox(
          width: size,
          height: size,
          child: RawImage(image: _frozenFrame, fit: BoxFit.contain),
        ),
      );
    }

    // Phase 1→2: Entrance slide-up + Rive animation playing
    final riveWidget = SizedBox(
      width: size,
      height: size,
      child: RiveAnimation.asset(
        widget.asset,
        fit: BoxFit.contain,
        onInit: (artboard) {
          artboard.fills.clear();
          final smName = artboard.animations
              .whereType<StateMachine>()
              .map((sm) => sm.name)
              .firstOrNull;
          if (smName != null) {
            final controller = StateMachineController.fromArtboard(
              artboard,
              smName,
            );
            if (controller != null) artboard.addController(controller);
          }
        },
      ),
    );

    return AnimatedSlide(
      offset: _entered ? Offset.zero : const Offset(0, 1.5),
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutQuint,
      child: widget.freeze
          ? RepaintBoundary(key: _repaintKey, child: riveWidget)
          : riveWidget,
    );
  }
}
