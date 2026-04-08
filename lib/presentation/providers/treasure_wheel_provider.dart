import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/treasure_wheel.dart';
import '../../domain/usecases/treasure/spin_treasure_wheel_usecase.dart';
import '../../domain/usecases/usecase.dart';
import 'auth_provider.dart';
import 'usecase_providers.dart';
import 'user_provider.dart';
import 'vocabulary_provider.dart';

enum TreasureWheelPhase {
  loading,
  ready,
  spinning,
  revealing,
  rewarded,
  completed,
  error,
}

class TreasureWheelState {
  const TreasureWheelState({
    this.phase = TreasureWheelPhase.loading,
    this.slices = const [],
    this.result,
    this.errorMessage,
  });

  final TreasureWheelPhase phase;
  final List<TreasureWheelSlice> slices;
  final TreasureSpinResult? result;
  final String? errorMessage;

  TreasureWheelState copyWith({
    TreasureWheelPhase? phase,
    List<TreasureWheelSlice>? slices,
    TreasureSpinResult? result,
    String? errorMessage,
  }) {
    return TreasureWheelState(
      phase: phase ?? this.phase,
      slices: slices ?? this.slices,
      result: result ?? this.result,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

class TreasureWheelController extends StateNotifier<TreasureWheelState> {
  TreasureWheelController(this._ref) : super(const TreasureWheelState());

  final Ref _ref;

  Future<void> loadSlices() async {
    state = state.copyWith(phase: TreasureWheelPhase.loading);

    final useCase = _ref.read(getWheelSlicesUseCaseProvider);
    final result = await useCase(const NoParams());

    result.fold(
      (failure) {
        state = state.copyWith(
          phase: TreasureWheelPhase.error,
          errorMessage: failure.message,
        );
      },
      (slices) {
        if (slices.length < 2) {
          state = state.copyWith(
            phase: TreasureWheelPhase.error,
            errorMessage: 'No rewards available',
          );
          return;
        }
        state = state.copyWith(
          phase: TreasureWheelPhase.ready,
          slices: slices,
        );
      },
    );
  }

  Future<void> spin({required String unitId, required String itemId}) async {
    if (state.phase != TreasureWheelPhase.ready) return;

    state = state.copyWith(phase: TreasureWheelPhase.spinning);

    final userId = _ref.read(currentUserIdProvider);
    if (userId == null) {
      state = state.copyWith(
        phase: TreasureWheelPhase.error,
        errorMessage: 'Not logged in',
      );
      return;
    }

    final useCase = _ref.read(spinTreasureWheelUseCaseProvider);
    final result = await useCase(
      SpinTreasureWheelParams(userId: userId, unitId: unitId, itemId: itemId),
    );

    result.fold(
      (failure) {
        debugPrint('Treasure spin error: ${failure.message}');
        state = state.copyWith(
          phase: TreasureWheelPhase.error,
          errorMessage: failure.message,
        );
      },
      (spinResult) {
        state = state.copyWith(
          phase: TreasureWheelPhase.revealing,
          result: spinResult,
        );
      },
    );
  }

  void showReward() {
    state = state.copyWith(phase: TreasureWheelPhase.rewarded);
  }

  void complete() {
    _ref.invalidate(nodeCompletionsProvider);
    _ref.invalidate(currentUserProvider);
    _ref.invalidate(userControllerProvider);
    state = state.copyWith(phase: TreasureWheelPhase.completed);
  }
}

final treasureWheelControllerProvider =
    StateNotifierProvider.autoDispose<TreasureWheelController, TreasureWheelState>(
  (ref) => TreasureWheelController(ref),
);
