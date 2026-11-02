import '../repositories/audio_repository.dart';

/// UseCase responsible for toggling mute state on the [AudioRepository].
class ToggleSoundUseCase {
  final AudioRepository _audioRepository;

  const ToggleSoundUseCase(this._audioRepository);

  /// Toggles mute state and returns the new `isMuted` boolean.
  bool call() {
    _audioRepository.toggleMute();
    return _audioRepository.isMuted;
  }
}
