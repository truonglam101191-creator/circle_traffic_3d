import '../entities/game_traffic_state.dart';
import '../services/traffic_math_service.dart';

/// Result returned from advancing the simulation by one tick (`dt`).
class AdvanceTrafficResult {
  final GameTrafficState nextState;
  final bool justCrashed;
  final bool justFailed;
  final bool justCleared;
  final bool justMerged;
  final bool justConverted;
  final int? rewardCarId;
  final int? convertedCarId;

  const AdvanceTrafficResult({
    required this.nextState,
    required this.justCrashed,
    required this.justFailed,
    required this.justCleared,
    required this.justMerged,
    required this.justConverted,
    this.rewardCarId,
    this.convertedCarId,
  });
}

/// UseCase responsible for stepping the traffic physics simulation forward by `dt`
/// and detecting crash, stage-clear, clean-merge, and police-conversion events.
class AdvanceTrafficUseCase {
  const AdvanceTrafficUseCase();

  AdvanceTrafficResult call(
    GameTrafficState currentState,
    double dt, {
    int? lastConvertedId,
  }) {
    final clampedDt = dt.clamp(0.0, 0.05);
    final speed = TrafficMath.paceForMerges(
      TrafficMath.baseTrafficSpeed,
      currentState.cleanMerges,
    );

    final wasPhase = currentState.runPhase;
    final wasCrashed = currentState.crashed;
    final prevMerges = currentState.cleanMerges;

    final nextState = currentState.advance(clampedDt, speed);

    final justCrashed = nextState.crashed && !wasCrashed;
    final justFailed =
        nextState.runPhase == 'failed' && wasPhase != 'failed' && !wasCrashed;
    final justCleared =
        nextState.runPhase == 'cleared' && wasPhase != 'cleared';
    final justMerged =
        !nextState.crashed && nextState.cleanMerges > prevMerges;
    final justConverted = nextState.lastConversion != null &&
        nextState.lastConversion!.id != lastConvertedId;

    return AdvanceTrafficResult(
      nextState: nextState,
      justCrashed: justCrashed,
      justFailed: justFailed,
      justCleared: justCleared,
      justMerged: justMerged,
      justConverted: justConverted,
      rewardCarId: justMerged ? nextState.lastMerge?.id : null,
      convertedCarId: justConverted ? nextState.lastConversion?.id : null,
    );
  }
}
