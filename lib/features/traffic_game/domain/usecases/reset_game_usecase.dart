import '../entities/circle_traffic_models.dart';
import '../entities/game_traffic_state.dart';
import '../repositories/stage_repository.dart';
import '../services/traffic_math_service.dart';

/// UseCase responsible for creating/resetting traffic simulation states across
/// classic mode, 100 campaign stages, and all 6 game modes.
class ResetGameUseCase {
  final StageRepository _stageRepository;

  const ResetGameUseCase(this._stageRepository);

  /// Creates the initial state on app launch (Stage 1 Campaign).
  GameTrafficState call({
    int stageId = 1,
    CTGameMode mode = CTGameMode.campaign,
    bool classicRing = false,
  }) {
    TrafficMath.initialize();
    if (classicRing) {
      return GameTrafficState.createInitial();
    }
    return GameTrafficState.createForStage(stageId, mode: mode);
  }

  /// Retries the current stage or classic ring.
  GameTrafficState retry(GameTrafficState current) {
    TrafficMath.initialize();
    if (current.useStagePaths) {
      return GameTrafficState.createForStage(
        current.stageId,
        mode: current.mode,
        bossRushIndex: current.bossRushIndex,
      );
    }
    return GameTrafficState.createInitial();
  }

  /// Advances to the next stage (or next boss in Boss Rush mode).
  GameTrafficState nextStage(GameTrafficState current) {
    TrafficMath.initialize();
    if (current.mode == CTGameMode.bossRush) {
      final nextBossIdx = (current.bossRushIndex + 1) % 10;
      return GameTrafficState.createForStage(
        (nextBossIdx + 1) * 10,
        mode: CTGameMode.bossRush,
        bossRushIndex: nextBossIdx,
      );
    }
    final totalStages = _stageRepository.stages.length;
    final nextId = current.stageId >= totalStages ? 1 : current.stageId + 1;
    return GameTrafficState.createForStage(
      nextId,
      mode: CTGameMode.campaign,
    );
  }

  /// Switches to one of the 6 game modes.
  GameTrafficState selectMode(GameTrafficState current, CTGameMode mode) {
    TrafficMath.initialize();
    final startStageId = mode == CTGameMode.bossRush ? 10 : current.stageId;
    return GameTrafficState.createForStage(
      startStageId,
      mode: mode,
      bossRushIndex: 0,
    );
  }

  /// Selects a specific stage (1..100) in Campaign mode.
  GameTrafficState selectStage(int stageId) {
    TrafficMath.initialize();
    return GameTrafficState.createForStage(
      stageId,
      mode: CTGameMode.campaign,
    );
  }
}
