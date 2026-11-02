import '../entities/circle_traffic_models.dart';
import '../entities/game_traffic_state.dart';
import '../repositories/audio_repository.dart';
import '../services/traffic_math_service.dart';

/// UseCase responsible for releasing the front car from the waiting queue onto the ramp.
class ReleaseCarUseCase {
  final AudioRepository _audioRepository;

  const ReleaseCarUseCase(this._audioRepository);

  /// Attempts to release the next waiting car.
  /// Returns `(state: nextState, released: true)` if a car was launched.
  ({GameTrafficState state, bool released}) call(
    GameTrafficState currentState,
  ) {
    if (currentState.runPhase != 'playing' ||
        currentState.crashed ||
        currentState.cooldown > 0 ||
        currentState.queue.isEmpty) {
      return (state: currentState, released: false);
    }

    final nextRole = currentState.queue.first.role;
    if (nextRole == CTCarRole.police) {
      _audioRepository.playPolice();
    } else {
      _audioRepository.playRelease();
    }

    final speed = TrafficMath.paceForMerges(
      TrafficMath.baseTrafficSpeed,
      currentState.cleanMerges,
    );
    final nextState = currentState.releaseCar(speed);
    return (state: nextState, released: true);
  }
}
