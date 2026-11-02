/// Abstract repository contract for game sound effects (Domain Layer).
abstract class AudioRepository {
  bool get isMuted;
  void toggleMute();
  Future<void> warmUp();
  Future<void> playRelease();
  Future<void> playMerge();
  Future<void> playCrash();
  Future<void> playPolice();
  Future<void> playConvert();
  Future<void> playStageClear();
  Future<void> playClick();
  Future<void> playPowerup();
  void dispose();
}
