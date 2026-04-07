import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/treasure_wheel_provider.dart';
import '../../widgets/treasure/treasure_wheel_painter.dart';

class TreasureWheelScreen extends ConsumerStatefulWidget {
  const TreasureWheelScreen({super.key, required this.unitId});

  final String unitId;

  @override
  ConsumerState<TreasureWheelScreen> createState() => _TreasureWheelScreenState();
}

class _TreasureWheelScreenState extends ConsumerState<TreasureWheelScreen> {
  final _wheelKey = GlobalKey<TreasureWheelWidgetState>();

  @override
  void initState() {
    super.initState();
    // Load slices on first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(treasureWheelControllerProvider.notifier).loadSlices();
    });
  }

  void _onSpin() {
    // Start wheel spinning immediately for visual feedback
    _wheelKey.currentState?.startIdleSpin();
    // Fire RPC in parallel
    final controller = ref.read(treasureWheelControllerProvider.notifier);
    controller.spin(widget.unitId);
  }

  void _onSpinAnimationComplete() {
    final state = ref.read(treasureWheelControllerProvider);
    if (state.phase == TreasureWheelPhase.revealing) {
      // Short delay before showing reward
      Future.delayed(const Duration(milliseconds: 500), () {
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

    // When RPC returns during spin, start the wheel animation to target
    ref.listen<TreasureWheelState>(treasureWheelControllerProvider, (prev, next) {
      if (prev?.phase == TreasureWheelPhase.spinning &&
          next.phase == TreasureWheelPhase.revealing &&
          next.result != null) {
        _wheelKey.currentState?.spinTo(next.result!.sliceIndex);
      }
    });

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: state.phase == TreasureWheelPhase.spinning
            ? const SizedBox.shrink() // Prevent back during spin
            : null,
      ),
      body: SafeArea(
        child: Center(
          child: _buildBody(state),
        ),
      ),
    );
  }

  Widget _buildBody(TreasureWheelState state) {
    switch (state.phase) {
      case TreasureWheelPhase.loading:
        return const CircularProgressIndicator(color: Colors.amber);

      case TreasureWheelPhase.error:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 16),
            Text(
              state.errorMessage ?? 'Something went wrong',
              style: const TextStyle(color: Colors.white, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Go Back'),
            ),
          ],
        );

      case TreasureWheelPhase.ready:
      case TreasureWheelPhase.spinning:
      case TreasureWheelPhase.revealing:
        return _buildWheelView(state);

      case TreasureWheelPhase.rewarded:
      case TreasureWheelPhase.completed:
        return _buildRewardView(state);
    }
  }

  Widget _buildWheelView(TreasureWheelState state) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          'Spin to Win!',
          style: TextStyle(
            color: Colors.amber,
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 32),
        TreasureWheelWidget(
          key: _wheelKey,
          slices: state.slices,
          onSpinComplete: _onSpinAnimationComplete,
        ),
        const SizedBox(height: 32),
        SizedBox(
          width: 200,
          height: 56,
          child: ElevatedButton(
            onPressed: state.phase == TreasureWheelPhase.ready ? _onSpin : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
              textStyle: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            child: state.phase == TreasureWheelPhase.spinning
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.black,
                    ),
                  )
                : const Text('SPIN'),
          ),
        ),
      ],
    );
  }

  Widget _buildRewardView(TreasureWheelState state) {
    final result = state.result!;
    final isCoin = result.rewardType == 'coin';

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          isCoin ? Icons.monetization_on : Icons.style,
          color: Colors.amber,
          size: 80,
        ),
        const SizedBox(height: 24),
        const Text(
          'Congratulations!',
          style: TextStyle(
            color: Colors.amber,
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'You won ${result.sliceLabel}!',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
          ),
        ),
        if (result.cards != null && result.cards!.isNotEmpty) ...[
          const SizedBox(height: 24),
          SizedBox(
            height: 120,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(horizontal: 32),
              itemCount: result.cards!.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final card = result.cards![index];
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 70,
                      height: 90,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.amber, width: 2),
                        color: Colors.white10,
                      ),
                      child: Center(
                        child: Text(
                          card.card.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (card.isNew)
                      const Text(
                        'NEW!',
                        style: TextStyle(
                          color: Colors.greenAccent,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
        const SizedBox(height: 32),
        SizedBox(
          width: 200,
          height: 56,
          child: ElevatedButton(
            onPressed: _onClaim,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
              textStyle: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            child: const Text('CLAIM'),
          ),
        ),
      ],
    );
  }
}
