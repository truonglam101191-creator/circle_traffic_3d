import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/datasources/circle_traffic_localization.dart';
import '../../data/datasources/synthesizer_audio_datasource.dart';
import '../../data/repositories/audio_repository_impl.dart';
import '../../data/repositories/stage_repository_impl.dart';
import '../../domain/entities/circle_traffic_models.dart';
import '../../domain/entities/game_traffic_state.dart';
import '../../domain/entities/reward_popup_entity.dart';
import '../../domain/repositories/audio_repository.dart';
import '../../domain/repositories/stage_repository.dart';
import '../../domain/services/traffic_math_service.dart';
import '../../domain/usecases/advance_traffic_usecase.dart';
import '../../domain/usecases/booster_usecase.dart';
import '../../domain/usecases/release_car_usecase.dart';
import '../../domain/usecases/reset_game_usecase.dart';
import '../../domain/usecases/toggle_sound_usecase.dart';
import '../render3d/scene_3d_world.dart';
import '../state/game_session_state.dart';

// ---------------------------------------------------------------------------
// 1. Data & Repository Providers (Dependency Injection)
// ---------------------------------------------------------------------------

final audioDataSourceProvider = Provider<GameAudio>((ref) {
  final audio = GameAudio();
  ref.onDispose(audio.dispose);
  return audio;
});

final audioRepositoryProvider = Provider<AudioRepository>((ref) {
  final dataSource = ref.watch(audioDataSourceProvider);
  return AudioRepositoryImpl(dataSource);
});

final stageRepositoryProvider = Provider<StageRepository>((ref) {
  return const StageRepositoryImpl();
});

// ---------------------------------------------------------------------------
// 2. Domain UseCase Providers
// ---------------------------------------------------------------------------

final advanceTrafficUseCaseProvider = Provider<AdvanceTrafficUseCase>((ref) {
  return const AdvanceTrafficUseCase();
});

final releaseCarUseCaseProvider = Provider<ReleaseCarUseCase>((ref) {
  final audioRepo = ref.watch(audioRepositoryProvider);
  return ReleaseCarUseCase(audioRepo);
});

final resetGameUseCaseProvider = Provider<ResetGameUseCase>((ref) {
  final stageRepo = ref.watch(stageRepositoryProvider);
  return ResetGameUseCase(stageRepo);
});

final triggerSlowMoUseCaseProvider = Provider<TriggerSlowMoUseCase>((ref) {
  final audioRepo = ref.watch(audioRepositoryProvider);
  return TriggerSlowMoUseCase(audioRepo);
});

final triggerZapClearUseCaseProvider = Provider<TriggerZapClearUseCase>((ref) {
  final audioRepo = ref.watch(audioRepositoryProvider);
  return TriggerZapClearUseCase(audioRepo);
});

final toggleSoundUseCaseProvider = Provider<ToggleSoundUseCase>((ref) {
  final audioRepo = ref.watch(audioRepositoryProvider);
  return ToggleSoundUseCase(audioRepo);
});

// ---------------------------------------------------------------------------
// 3. 3D Scene Graph & Frame Tick Providers
// ---------------------------------------------------------------------------

final scene3DWorldProvider = Provider<Scene3DWorld>((ref) {
  return Scene3DWorld();
});

/// High-frequency 60fps tick notifier exclusively for `SceneView` so the 3D
/// viewport repaints without forcing unnecessary HUD rebuilds.
final sceneTickProvider = Provider<ValueNotifier<int>>((ref) {
  final notifier = ValueNotifier<int>(0);
  ref.onDispose(notifier.dispose);
  return notifier;
});

/// Lightweight tick notifier exclusively for floating "Smooth merge! +1" popups
/// so they animate smoothly in their own isolated widget without rebuilding `GameOverlay`.
final rewardTickProvider = Provider<ValueNotifier<int>>((ref) {
  final notifier = ValueNotifier<int>(0);
  ref.onDispose(notifier.dispose);
  return notifier;
});

// ---------------------------------------------------------------------------
// 4. Presentation State Notifier (GameSessionNotifier)
// ---------------------------------------------------------------------------

final gameSessionProvider =
    NotifierProvider<GameSessionNotifier, GameSessionState>(
  GameSessionNotifier.new,
);

class GameSessionNotifier extends Notifier<GameSessionState> {
  Duration _lastTickTime = Duration.zero;
  int? _lastConvertedId;
  late GameTrafficState _liveTraffic;
  double _elapsedTime = 0.0;
  final List<RewardPopupData> _activeRewards = [];

  /// Returns the latest 60fps traffic state for the 3D camera & viewport.
  GameTrafficState get liveTraffic => _liveTraffic;

  /// Returns the active floating reward popups for the isolated rewards layer.
  List<RewardPopupData> get activeRewards => _activeRewards;

  @override
  GameSessionState build() {
    _lastTickTime = Duration.zero;
    _lastConvertedId = null;
    _elapsedTime = 0.0;
    _activeRewards.clear();
    final initialTraffic = ref.read(resetGameUseCaseProvider).call(
          stageId: 1,
          mode: CTGameMode.campaign,
        );
    _liveTraffic = initialTraffic;
    final isMuted = ref.read(audioRepositoryProvider).isMuted;
    return GameSessionState(
      traffic: initialTraffic,
      elapsedTime: 0.0,
      isMuted: isMuted,
      sceneReady: false,
      rewards: const [],
    );
  }

  /// Initializes the 3D `flutter_scene` world progressively across frames and
  /// warms up the C++ SoLoud audio engine in the background.
  Future<void> init3D() async {
    try {
      // Allow the first 2D HUD frame to finish rendering before starting 3D setup
      await Future<void>.delayed(const Duration(milliseconds: 16));
      final world3d = ref.read(scene3DWorldProvider);
      await world3d.initialize(initialState: _liveTraffic);
      world3d.updateScene(_liveTraffic, _elapsedTime);
      if (!state.sceneReady) {
        state = state.copyWith(sceneReady: true);
      } else {
        ref.read(sceneTickProvider).value++;
      }

      // Pre-warm SoLoud AAudio stream & 8 WAV buffers across background frames
      ref.read(audioRepositoryProvider).warmUp();
    } catch (e, st) {
      debugPrint('Failed to initialize Scene3DWorld: $e\n$st');
    }
  }

  /// Called on every Ticker frame (~60 FPS).
  void onTick(Duration elapsed, {bool forceStateSync = false}) {
    if (!forceStateSync && !ref.read(scene3DWorldProvider).isInitialized) {
      _lastTickTime = elapsed;
      return;
    }
    final dt = _lastTickTime == Duration.zero
        ? 0.016
        : (elapsed - _lastTickTime).inMicroseconds / 1e6;
    _lastTickTime = elapsed;
    final clampedDt = dt.clamp(0.0, 0.05);
    final prevElapsed = _elapsedTime;
    _elapsedTime += clampedDt;

    // Pause 3D & HUD updates while browsing the 6 Modes / 100 Stages selector modal
    if (state.showModeStageSelector) {
      return;
    }

    final currentTraffic = _liveTraffic;
    final wasPhase = currentTraffic.runPhase;

    // Once settled on Fail or Stage Clear screen with no active animations, idle the loop
    if ((wasPhase == 'failed' || wasPhase == 'cleared') &&
        _activeRewards.isEmpty &&
        (_elapsedTime - state.crashFlashTime) > 0.5 &&
        !forceStateSync) {
      return;
    }

    final wasCrashed = currentTraffic.crashed;
    final prevMerges = currentTraffic.cleanMerges;
    final prevQueueLen = currentTraffic.queue.length;
    final wasCooldown = currentTraffic.cooldown;
    final prevSlowDeci = (currentTraffic.slowMoRemaining * 10).floor();
    final prevTimeDeci = (currentTraffic.timeRemaining * 10).floor();
    final prevWave = currentTraffic.waveNumber;
    final prevConv = currentTraffic.convertedCleared;
    final hadRewards = _activeRewards.isNotEmpty;

    final advanceResult = ref.read(advanceTrafficUseCaseProvider).call(
          currentTraffic,
          clampedDt,
          lastConvertedId: _lastConvertedId,
        );
    final nextTraffic = advanceResult.nextState;

    final audioRepo = ref.read(audioRepositoryProvider);
    var nextBadgeBounce = state.badgeBounceTime;
    var nextCrashFlash = state.crashFlashTime;
    var nextStreak = state.streak;
    var nextBestEndless = state.bestEndlessScore;
    var nextClearedStages = state.clearedStages;

    if (advanceResult.justCrashed) {
      audioRepo.playCrash();
      nextCrashFlash = _elapsedTime;
      nextStreak = 0;
      _activeRewards.clear();
    } else if (advanceResult.justFailed) {
      audioRepo.playCrash();
      nextStreak = 0;
    } else if (advanceResult.justCleared) {
      audioRepo.playStageClear();
      nextStreak++;
      nextClearedStages = {...nextClearedStages, nextTraffic.stageId};
    } else if (advanceResult.justMerged) {
      audioRepo.playMerge();
      nextBadgeBounce = _elapsedTime;
      if (nextTraffic.mode == CTGameMode.endless) {
        nextBestEndless = math.max(nextBestEndless, nextTraffic.cleanMerges);
      }
      if (advanceResult.rewardCarId != null) {
        _activeRewards.add(
          RewardPopupData(
            carId: advanceResult.rewardCarId!,
            customLabel: CTStrings.tr('smooth_merge', lang: state.lang),
            customBadge:
                nextTraffic.mode == CTGameMode.timeAttack ? '+1.2s' : '+1',
          ),
        );
      }
    }

    // Police conversion feedback
    if (advanceResult.justConverted && advanceResult.convertedCarId != null) {
      _lastConvertedId = advanceResult.convertedCarId;
      audioRepo.playConvert();
      nextBadgeBounce = _elapsedTime;
      _activeRewards.add(
        RewardPopupData(
          carId: advanceResult.convertedCarId!,
          customLabel: '🚓 Converted!',
          customBadge:
              nextTraffic.mode == CTGameMode.timeAttack ? '+1.5s' : 'EXIT',
        ),
      );
    }

    // Advance floating reward popups in their own isolated ValueNotifier
    for (int i = _activeRewards.length - 1; i >= 0; i--) {
      _activeRewards[i].age += clampedDt;
      if (!TrafficMath.rewardMotion(_activeRewards[i].age).visible) {
        _activeRewards.removeAt(i);
      }
    }
    if (_activeRewards.isNotEmpty || hadRewards) {
      ref.read(rewardTickProvider).value++;
    }

    _liveTraffic = nextTraffic;

    if (state.sceneReady) {
      ref.read(scene3DWorldProvider).updateScene(nextTraffic, _elapsedTime);
      ref.read(sceneTickProvider).value++;
    }

    final crashFlashJustEnded =
        (prevElapsed - nextCrashFlash) < 0.48 &&
        (_elapsedTime - nextCrashFlash) >= 0.48;

    // Only rebuild the main 2D GameOverlay on discrete gameplay state changes!
    // Never rebuild GameOverlay continuously while cars are launching or merging.
    final hudNeedsRebuild = forceStateSync ||
        nextTraffic.runPhase != wasPhase ||
        nextTraffic.crashed != wasCrashed ||
        nextTraffic.cleanMerges != prevMerges ||
        nextTraffic.queue.length != prevQueueLen ||
        (nextTraffic.cooldown <= 0 && wasCooldown > 0) ||
        advanceResult.justConverted ||
        crashFlashJustEnded ||
        (nextTraffic.slowMoRemaining * 10).floor() != prevSlowDeci ||
        (nextTraffic.mode == CTGameMode.timeAttack &&
            (nextTraffic.timeRemaining * 10).floor() != prevTimeDeci) ||
        nextTraffic.waveNumber != prevWave ||
        nextTraffic.convertedCleared != prevConv;

    if (hudNeedsRebuild) {
      state = state.copyWith(
        traffic: nextTraffic,
        elapsedTime: _elapsedTime,
        streak: nextStreak,
        bestEndlessScore: nextBestEndless,
        clearedStages: nextClearedStages,
        rewards: List<RewardPopupData>.unmodifiable(_activeRewards),
        badgeBounceTime: nextBadgeBounce,
        crashFlashTime: nextCrashFlash,
      );
    }
  }

  /// Handles user tap / Spacebar action: releases a car, retries on fail, or advances on clear.
  void releaseCar() {
    if (state.showModeStageSelector) return;
    if (_liveTraffic.runPhase == 'crashing') return;

    if (_liveTraffic.runPhase == 'failed') {
      retry();
      return;
    }

    if (_liveTraffic.runPhase == 'cleared') {
      nextStage();
      return;
    }

    final result = ref.read(releaseCarUseCaseProvider).call(_liveTraffic);
    if (!result.released) return;

    _liveTraffic = result.state;
    // When no Ticker is running (e.g. unit tests), sync the 3D scene immediately.
    // During live 60fps gameplay, let `onTick` perform the single scene update for this frame.
    if (state.sceneReady && _lastTickTime == Duration.zero) {
      ref.read(scene3DWorldProvider).updateScene(_liveTraffic, _elapsedTime);
      ref.read(sceneTickProvider).value++;
    }

    state = state.copyWith(
      traffic: _liveTraffic,
      elapsedTime: _elapsedTime,
      releaseBounceTime: _elapsedTime,
    );
  }

  /// Retries the current stage or classic mode.
  void retry() {
    ref.read(audioRepositoryProvider).playClick();
    _activeRewards.clear();
    _lastConvertedId = null;
    _liveTraffic = ref.read(resetGameUseCaseProvider).retry(_liveTraffic);
    _syncSceneAfterReset();
    state = state.copyWith(
      traffic: _liveTraffic,
      rewards: const [],
    );
  }

  /// Advances to the next stage (or next Boss in Boss Rush).
  void nextStage() {
    ref.read(audioRepositoryProvider).playClick();
    _activeRewards.clear();
    _lastConvertedId = null;
    _liveTraffic = ref.read(resetGameUseCaseProvider).nextStage(_liveTraffic);
    _syncSceneAfterReset();
    state = state.copyWith(
      traffic: _liveTraffic,
      rewards: const [],
    );
  }

  /// Switches to one of the 6 game modes.
  void selectMode(CTGameMode mode) {
    ref.read(audioRepositoryProvider).playClick();
    _activeRewards.clear();
    _lastConvertedId = null;
    _liveTraffic =
        ref.read(resetGameUseCaseProvider).selectMode(_liveTraffic, mode);
    _syncSceneAfterReset();
    state = state.copyWith(
      traffic: _liveTraffic,
      showModeStageSelector: false,
      rewards: const [],
    );
  }

  /// Selects a specific stage (1..100) in Campaign mode.
  void selectStage(int stageId) {
    ref.read(audioRepositoryProvider).playClick();
    _activeRewards.clear();
    _lastConvertedId = null;
    _liveTraffic = ref.read(resetGameUseCaseProvider).selectStage(stageId);
    _syncSceneAfterReset();
    state = state.copyWith(
      traffic: _liveTraffic,
      showModeStageSelector: false,
      rewards: const [],
    );
  }

  /// Activates the Slow-Mo booster.
  void triggerSlowMo() {
    final res = ref.read(triggerSlowMoUseCaseProvider).call(_liveTraffic);
    if (!res.triggered) return;
    _liveTraffic = res.state;
    state = state.copyWith(traffic: _liveTraffic);
  }

  /// Activates the Zap-Clear booster.
  void triggerZapClear() {
    final res = ref.read(triggerZapClearUseCaseProvider).call(_liveTraffic);
    if (!res.triggered) return;
    _liveTraffic = res.state;
    if (state.sceneReady) {
      ref.read(scene3DWorldProvider).updateScene(_liveTraffic, _elapsedTime);
      ref.read(sceneTickProvider).value++;
    }
    state = state.copyWith(traffic: _liveTraffic);
  }

  /// Toggles audio mute/unmute state.
  void toggleSound() {
    final isMuted = ref.read(toggleSoundUseCaseProvider).call();
    state = state.copyWith(isMuted: isMuted);
  }

  /// Cycles UI language (`vi` -> `en` -> `ja` -> `vi`).
  void cycleLanguage() {
    ref.read(audioRepositoryProvider).playClick();
    final nextLang = switch (state.lang) {
      'vi' => 'en',
      'en' => 'ja',
      _ => 'vi',
    };
    state = state.copyWith(lang: nextLang);
  }

  /// Opens the dedicated Main Menu screen without sound (used on initial app launch).
  void openMenu() {
    if (!state.showModeStageSelector) {
      state = state.copyWith(showModeStageSelector: true);
    }
  }

  /// Opens or closes the 6 Modes / 100 Stages Menu screen.
  void toggleSelector() {
    ref.read(audioRepositoryProvider).playClick();
    state = state.copyWith(
      showModeStageSelector: !state.showModeStageSelector,
    );
  }

  void _syncSceneAfterReset() {
    ref.read(rewardTickProvider).value++;
    if (state.sceneReady) {
      final world3d = ref.read(scene3DWorldProvider);
      world3d.resetMotion();
      world3d.updateScene(_liveTraffic, _elapsedTime);
      ref.read(sceneTickProvider).value++;
    }
  }
}
