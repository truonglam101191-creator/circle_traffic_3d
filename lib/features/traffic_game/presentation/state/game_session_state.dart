import '../../domain/entities/game_traffic_state.dart';
import '../../domain/entities/reward_popup_entity.dart';

/// Immutable presentation state managed by Riverpod's `GameSessionNotifier`.
class GameSessionState {
  final GameTrafficState traffic;
  final double elapsedTime;
  final bool isMuted;
  final bool sceneReady;
  final String lang;
  final int streak;
  final int bestEndlessScore;
  final Set<int> clearedStages;
  final bool showModeStageSelector;
  final List<RewardPopupData> rewards;
  final double badgeBounceTime;
  final double releaseBounceTime;
  final double crashFlashTime;

  const GameSessionState({
    required this.traffic,
    required this.elapsedTime,
    required this.isMuted,
    required this.sceneReady,
    this.lang = 'vi',
    this.streak = 0,
    this.bestEndlessScore = 0,
    this.clearedStages = const <int>{},
    this.showModeStageSelector = false,
    required this.rewards,
    this.badgeBounceTime = -10.0,
    this.releaseBounceTime = -10.0,
    this.crashFlashTime = -10.0,
  });

  double get badgeBounceScale =>
      _computeBounceScale(badgeBounceTime, 0.26, 1.07);

  double get releaseBounceScale =>
      _computeBounceScale(releaseBounceTime, 0.24, 1.03);

  double get crashFlashOpacity => _computeCrashFlashOpacity();

  double _computeBounceScale(double triggerTime, double duration, double peak) {
    final age = elapsedTime - triggerTime;
    if (age < 0 || age >= duration) return 1.0;
    final t = age / duration;
    if (t < 0.42) {
      return 1.0 + (peak - 1.0) * (t / 0.42);
    } else {
      return peak - (peak - 1.0) * ((t - 0.42) / 0.58);
    }
  }

  double _computeCrashFlashOpacity() {
    final age = elapsedTime - crashFlashTime;
    if (age < 0 || age >= 0.44) return 0.0;
    final t = age / 0.44;
    if (t < 0.14) {
      return 0.72 * (t / 0.14);
    }
    return 0.72 * (1.0 - (t - 0.14) / 0.86);
  }

  GameSessionState copyWith({
    GameTrafficState? traffic,
    double? elapsedTime,
    bool? isMuted,
    bool? sceneReady,
    String? lang,
    int? streak,
    int? bestEndlessScore,
    Set<int>? clearedStages,
    bool? showModeStageSelector,
    List<RewardPopupData>? rewards,
    double? badgeBounceTime,
    double? releaseBounceTime,
    double? crashFlashTime,
  }) {
    return GameSessionState(
      traffic: traffic ?? this.traffic,
      elapsedTime: elapsedTime ?? this.elapsedTime,
      isMuted: isMuted ?? this.isMuted,
      sceneReady: sceneReady ?? this.sceneReady,
      lang: lang ?? this.lang,
      streak: streak ?? this.streak,
      bestEndlessScore: bestEndlessScore ?? this.bestEndlessScore,
      clearedStages: clearedStages ?? this.clearedStages,
      showModeStageSelector:
          showModeStageSelector ?? this.showModeStageSelector,
      rewards: rewards ?? this.rewards,
      badgeBounceTime: badgeBounceTime ?? this.badgeBounceTime,
      releaseBounceTime: releaseBounceTime ?? this.releaseBounceTime,
      crashFlashTime: crashFlashTime ?? this.crashFlashTime,
    );
  }
}
