import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../domain/entities/treasure_wheel.dart';
import '../../providers/treasure_wheel_provider.dart';
import '../../widgets/common/game_button.dart';
import '../../widgets/treasure/treasure_wheel_painter.dart';

class TreasureWheelScreen extends ConsumerStatefulWidget {
  const TreasureWheelScreen({super.key, required this.unitId});

  final String unitId;

  @override
  ConsumerState<TreasureWheelScreen> createState() => _TreasureWheelScreenState();
}

class _TreasureWheelScreenState extends ConsumerState<TreasureWheelScreen> {
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
    context.pop();
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
                onPressed: () => context.pop(),
              ),
      ),
      body: Stack(
        children: [
          const _AnimatedBackground(),
          SafeArea(
            child: Center(child: _buildBody(state)),
          ),
          if (_showConfetti) const IgnorePointer(child: _ConfettiOverlay()),
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
          onBack: () => context.pop(),
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
    final isReady = state.phase == TreasureWheelPhase.ready;
    final isSpinning = state.phase == TreasureWheelPhase.spinning ||
        state.phase == TreasureWheelPhase.revealing;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Title
        Text(
          'SPIN TO WIN',
          style: TextStyle(
            color: AppColors.wasp,
            fontSize: 32,
            fontWeight: FontWeight.w900,
            letterSpacing: 4,
            shadows: [
              Shadow(blurRadius: 20, color: AppColors.wasp.withValues(alpha: 0.5)),
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
        if (isSpinning)
          SizedBox(
            width: 70,
            height: 54,
            child: Center(
              child: SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: AppColors.wasp,
                ),
              ),
            ),
          )
        else
          SizedBox(
            width: 220,
            child: GameButton(
              label: 'SPIN!',
              variant: GameButtonVariant.wasp,
              onPressed: isReady ? _onSpin : null,
            ),
          )
              .animate(
                target: isReady ? 1 : 0,
                onPlay: (c) => c.repeat(reverse: true),
              )
              .scaleXY(begin: 1.0, end: 1.04, duration: 800.ms, curve: Curves.easeInOut),
      ],
    );
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

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
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
                  AppColors.wasp.withValues(alpha: 0.3),
                  Colors.transparent,
                ],
              ),
            ),
            child: Center(
              child: isCoin
                  ? Image.asset(
                      'assets/icons/gem_outline_256.png',
                      width: 72,
                      height: 72,
                      filterQuality: FilterQuality.high,
                    )
                  : Icon(Icons.style_rounded, color: AppColors.wasp, size: 72),
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
              color: AppColors.wasp,
              fontSize: 36,
              fontWeight: FontWeight.w900,
              letterSpacing: 4,
              shadows: [
                Shadow(blurRadius: 20, color: AppColors.wasp.withValues(alpha: 0.6)),
              ],
            ),
          )
              .animate()
              .fadeIn(duration: 400.ms, delay: 200.ms)
              .slideY(begin: -0.3, end: 0, duration: 400.ms, curve: Curves.easeOut),

          const SizedBox(height: 16),

          // Reward amount text
          Text(
            result.sliceLabel,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w800,
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
            const SizedBox(height: 12),
            Text(
              'Added to your pack inventory!',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 14,
              ),
            ).animate().fadeIn(delay: 600.ms),
          ],

          const SizedBox(height: 40),

          // Collect button — GameButton
          SizedBox(
            width: 220,
            child: GameButton(
              label: 'COLLECT',
              variant: GameButtonVariant.wasp,
              onPressed: onClaim,
            ),
          )
              .animate()
              .fadeIn(duration: 400.ms, delay: 600.ms)
              .slideY(begin: 0.5, end: 0, duration: 400.ms, curve: Curves.easeOut),
        ],
      ),
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
        Icon(Icons.diamond_rounded, color: AppColors.wasp, size: 48)
            .animate(onPlay: (c) => c.repeat())
            .rotate(duration: 2000.ms)
            .scaleXY(begin: 0.8, end: 1.2, duration: 1000.ms),
        const SizedBox(height: 16),
        Text(
          'Preparing your treasure...',
          style: TextStyle(color: AppColors.wasp.withValues(alpha: 0.7), fontSize: 16),
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
        const Icon(Icons.error_outline, color: AppColors.danger, size: 56),
        const SizedBox(height: 16),
        Text(
          message,
          style: const TextStyle(color: Colors.white70, fontSize: 16),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: 180,
          child: GameButton(
            label: 'Go Back',
            variant: GameButtonVariant.neutral,
            onPressed: onBack,
          ),
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
    final bgPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF0D0D2B), Color(0xFF1A1A3E), Color(0xFF0D0D2B)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    final random = math.Random(42);
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
        Paint()..color = Color.fromRGBO(255, 200, 0, opacity.clamp(0.1, 0.5)),
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
        color = const [
          AppColors.wasp,
          AppColors.streakOrange,
          AppColors.primary,
          AppColors.danger,
          AppColors.cardEpic,
          AppColors.secondary,
          AppColors.cardLegendary,
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
