import '../entities/game_traffic_state.dart';
import '../repositories/audio_repository.dart';

/// UseCase for activating the Slow-Mo booster.
class TriggerSlowMoUseCase {
  final AudioRepository _audioRepository;

  const TriggerSlowMoUseCase(this._audioRepository);

  ({GameTrafficState state, bool triggered}) call(GameTrafficState current) {
    if (current.slowMoCharges <= 0 || current.slowMoRemaining > 0) {
      return (state: current, triggered: false);
    }
    _audioRepository.playPowerup();
    return (state: current.triggerSlowMo(), triggered: true);
  }
}

/// UseCase for activating the Zap-Clear booster.
class TriggerZapClearUseCase {
  final AudioRepository _audioRepository;

  const TriggerZapClearUseCase(this._audioRepository);

  ({GameTrafficState state, bool triggered}) call(GameTrafficState current) {
    if (current.zapCharges <= 0) {
      return (state: current, triggered: false);
    }
    _audioRepository.playPowerup();
    return (state: current.triggerZapClear(), triggered: true);
  }
}
