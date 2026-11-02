import '../../domain/repositories/audio_repository.dart';
import '../datasources/synthesizer_audio_datasource.dart';

/// Concrete implementation of [AudioRepository] backed by procedural WAV synthesis
/// ([GameAudio]).
class AudioRepositoryImpl implements AudioRepository {
  final GameAudio _audioDataSource;

  AudioRepositoryImpl(this._audioDataSource);

  @override
  bool get isMuted => _audioDataSource.isMuted;

  @override
  void toggleMute() => _audioDataSource.toggleMute();

  @override
  Future<void> warmUp() => _audioDataSource.warmUp();

  @override
  Future<void> playRelease() => _audioDataSource.playRelease();

  @override
  Future<void> playMerge() => _audioDataSource.playMerge();

  @override
  Future<void> playCrash() => _audioDataSource.playCrash();

  @override
  Future<void> playPolice() => _audioDataSource.playPolice();

  @override
  Future<void> playConvert() => _audioDataSource.playConvert();

  @override
  Future<void> playStageClear() => _audioDataSource.playStageClear();

  @override
  Future<void> playClick() => _audioDataSource.playClick();

  @override
  Future<void> playPowerup() => _audioDataSource.playPowerup();

  @override
  void dispose() => _audioDataSource.dispose();
}
