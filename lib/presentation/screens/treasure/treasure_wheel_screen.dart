import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/entities/treasure_wheel.dart';
import '../../providers/treasure_wheel_provider.dart';
import '../../widgets/treasure/treasure_wheel_painter.dart';

class TreasureWheelScreen extends ConsumerStatefulWidget {
  const TreasureWheelScreen({super.key, required this.unitId});

  final String unitId;

  @override
  ConsumerState<TreasureWheelScreen> createState() => _TreasureWheelScreenState();
}

class _TreasureWheelScreenState extends ConsumerState<TreasureWheelScreen>
    with TickerProviderStateMixin {
  final _wheelKey = GlobalKey<TreasureWheelWidgetState>();
  bool _showConfetti = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(treasureWheelControllerProvider.notifier).loadSlices();
    });
  }

  void _onSpin() {
    _wheelKey.currentState?.startIdleSpin();
    ref.read(treasureWheelControllerProvider.notifier).spin(widget.unitId);
  }

  void _onSpinAnimationComplete() {
    final state = ref.read(treasureWheelControllerProvider);
    if (state.phase == TreasureWheelPhase.revealing) {
      setState(() => _showConfetti = true);
      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted) {
          ref.read(treasureWheelControllerProvider.notifier).showReward();
        }
      });
    }
  }

  void _onClaim() {
    ref.read(treasureWheelControllerProvider.notifier).complete();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(treasureWheelControllerProvider);

    ref.listen<TreasureWheelState>(treasureWheelControllerProvider, (prev, next) {
      if (prev?.phase == TreasureWheelPhase.spinning &&
          next.phase == TreasureWheelPhase.revealing &&
          next.result != null) {
        _wheelKey.currentState?.spinTo(next.result!.sliceIndex);
      }
    });

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D2B),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: state.phase == TreasureWheelPhase.spinning
            ? const SizedBox.shrink()
            : IconButton(
                icon: const Icon(Icons.close, color: Colors.white54),
                onPressed: () => Navigator.of(context).pop(),
              ),
      ),
      body: Stack(
        children: [
          // Animated background
          const _AnimatedBackground(),
          // Main content
          SafeArea(
            child: Center(child: _buildBody(state)),
          ),
          // Confetti overlay
          if (_showConfetti) const _ConfettiOverlay(),
        ],
      ),
    );
  }

  Widget _buildBody(TreasureWheelState state) {
    switch (state.phase) {
      case TreasureWheelPhase.loading:
        return const _LoadingView();

      case TreasureWheelPhase.error:
        return _ErrorView(
          message: state.errorMessage ?? 'Something went wrong',
          onBack: () => Navigator.of(context).pop(),
        );

      case TreasureWheelPhase.ready:
      case TreasureWheelPhase.spinning:
      case TreasureWheelPhase.revealing:
        return _buildWheelView(state);

      case TreasureWheelPhase.rewarded:
      case TreasureWheelPhase.completed:
        return _RewardView(
          result: state.result!,
          onClaim: _onClaim,
        );
    }
  }

  Widget _buildWheelView(TreasureWheelState state) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Title
        Text(
          'SPIN TO WIN',
          style: TextStyle(
            color: Colors.amber.shade300,
            fontSize: 32,
            fontWeight: FontWeight.w900,
            letterSpacing: 4,
            shadows: [
              Shadow(blurRadius: 20, color: Colors.amber.withValues(alpha: 0.5)),
              const Shadow(blurRadius: 40, color: Colors.orange),
            ],
          ),
        )
            .animate(onPlay: (c) => c.repeat(reverse: true))
            .shimmer(duration: 2000.ms, color: Colors.white24),
        const SizedBox(height: 24),
        // Wheel
        TreasureWheelWidget(
          key: _wheelKey,
          slices: state.slices,
          onSpinComplete: _onSpinAnimationComplete,
        ).animate().scale(
              begin: const Offset(0.8, 0.8),
              end: const Offset(1, 1),
              duration: 600.ms,
              curve: Curves.elasticOut,
            ),
        const SizedBox(height: 32),
        // Spin button
        _SpinButton(
          isReady: state.phase == TreasureWheelPhase.ready,
          isSpinning: state.phase == TreasureWheelPhase.spinning ||
              state.phase == TreasureWheelPhase.revealing,
          onPressed: _onSpin,
        ),
      ],
    );
  }
}

// ─── Spin Button ────────────────────────────────────

class _SpinButton extends StatelessWidget {
  const _SpinButton({
    required this.isReady,
    required this.isSpinning,
    required this.onPressed,
  });

  final bool isReady;
  final bool isSpinning;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: isSpinning ? 70 : 220,
      height: 60,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isReady ? onPressed : null,
          borderRadius: BorderRadius.circular(30),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(30),
              gradient: LinearGradient(
                colors: isReady
                    ? [const Color(0xFFFFD54F), const Color(0xFFFF8F00)]
                    : [Colors.grey.shade700, Colors.grey.shade800],
              ),
              boxShadow: isReady
                  ? [
                      BoxShadow(
                        color: Colors.amber.withValues(alpha: 0.5),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ]
                  : [],
            ),
            alignment: Alignment.center,
            child: isSpinning
                ? const SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      color: Colors.white,
                    ),
                  )
                : const Text(
                    'SPIN!',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF3E2723),
                      letterSpacing: 3,
                    ),
                  ),
          ),
        ),
      ),
    )
        .animate(
          target: isReady ? 1 : 0,
          onPlay: (c) => c.repeat(reverse: true),
        )
        .scaleXY(begin: 1.0, end: 1.05, duration: 800.ms, curve: Curves.easeInOut);
  }
}

// ─── Reward View ────────────────────────────────────

class _RewardView extends StatelessWidget {
  const _RewardView({required this.result, required this.onClaim});

  final TreasureSpinResult result;
  final VoidCallback onClaim;

  @override
  Widget build(BuildContext context) {
    final isCoin = result.rewardType == 'coin';

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Big reward icon with glow
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                Colors.amber.withValues(alpha: 0.3),
                Colors.transparent,
              ],
            ),
          ),
          child: Icon(
            isCoin ? Icons.monetization_on : Icons.card_giftcard,
            color: Colors.amber,
            size: 80,
          ),
        )
            .animate()
            .scale(
              begin: const Offset(0, 0),
              end: const Offset(1, 1),
              duration: 500.ms,
              curve: Curves.elasticOut,
            )
            .then()
            .animate(onPlay: (c) => c.repeat(reverse: true))
            .scaleXY(begin: 1.0, end: 1.08, duration: 1200.ms),

        const SizedBox(height: 16),

        // "YOU WON" text
        Text(
          'YOU WON!',
          style: TextStyle(
            color: Colors.amber.shade300,
            fontSize: 36,
            fontWeight: FontWeight.w900,
            letterSpacing: 4,
            shadows: [
              Shadow(blurRadius: 20, color: Colors.amber.withValues(alpha: 0.6)),
            ],
          ),
        )
            .animate()
            .fadeIn(duration: 400.ms, delay: 200.ms)
            .slideY(begin: -0.3, end: 0, duration: 400.ms, curve: Curves.easeOut),

        const SizedBox(height: 12),

        // Reward label
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: Colors.white.withValues(alpha: 0.1),
            border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isCoin ? Icons.monetization_on : Icons.card_giftcard,
                color: Colors.amber,
                size: 28,
              ),
              const SizedBox(width: 10),
              Text(
                result.sliceLabel,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        )
            .animate()
            .fadeIn(duration: 400.ms, delay: 400.ms)
            .scale(
              begin: const Offset(0.8, 0.8),
              end: const Offset(1, 1),
              duration: 400.ms,
              curve: Curves.easeOut,
            ),

        if (!isCoin) ...[
          const SizedBox(height: 8),
          Text(
            'Added to your pack inventory!',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 14,
            ),
          ).animate().fadeIn(delay: 600.ms),
        ],

        const SizedBox(height: 40),

        // Claim button
        SizedBox(
          width: 220,
          height: 56,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onClaim,
              borderRadius: BorderRadius.circular(28),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFFD54F), Color(0xFFFF8F00)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.amber.withValues(alpha: 0.4),
                      blurRadius: 16,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: const Text(
                  'COLLECT',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF3E2723),
                    letterSpacing: 2,
                  ),
                ),
              ),
            ),
          ),
        )
            .animate()
            .fadeIn(duration: 400.ms, delay: 600.ms)
            .slideY(begin: 0.5, end: 0, duration: 400.ms, curve: Curves.easeOut),
      ],
    );
  }
}

// ─── Loading View ────────────────────────────────────

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.diamond, color: Colors.amber, size: 48)
            .animate(onPlay: (c) => c.repeat())
            .rotate(duration: 2000.ms)
            .scaleXY(begin: 0.8, end: 1.2, duration: 1000.ms),
        const SizedBox(height: 16),
        Text(
          'Preparing your treasure...',
          style: TextStyle(color: Colors.amber.shade200, fontSize: 16),
        ).animate(onPlay: (c) => c.repeat(reverse: true)).fadeIn(duration: 800.ms),
      ],
    );
  }
}

// ─── Error View ────────────────────────────────────

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onBack});

  final String message;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.error_outline, color: Colors.redAccent, size: 56),
        const SizedBox(height: 16),
        Text(
          message,
          style: const TextStyle(color: Colors.white70, fontSize: 16),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: onBack,
          style: ElevatedButton.styleFrom(backgroundColor: Colors.white12),
          child: const Text('Go Back', style: TextStyle(color: Colors.white)),
        ),
      ],
    ).animate().fadeIn(duration: 300.ms);
  }
}

// ─── Animated Background ────────────────────────────

class _AnimatedBackground extends StatefulWidget {
  const _AnimatedBackground();

  @override
  State<_AnimatedBackground> createState() => _AnimatedBackgroundState();
}

class _AnimatedBackgroundState extends State<_AnimatedBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          size: MediaQuery.of(context).size,
          painter: _BackgroundPainter(progress: _controller.value),
        );
      },
    );
  }
}

class _BackgroundPainter extends CustomPainter {
  _BackgroundPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    // Deep space gradient
    final bgPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFF0D0D2B),
          const Color(0xFF1A1A3E),
          const Color(0xFF0D0D2B),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    // Floating particles/stars
    final random = math.Random(42); // Fixed seed for consistent pattern
    for (int i = 0; i < 40; i++) {
      final baseX = random.nextDouble() * size.width;
      final baseY = random.nextDouble() * size.height;
      final speed = 0.3 + random.nextDouble() * 0.7;
      final phase = random.nextDouble() * 2 * math.pi;

      final x = baseX + math.sin(progress * 2 * math.pi * speed + phase) * 15;
      final y = baseY + math.cos(progress * 2 * math.pi * speed * 0.7 + phase) * 10;

      final opacity = 0.2 + math.sin(progress * 2 * math.pi * 2 + phase) * 0.3;
      final dotSize = 1.0 + random.nextDouble() * 2;

      canvas.drawCircle(
        Offset(x, y),
        dotSize,
        Paint()..color = Colors.amber.withValues(alpha: opacity.clamp(0.1, 0.5)),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BackgroundPainter oldDelegate) => true;
}

// ─── Confetti Overlay ────────────────────────────────

class _ConfettiOverlay extends StatefulWidget {
  const _ConfettiOverlay();

  @override
  State<_ConfettiOverlay> createState() => _ConfettiOverlayState();
}

class _ConfettiOverlayState extends State<_ConfettiOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late List<_ConfettiParticle> _particles;

  @override
  void initState() {
    super.initState();
    final random = math.Random();
    _particles = List.generate(60, (_) => _ConfettiParticle(random));
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return CustomPaint(
          size: MediaQuery.of(context).size,
          painter: _ConfettiPainter(
            particles: _particles,
            progress: _controller.value,
          ),
        );
      },
    );
  }
}

class _ConfettiParticle {
  _ConfettiParticle(math.Random r)
      : x = r.nextDouble(),
        speed = 0.5 + r.nextDouble() * 1.5,
        size = 4.0 + r.nextDouble() * 8,
        drift = (r.nextDouble() - 0.5) * 0.3,
        rotation = r.nextDouble() * math.pi * 2,
        rotationSpeed = (r.nextDouble() - 0.5) * 6,
        color = [
          Colors.amber,
          Colors.orange,
          Colors.yellow,
          Colors.red,
          Colors.purple,
          Colors.blue,
          Colors.green,
        ][r.nextInt(7)];

  final double x;
  final double speed;
  final double size;
  final double drift;
  final double rotation;
  final double rotationSpeed;
  final Color color;
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter({required this.particles, required this.progress});

  final List<_ConfettiParticle> particles;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      final y = -20 + progress * size.height * p.speed * 1.2;
      final x = p.x * size.width + math.sin(progress * math.pi * 4 + p.drift * 10) * 40;
      final opacity = (1.0 - progress).clamp(0.0, 1.0);

      if (y < 0 || y > size.height) continue;

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(p.rotation + progress * p.rotationSpeed);

      canvas.drawRect(
        Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size * 0.6),
        Paint()..color = p.color.withValues(alpha: opacity),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) => true;
}
