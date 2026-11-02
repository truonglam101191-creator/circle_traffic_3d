import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter_soloud/flutter_soloud.dart';

class _PreparedSound {
  final String _name;
  final Uint8List Function() _builder;
  AudioSource? _source;
  Uint8List? _bytes;
  bool _loading = false;
  int lastPlayedMs = 0;

  _PreparedSound(this._name, this._builder);

  Future<void> preload(Future<bool> Function() ensureEngineReady) async {
    if (_source != null || _loading) return;
    _loading = true;
    try {
      final bytes = _bytes ??= _builder();
      final engineOk = await ensureEngineReady();
      if (!engineOk) {
        _loading = false;
        return;
      }
      _source ??= await SoLoud.instance.loadMem(_name, bytes);
    } catch (_) {
      // Ignore audio backend errors on headless/unsupported environments
    } finally {
      _loading = false;
    }
  }

  Future<void> trigger(Future<bool> Function() ensureEngineReady) {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - lastPlayedMs < 45) return SynchronousFuture<void>(null);
    lastPlayedMs = now;

    // Zero-allocation synchronous fast path when already warmed up
    final readySrc = _source;
    if (readySrc != null && SoLoud.instance.isInitialized) {
      try {
        SoLoud.instance.play(readySrc);
      } catch (_) {}
      return SynchronousFuture<void>(null);
    }

    return _triggerSlow(ensureEngineReady);
  }

  Future<void> _triggerSlow(Future<bool> Function() ensureEngineReady) async {
    try {
      await preload(ensureEngineReady);
      final src = _source;
      if (src != null && SoLoud.instance.isInitialized) {
        SoLoud.instance.play(src);
      }
    } catch (_) {}
  }

  void dispose() {
    final src = _source;
    _source = null;
    if (src != null && SoLoud.instance.isInitialized) {
      try {
        SoLoud.instance.disposeSource(src);
      } catch (_) {}
    }
  }
}

/// Low-latency C++ FFI procedural audio synthesizer powered by `flutter_soloud`.
class GameAudio {
  bool isMuted = false;
  Future<bool>? _engineInitFuture;

  late final _PreparedSound _releaseSfx =
      _PreparedSound('release.wav', _synthRelease);
  late final _PreparedSound _mergeSfx =
      _PreparedSound('merge.wav', _synthMerge);
  late final _PreparedSound _crashSfx =
      _PreparedSound('crash.wav', _synthCrash);
  late final _PreparedSound _policeSfx =
      _PreparedSound('police.wav', _synthPolice);
  late final _PreparedSound _convertSfx =
      _PreparedSound('convert.wav', _synthConvert);
  late final _PreparedSound _stageClearSfx =
      _PreparedSound('stage_clear.wav', _synthStageClear);
  late final _PreparedSound _clickSfx =
      _PreparedSound('click.wav', _synthClick);
  late final _PreparedSound _powerupSfx =
      _PreparedSound('powerup.wav', _synthPowerup);

  GameAudio();

  Future<bool> _ensureEngineReady() {
    if (SoLoud.instance.isInitialized) {
      return SynchronousFuture<bool>(true);
    }
    return _engineInitFuture ??= _initSoLoud();
  }

  Future<bool> _initSoLoud() async {
    try {
      if (!SoLoud.instance.isInitialized) {
        await SoLoud.instance.init();
      }
      return SoLoud.instance.isInitialized;
    } catch (e) {
      debugPrint('SoLoud init error: $e');
      _engineInitFuture = null;
      return false;
    }
  }

  void toggleMute() {
    isMuted = !isMuted;
  }

  /// Asynchronously warms up the C++ SoLoud audio stream and pre-loads the 8
  /// tiny SFX buffers across separate background frames so gameplay taps and
  /// merges never stall a frame opening AAudio or decoding WAV bytes.
  Future<void> warmUp() async {
    try {
      await Future<void>.delayed(const Duration(milliseconds: 120));
      final ok = await _ensureEngineReady();
      if (!ok) return;

      final sounds = <_PreparedSound>[
        _releaseSfx,
        _mergeSfx,
        _crashSfx,
        _clickSfx,
        _convertSfx,
        _policeSfx,
        _stageClearSfx,
        _powerupSfx,
      ];
      for (final sfx in sounds) {
        await Future<void>.delayed(const Duration(milliseconds: 28));
        await sfx.preload(_ensureEngineReady);
      }
    } catch (_) {}
  }

  Future<void> _play(_PreparedSound sfx) {
    if (isMuted) return SynchronousFuture<void>(null);
    return sfx.trigger(_ensureEngineReady);
  }

  Future<void> playRelease() => _play(_releaseSfx);
  Future<void> playMerge() => _play(_mergeSfx);
  Future<void> playCrash() => _play(_crashSfx);
  Future<void> playPolice() => _play(_policeSfx);
  Future<void> playConvert() => _play(_convertSfx);
  Future<void> playStageClear() => _play(_stageClearSfx);
  Future<void> playClick() => _play(_clickSfx);
  Future<void> playPowerup() => _play(_powerupSfx);

  void dispose() {
    _releaseSfx.dispose();
    _mergeSfx.dispose();
    _crashSfx.dispose();
    _policeSfx.dispose();
    _convertSfx.dispose();
    _stageClearSfx.dispose();
    _clickSfx.dispose();
    _powerupSfx.dispose();
  }

  // --- Sound Synthesizer (8000 Hz ultra-lightweight PCM WAV) ---
  static const int _sampleRate = 8000;

  static Uint8List _createWav(int sampleRate, List<double> samples) {
    final byteCount = samples.length * 2;
    final buffer = ByteData(44 + byteCount);

    // RIFF chunk
    buffer.setUint8(0, 0x52); // 'R'
    buffer.setUint8(1, 0x49); // 'I'
    buffer.setUint8(2, 0x46); // 'F'
    buffer.setUint8(3, 0x46); // 'F'
    buffer.setUint32(4, 36 + byteCount, Endian.little);
    buffer.setUint8(8, 0x57); // 'W'
    buffer.setUint8(9, 0x41); // 'A'
    buffer.setUint8(10, 0x56); // 'V'
    buffer.setUint8(11, 0x45); // 'E'

    // fmt subchunk
    buffer.setUint8(12, 0x66); // 'f'
    buffer.setUint8(13, 0x6D); // 'm'
    buffer.setUint8(14, 0x74); // 't'
    buffer.setUint8(15, 0x20); // ' '
    buffer.setUint32(16, 16, Endian.little);
    buffer.setUint16(20, 1, Endian.little); // PCM
    buffer.setUint16(22, 1, Endian.little); // Mono
    buffer.setUint32(24, sampleRate, Endian.little);
    buffer.setUint32(28, sampleRate * 2, Endian.little); // Byte rate
    buffer.setUint16(32, 2, Endian.little); // Block align
    buffer.setUint16(34, 16, Endian.little); // Bits per sample

    // data subchunk
    buffer.setUint8(36, 0x64); // 'd'
    buffer.setUint8(37, 0x61); // 'a'
    buffer.setUint8(38, 0x74); // 't'
    buffer.setUint8(39, 0x61); // 'a'
    buffer.setUint32(40, byteCount, Endian.little);

    for (int i = 0; i < samples.length; i++) {
      final s = (samples[i].clamp(-1.0, 1.0) * 32767).toInt();
      buffer.setInt16(44 + i * 2, s, Endian.little);
    }

    return buffer.buffer.asUint8List();
  }

  static void _addTone({
    required List<double> output,
    required int sampleRate,
    required double startFreq,
    required double endFreq,
    required double startTime,
    required double duration,
    required double volume,
    bool triangle = false,
  }) {
    final startIdx = (startTime * sampleRate).toInt();
    final totalSamples = (duration * sampleRate).toInt();
    double phase = 0.0;

    for (int i = 0; i < totalSamples; i++) {
      final idx = startIdx + i;
      if (idx >= output.length) break;

      final t = i / totalSamples;
      final currentFreq = startFreq * math.pow(endFreq / startFreq, t);
      phase += 2 * math.pi * currentFreq / sampleRate;

      // Envelope: ramp up in 12ms, then exponential decay
      double env;
      const rampUp = 0.012;
      final rampUpSamples = (rampUp * sampleRate).toInt();
      if (i < rampUpSamples) {
        env = (i / rampUpSamples) * volume;
      } else {
        final decayT = (i - rampUpSamples) / (totalSamples - rampUpSamples);
        env = volume * math.exp(-3.5 * decayT);
      }

      double wave;
      if (triangle) {
        final normPhase = (phase / (2 * math.pi)) % 1.0;
        wave = (normPhase < 0.5 ? (4 * normPhase - 1) : (3 - 4 * normPhase));
      } else {
        wave = math.sin(phase);
      }

      output[idx] += wave * env;
    }
  }

  static Uint8List _synthRelease() {
    const totalDuration = 0.35;
    final samples =
        List<double>.filled((totalDuration * _sampleRate).toInt(), 0.0);

    _addTone(
      output: samples,
      sampleRate: _sampleRate,
      startFreq: 240,
      endFreq: 540,
      startTime: 0.0,
      duration: 0.12,
      volume: 0.38,
    );
    _addTone(
      output: samples,
      sampleRate: _sampleRate,
      startFreq: 420,
      endFreq: 180,
      startTime: 0.06,
      duration: 0.16,
      volume: 0.18,
      triangle: true,
    );
    _addTone(
      output: samples,
      sampleRate: _sampleRate,
      startFreq: 120,
      endFreq: 235,
      startTime: 0.07,
      duration: 0.23,
      volume: 0.11,
      triangle: true,
    );

    return _createWav(_sampleRate, samples);
  }

  static Uint8List _synthMerge() {
    const totalDuration = 0.42;
    final samples =
        List<double>.filled((totalDuration * _sampleRate).toInt(), 0.0);

    _addTone(
      output: samples,
      sampleRate: _sampleRate,
      startFreq: 659,
      endFreq: 659,
      startTime: 0.0,
      duration: 0.21,
      volume: 0.33,
    );
    _addTone(
      output: samples,
      sampleRate: _sampleRate,
      startFreq: 830,
      endFreq: 830,
      startTime: 0.055,
      duration: 0.22,
      volume: 0.26,
    );
    _addTone(
      output: samples,
      sampleRate: _sampleRate,
      startFreq: 988,
      endFreq: 988,
      startTime: 0.105,
      duration: 0.27,
      volume: 0.24,
    );

    return _createWav(_sampleRate, samples);
  }

  static Uint8List _synthCrash() {
    const totalDuration = 0.35;
    final samples =
        List<double>.filled((totalDuration * _sampleRate).toInt(), 0.0);

    _addTone(
      output: samples,
      sampleRate: _sampleRate,
      startFreq: 150,
      endFreq: 65,
      startTime: 0.0,
      duration: 0.24,
      volume: 0.34,
      triangle: true,
    );

    return _createWav(_sampleRate, samples);
  }

  static Uint8List _synthPolice() {
    const totalDuration = 0.45;
    final samples =
        List<double>.filled((totalDuration * _sampleRate).toInt(), 0.0);

    _addTone(
      output: samples,
      sampleRate: _sampleRate,
      startFreq: 680,
      endFreq: 960,
      startTime: 0.0,
      duration: 0.20,
      volume: 0.30,
      triangle: true,
    );
    _addTone(
      output: samples,
      sampleRate: _sampleRate,
      startFreq: 960,
      endFreq: 680,
      startTime: 0.20,
      duration: 0.22,
      volume: 0.28,
      triangle: true,
    );

    return _createWav(_sampleRate, samples);
  }

  static Uint8List _synthConvert() {
    const totalDuration = 0.36;
    final samples =
        List<double>.filled((totalDuration * _sampleRate).toInt(), 0.0);

    _addTone(
      output: samples,
      sampleRate: _sampleRate,
      startFreq: 784,
      endFreq: 1175,
      startTime: 0.0,
      duration: 0.14,
      volume: 0.30,
    );
    _addTone(
      output: samples,
      sampleRate: _sampleRate,
      startFreq: 1175,
      endFreq: 1568,
      startTime: 0.09,
      duration: 0.22,
      volume: 0.28,
    );

    return _createWav(_sampleRate, samples);
  }

  static Uint8List _synthStageClear() {
    const totalDuration = 0.75;
    final samples =
        List<double>.filled((totalDuration * _sampleRate).toInt(), 0.0);

    final notes = [523.25, 659.25, 783.99, 1046.50];
    for (int i = 0; i < notes.length; i++) {
      _addTone(
        output: samples,
        sampleRate: _sampleRate,
        startFreq: notes[i],
        endFreq: notes[i],
        startTime: i * 0.11,
        duration: i == 3 ? 0.38 : 0.22,
        volume: 0.32,
      );
    }

    return _createWav(_sampleRate, samples);
  }

  static Uint8List _synthClick() {
    const totalDuration = 0.09;
    final samples =
        List<double>.filled((totalDuration * _sampleRate).toInt(), 0.0);

    _addTone(
      output: samples,
      sampleRate: _sampleRate,
      startFreq: 520,
      endFreq: 740,
      startTime: 0.0,
      duration: 0.07,
      volume: 0.25,
    );

    return _createWav(_sampleRate, samples);
  }

  static Uint8List _synthPowerup() {
    const totalDuration = 0.42;
    final samples =
        List<double>.filled((totalDuration * _sampleRate).toInt(), 0.0);

    _addTone(
      output: samples,
      sampleRate: _sampleRate,
      startFreq: 320,
      endFreq: 880,
      startTime: 0.0,
      duration: 0.35,
      volume: 0.32,
      triangle: true,
    );

    return _createWav(_sampleRate, samples);
  }
}
