import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../data/datasources/circle_traffic_localization.dart';
import '../../data/datasources/circle_traffic_stages.dart';
import '../../data/datasources/circle_traffic_themes.dart';
import '../../domain/services/traffic_math_service.dart';
import '../../domain/entities/circle_traffic_models.dart';
import '../../domain/entities/game_traffic_state.dart';
import '../../domain/entities/reward_popup_entity.dart';
import '../screens/menu_screen.dart';
import 'game_icons.dart';
export '../../domain/entities/reward_popup_entity.dart';

class GameOverlay extends StatelessWidget {
  final GameTrafficState state;
  final bool muted;
  final String lang;
  final int streak;
  final int bestEndlessScore;
  final Set<int> clearedStages;
  final bool showModeStageSelector;
  final VoidCallback onRelease;
  final VoidCallback onToggleSound;
  final VoidCallback onCycleLanguage;
  final VoidCallback onToggleSelector;
  final VoidCallback onNextStage;
  final VoidCallback onRetry;
  final VoidCallback onSlowMo;
  final VoidCallback onZapClear;
  final void Function(CTGameMode mode) onSelectMode;
  final void Function(int stageId) onSelectStage;
  final List<RewardPopupData> rewards;
  final Offset? Function(int carId, double elevation, Size stageSize)
  projectCar;
  final double badgeBounceScale;
  final double releaseBounceScale;
  final double crashFlashOpacity;

  const GameOverlay({
    super.key,
    required this.state,
    required this.muted,
    this.lang = 'vi',
    this.streak = 0,
    this.bestEndlessScore = 0,
    this.clearedStages = const {},
    this.showModeStageSelector = false,
    required this.onRelease,
    required this.onToggleSound,
    this.onCycleLanguage = _noop,
    this.onToggleSelector = _noop,
    this.onNextStage = _noop,
    this.onRetry = _noop,
    this.onSlowMo = _noop,
    this.onZapClear = _noop,
    this.onSelectMode = _noopMode,
    this.onSelectStage = _noopStage,
    required this.rewards,
    required this.projectCar,
    this.badgeBounceScale = 1.0,
    this.releaseBounceScale = 1.0,
    this.crashFlashOpacity = 0.0,
  });

  static void _noop() {}
  static void _noopMode(CTGameMode _) {}
  static void _noopStage(int _) {}

  String _tr(String key, [Map<String, String>? params]) =>
      CTStrings.tr(key, lang: lang, params: params);

  @override
  Widget build(BuildContext context) {
    if (showModeStageSelector) {
      return MenuScreen(
        state: state,
        lang: lang,
        muted: muted,
        clearedStages: clearedStages,
        bestEndlessScore: bestEndlessScore,
        onResumeOrPlay: onToggleSelector,
        onSelectMode: onSelectMode,
        onSelectStage: onSelectStage,
        onCycleLanguage: onCycleLanguage,
        onToggleSound: onToggleSound,
      );
    }

    final viewPadding = MediaQuery.viewPaddingOf(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final stageW = constraints.maxWidth;
        final stageH = constraints.maxHeight;
        final stageSize = Size(stageW, stageH);

        // Mobile-first UI scale relative to a standard 390dp phone width
        // (prevents 0.5x microscopic buttons/text on 360dp-390dp phones)
        final ui = (stageW / 390.0).clamp(0.86, 1.38);

        // Safe-area insets so controls never sit beneath StatusBar, Notch, or Gesture Bar
        final safeTop = math.max(viewPadding.top + 8.0, 14.0 * ui);
        final safeBottom = math.max(viewPadding.bottom + 10.0, 16.0 * ui);
        final safeLeft = math.max(viewPadding.left + 12.0 * ui, 14.0 * ui);
        final safeRight = math.max(viewPadding.right + 12.0 * ui, 14.0 * ui);

        final phase = state.runPhase;
        final isCrashed = state.crashed;
        final isFailed = phase == 'failed';
        final isCleared = phase == 'cleared';
        final hotFlow = state.cleanMerges >= 4;
        final ready = phase == 'playing' && state.cooldown <= 0;
        final firing =
            state.cooldown > 0 &&
            (state.releaseDuration - state.cooldown) < 0.4;

        final nextToken = state.queue.isNotEmpty ? state.queue.first : null;

        final buttonLabel = phase != 'playing'
            ? _tr('stopped')
            : ready
            ? _tr('release_car')
            : firing
            ? 'Whoosh!'
            : _tr('lining_up');

        final buttonDetail = nextToken != null && ready
            ? _nextTokenSubtitle(nextToken)
            : ready
            ? _tr('one_tap')
            : firing
            ? 'OFF IT GOES!'
            : 'LINING UP NEXT CAR';

        final chargeFactor = state.crashed
            ? 0.0
            : (1.0 -
                      state.cooldown /
                          (state.releaseDuration > 0
                              ? state.releaseDuration
                              : TrafficMath.releaseCooldown))
                  .clamp(0.0, 1.0);

        final mergeWord = state.cleanMerges == 1
            ? 'clean merge'
            : 'clean merges';

        final topSubRowY = safeTop + 56.0 * ui;
        final leftColumnW = math.min(stageW * 0.62, 248.0 * ui);

        return Stack(
          clipBehavior: Clip.none,
          children: [
            // Full-screen tap catcher to release car (or retry when failed)
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTapDown: (_) {
                  if (showModeStageSelector) return;
                  if (isCleared) {
                    onNextStage();
                  } else {
                    onRelease();
                  }
                },
                child: const SizedBox.expand(),
              ),
            ),

            // Slow-Mo frost tint overlay when Slow-Mo booster is active
            if (state.slowMoRemaining > 0)
              Positioned.fill(
                child: IgnorePointer(
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: const Color(0x8838BDF8),
                        width: 4.5 * ui,
                      ),
                    ),
                  ),
                ),
              ),

            // Crash flash (#fff1cb) — direct alpha color avoids GPU saveLayer()
            if (crashFlashOpacity > 0.001)
              Positioned.fill(
                child: IgnorePointer(
                  child: ColoredBox(
                    color: const Color(0xFFFFF1CB)
                        .withValues(alpha: crashFlashOpacity.clamp(0.0, 1.0)),
                  ),
                ),
              ),

            // Floating "Smooth merge! +1" reward popups (fallback for direct widget tests)
            for (final r in rewards) _buildRewardPopup(r, stageSize, ui),

            // Top-left Mode & Stage Selector Button (below StatusBar, >= 48dp touch height)
            Positioned(
              left: safeLeft,
              top: safeTop,
              width: math.min(stageW * 0.53, 204.0 * ui),
              child: RepaintBoundary(child: _buildModeStageHeaderButton(ui)),
            ),

            // Top-right Language & Sound Buttons side-by-side (below StatusBar, >= 48dp touch height)
            Positioned(
              right: safeRight,
              top: safeTop,
              child: RepaintBoundary(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildLanguageButton(ui),
                    SizedBox(width: 8.0 * ui),
                    _buildSoundButton(ui),
                  ],
                ),
              ),
            ),

            // Left Unified Score & Stage Progress Card
            Positioned(
              left: safeLeft,
              top: topSubRowY,
              width: math.min(stageW * 0.45, 174.0 * ui),
              child: RepaintBoundary(
                child: IgnorePointer(
                  child: Transform.scale(
                    scale: badgeBounceScale,
                    child: _buildCleanMergesBadge(ui, hotFlow),
                  ),
                ),
              ),
            ),

            // Right Stage Hint / Next Special Car Banner
            if (state.useStagePaths && phase == 'playing' && !isCrashed)
              Positioned(
                right: safeRight,
                top: topSubRowY,
                width: math.min(stageW * 0.45, 178.0 * ui),
                child: RepaintBoundary(
                  child: _buildStageInfoBanner(ui, nextToken),
                ),
              ),

            // Bottom-left Launch Controls + Boosters (leaves right-side 3D approach ramp 100% clear)
            if (!isCrashed && !isCleared)
              Positioned(
                left: safeLeft,
                bottom: safeBottom,
                width: leftColumnW,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    RepaintBoundary(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // .drive-motto ("Plan · Tap · Drive" + tilted yellow underline)
                          _buildDriveMotto(ui * 0.62),
                          SizedBox(height: 10.0 * ui),

                          // .status ("Find a gap.\nLet it roll.")
                          Padding(
                            padding: EdgeInsets.only(
                              left: 2.0 * ui,
                              bottom: 8.0 * ui,
                            ),
                            child: _StrokedText(
                              text: hotFlow
                                  ? _tr('keep_flowing')
                                  : _tr('find_gap'),
                              fontSize: 13.5 * ui,
                              fontWeight: FontWeight.w800,
                              height: 1.25,
                              letterSpacing: -0.2 * ui,
                              fillColor: const Color(0xFFFFF4DD),
                              strokeColor: const Color(0xFF4B2C49),
                              strokeWidth: 3.2 * ui,
                              shadowOffset: Offset(0, 1.5 * ui),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Boosters Row (Slow-Mo & Zap Clear) right above Release button for easy thumb reach
                    if (state.useStagePaths && phase == 'playing') ...[
                      RepaintBoundary(child: _buildBoosterButtons(ui)),
                      SizedBox(height: 10.0 * ui),
                    ],

                    // Main Release Car Button (3D glossy Gold CTA button matching Image 2)
                    Transform.scale(
                      scale: releaseBounceScale,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTapDown: (_) => onRelease(),
                        child: Container(
                          width: leftColumnW,
                          height: 68.0 * ui,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: _releaseButtonGradient(nextToken),
                            ),
                            borderRadius: BorderRadius.circular(20.0 * ui),
                            border: Border.all(
                              color: const Color(0xFFFFF6C7),
                              width: 2.6 * ui,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFD18A10),
                                offset: Offset(0, 5.5 * ui),
                                blurRadius: 0,
                              ),
                              BoxShadow(
                                color: const Color(0x38000000),
                                offset: Offset(0, 9.0 * ui),
                                blurRadius: 12.0 * ui,
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(17.5 * ui),
                            child: Stack(
                              children: [
                                // .charge-fill
                                Positioned.fill(
                                  child: FractionallySizedBox(
                                    alignment: Alignment.centerLeft,
                                    widthFactor: chargeFactor,
                                    child: Container(
                                      color: const Color(0xFFFFF8D6)
                                          .withValues(alpha: 0.45),
                                    ),
                                  ),
                                ),
                                // Top glossy specular highlight bar (Image 2 style)
                                Positioned(
                                  top: 3.0 * ui,
                                  left: 12.0 * ui,
                                  right: 12.0 * ui,
                                  height: 15.0 * ui,
                                  child: IgnorePointer(
                                    child: Container(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(
                                          10.0 * ui,
                                        ),
                                        gradient: LinearGradient(
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                          colors: [
                                            Colors.white.withValues(
                                              alpha: 0.62,
                                            ),
                                            Colors.white.withValues(alpha: 0.0),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                // Button content
                                Padding(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 11.0 * ui,
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 40.0 * ui,
                                        height: 40.0 * ui,
                                        decoration: BoxDecoration(
                                          color: const Color(0xCCFFF9DF),
                                          borderRadius: BorderRadius.circular(
                                            12.0 * ui,
                                          ),
                                          border: Border.all(
                                            color: const Color(0xFFE5B532),
                                            width: 1.5 * ui,
                                          ),
                                        ),
                                        alignment: Alignment.center,
                                        child: GameSpriteIcon(
                                          _nextTokenIconAsset(nextToken),
                                          size: 26.0 * ui,
                                        ),
                                      ),
                                      SizedBox(width: 9.0 * ui),
                                      Expanded(
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              buttonLabel,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                color: ready
                                                    ? const Color(0xFF613A05)
                                                    : const Color(0xFF7D5822),
                                                fontSize: 17.5 * ui,
                                                fontWeight: FontWeight.w900,
                                                height: 1.08,
                                                letterSpacing: -0.3 * ui,
                                              ),
                                            ),
                                            SizedBox(height: 3.0 * ui),
                                            Text(
                                              buttonDetail,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                color: ready
                                                    ? const Color(0xFF7E510E)
                                                    : const Color(0xFF8F6B32),
                                                fontSize: 9.8 * ui,
                                                fontWeight: FontWeight.w900,
                                                height: 1.0,
                                                letterSpacing: 0.3 * ui,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      SizedBox(width: 6.0 * ui),
                                      Container(
                                        width: 38.0 * ui,
                                        height: 38.0 * ui,
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            begin: Alignment.topCenter,
                                            end: Alignment.bottomCenter,
                                            colors: ready
                                                ? const [
                                                    Color(0xFF7AD3FC),
                                                    Color(0xFF349CE8),
                                                  ]
                                                : const [
                                                    Color(0xFFB5C7D6),
                                                    Color(0xFF8EA5B8),
                                                  ],
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            12.0 * ui,
                                          ),
                                          border: Border.all(
                                            color: const Color(0xFFE6F6FF),
                                            width: 1.6 * ui,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: const Color(0xFF216CA8),
                                              offset: Offset(0, 2.5 * ui),
                                              blurRadius: 0,
                                            ),
                                          ],
                                        ),
                                        alignment: Alignment.center,
                                        child: CustomPaint(
                                          size: Size(19.0 * ui, 19.0 * ui),
                                          painter: _NorthEastArrowPainter(
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                    // .key-hint (<kbd>TAP</kbd> or tap anywhere)
                    Padding(
                      padding: EdgeInsets.only(left: 2.0 * ui, top: 8.0 * ui),
                      child: Row(
                        children: [
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 6.0 * ui,
                              vertical: 3.0 * ui,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF9DA9F),
                              borderRadius: BorderRadius.circular(6.0 * ui),
                              border: Border.all(
                                color: const Color(0xFFFFF1CC),
                                width: 1.0 * ui,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFA36B70),
                                  offset: Offset(0, 2.0 * ui),
                                  blurRadius: 0,
                                ),
                              ],
                            ),
                            child: Text(
                              'TAP',
                              style: TextStyle(
                                color: const Color(0xFF613D50),
                                fontSize: 10.0 * ui,
                                fontWeight: FontWeight.w900,
                                height: 1.1,
                                letterSpacing: 0.8 * ui,
                              ),
                            ),
                          ),
                          SizedBox(width: 8.0 * ui),
                          Flexible(
                            child: Text(
                              'or tap anywhere',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: const Color(0xFFFFF0DA),
                                fontSize: 11.5 * ui,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.2 * ui,
                                shadows: [
                                  Shadow(
                                    color: const Color(0xFF3C1E45),
                                    offset: Offset(0, 1.0 * ui),
                                    blurRadius: 3.0 * ui,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

            // Stage Clear Panel (centered above safeBottom with full mobile readability)
            if (isCleared)
              Positioned(
                left: safeLeft,
                right: safeRight,
                bottom: safeBottom,
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: 372.0 * ui),
                    child: _buildStageClearPanel(ui),
                  ),
                ),
              ),

            // Fail Panel (centered above safeBottom with full mobile readability)
            if (isFailed)
              Positioned(
                left: safeLeft,
                right: safeRight,
                bottom: safeBottom,
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: 372.0 * ui),
                    child: _buildFailPanel(ui, mergeWord),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  String _nextTokenSubtitle(CarModel token) {
    final roleLabel = switch (token.role) {
      CTCarRole.police => '🚓 ${_tr('role_police')}',
      CTCarRole.green => '🟢 ${_tr('role_green')}',
      CTCarRole.normal => _vehicleLabel(token.vehicleType),
    };
    return '${_tr('next_car_label')}: $roleLabel';
  }

  String _vehicleLabel(CTVehicleType type) {
    switch (type) {
      case CTVehicleType.mini:
        return 'MINI COMPACT';
      case CTVehicleType.car:
        return 'SEDAN';
      case CTVehicleType.van:
        return 'FAMILY VAN';
      case CTVehicleType.truck:
        return 'CARGO TRUCK';
      case CTVehicleType.bus:
        return 'CITY BUS';
    }
  }

  String _nextTokenIconAsset(CarModel? token) {
    if (token == null) return GameIcons.carMerge;
    switch (token.role) {
      case CTCarRole.police:
        return GameIcons.modePoliceChase;
      case CTCarRole.green:
        return GameIcons.carGreenExit;
      case CTCarRole.normal:
        return GameIcons.carMerge;
    }
  }

  List<Color> _releaseButtonGradient(CarModel? token) {
    if (token == null) {
      return const [Color(0xFFFFE77A), Color(0xFFF9B926)];
    }
    switch (token.role) {
      case CTCarRole.police:
        return const [Color(0xFF93E2FF), Color(0xFF47B3F5)];
      case CTCarRole.green:
        return const [Color(0xFF83F8C1), Color(0xFF34D98A)];
      case CTCarRole.normal:
        return const [Color(0xFFFFE77A), Color(0xFFF9B926)];
    }
  }

  Widget _buildModeStageHeaderButton(double ui) {
    final stg = state.stage;
    final stgId = stg?.id ?? state.stageId;
    final stgName = stg?.name ?? 'Stage $stgId';
    final isBoss = stg?.isBoss ?? false;
    final theme = ctThemeForStage(stgId);
    final modeTitle = switch (state.mode) {
      CTGameMode.campaign => '${_tr('stage_label')} $stgId/100',
      CTGameMode.endless => _tr('mode_endless'),
      CTGameMode.timeAttack => _tr('mode_timeAttack'),
      CTGameMode.rushHour => _tr('mode_rushHour'),
      CTGameMode.bossRush =>
        '${_tr('mode_bossRush')} (${state.bossRushIndex + 1}/10)',
      CTGameMode.policeChase => _tr('mode_policeChase'),
    };
    final subTitle =
        state.mode == CTGameMode.campaign || state.mode == CTGameMode.bossRush
        ? (isBoss ? '👑 $stgName' : '${theme.name} · $stgName')
        : _tr('modes_and_stages');

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onToggleSelector,
      child: Container(
        constraints: BoxConstraints(minHeight: 48.0 * ui),
        padding: EdgeInsets.symmetric(
          horizontal: 10.0 * ui,
          vertical: 6.0 * ui,
        ),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFAF8F0), Color(0xFFEFEAD6)],
          ),
          borderRadius: BorderRadius.circular(16.0 * ui),
          border: Border.all(
            color: isBoss ? const Color(0xFFF5A623) : const Color(0xFF8CC5F2),
            width: 2.2 * ui,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF558EC2),
              offset: Offset(0, 4.0 * ui),
              blurRadius: 0,
            ),
            BoxShadow(
              color: const Color(0x2E000000),
              offset: Offset(0, 6.0 * ui),
              blurRadius: 8.0 * ui,
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 32.0 * ui,
              height: 32.0 * ui,
              decoration: BoxDecoration(
                color: const Color(0xFFE2F0FB),
                borderRadius: BorderRadius.circular(10.0 * ui),
                border: Border.all(
                  color: const Color(0xFFA7D2F4),
                  width: 1.4 * ui,
                ),
              ),
              alignment: Alignment.center,
              child: GameSpriteIcon(
                GameIcons.forMode(state.mode),
                size: 22.0 * ui,
              ),
            ),
            SizedBox(width: 8.0 * ui),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    modeTitle.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: const Color(0xFF1D4D7A),
                      fontSize: 12.0 * ui,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.4 * ui,
                    ),
                  ),
                  SizedBox(height: 1.5 * ui),
                  Text(
                    subTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: const Color(0xFF637F9A),
                      fontSize: 10.2 * ui,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: 4.0 * ui),
            Icon(
              Icons.grid_view_rounded,
              size: 17.0 * ui,
              color: const Color(0xFF34689A),
            ),
          ],
        ),
      ),
    );
  }

  /// Unified 3D Score & Stage Progress Card combining Clean Merges and Mode Progress
  /// in the Creamy-Ivory & Sky-Blue style of Image 2.
  Widget _buildCleanMergesBadge(double ui, bool hotFlow) {
    String? subLabel;
    String? subValue;
    Color subAccent = const Color(0xFF10B981);
    double? progress;

    if (state.useStagePaths) {
      switch (state.mode) {
        case CTGameMode.campaign:
        case CTGameMode.bossRush:
          subLabel = _tr('queue_left');
          subValue = '${state.queue.length}';
          subAccent = const Color(0xFF10B981);
          final total = math.max(1, state.initialQueueCount);
          progress = ((total - state.queue.length) / total).clamp(0.0, 1.0);
          break;
        case CTGameMode.timeAttack:
          subLabel = _tr('time_left');
          subValue = '${state.timeRemaining.toStringAsFixed(1)}s';
          subAccent = state.timeRemaining < 10.0
              ? const Color(0xFFEF4444)
              : const Color(0xFF0284C7);
          progress = (state.timeRemaining / 60.0).clamp(0.0, 1.0);
          break;
        case CTGameMode.rushHour:
          subLabel = _tr('wave_label');
          subValue = '#${state.waveNumber}';
          subAccent = const Color(0xFFF59E0B);
          progress = ((state.cleanMerges % 8) / 8.0).clamp(0.0, 1.0);
          break;
        case CTGameMode.policeChase:
          subLabel = _tr('jam_cleared');
          subValue = '${state.convertedCleared}';
          subAccent = const Color(0xFF2563EB);
          break;
        case CTGameMode.endless:
          subLabel = 'BEST';
          subValue = '${math.max(bestEndlessScore, state.cleanMerges)}';
          subAccent = const Color(0xFFF5A623);
          break;
      }
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.0 * ui, vertical: 8.0 * ui),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFAF8F0), Color(0xFFEFEAD6)],
        ),
        borderRadius: BorderRadius.circular(17.0 * ui),
        border: Border.all(
          color: hotFlow ? const Color(0xFFF5A623) : const Color(0xFF8CC5F2),
          width: 2.2 * ui,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF558EC2),
            offset: Offset(0, 4.0 * ui),
            blurRadius: 0,
          ),
          BoxShadow(
            color: const Color(0x26000000),
            offset: Offset(0, 6.0 * ui),
            blurRadius: 8.0 * ui,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 32.0 * ui,
                height: 32.0 * ui,
                decoration: BoxDecoration(
                  color: const Color(0xFFE2F0FB),
                  borderRadius: BorderRadius.circular(10.0 * ui),
                  border: Border.all(
                    color: hotFlow
                        ? const Color(0xFFF5A623)
                        : const Color(0xFFA7D2F4),
                    width: 1.3 * ui,
                  ),
                ),
                alignment: Alignment.center,
                child: GameSpriteIcon(
                  hotFlow ? GameIcons.streakFire : GameIcons.carMerge,
                  size: 22.0 * ui,
                ),
              ),
              SizedBox(width: 7.0 * ui),
              Expanded(
                child: Text(
                  _tr('clean_merges'),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: const Color(0xFF5E7893),
                    fontSize: 9.5 * ui,
                    fontWeight: FontWeight.w900,
                    height: 1.18,
                    letterSpacing: 0.3 * ui,
                  ),
                ),
              ),
              SizedBox(width: 4.0 * ui),
              Text(
                '${state.cleanMerges}',
                style: TextStyle(
                  color: const Color(0xFFF5A623),
                  fontSize: 22.0 * ui,
                  fontWeight: FontWeight.w900,
                  height: 1.0,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          if (subLabel != null && subValue != null) ...[
            SizedBox(height: 6.0 * ui),
            Container(height: 1.2 * ui, color: const Color(0xFFE2DEC9)),
            SizedBox(height: 6.0 * ui),
            Row(
              children: [
                Expanded(
                  child: Text(
                    subLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: const Color(0xFF6B829A),
                      fontSize: 9.5 * ui,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.3 * ui,
                    ),
                  ),
                ),
                SizedBox(width: 4.0 * ui),
                Text(
                  subValue,
                  style: TextStyle(
                    color: subAccent,
                    fontSize: 15.0 * ui,
                    fontWeight: FontWeight.w900,
                    height: 1.0,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
            if (progress != null) ...[
              SizedBox(height: 5.0 * ui),
              ClipRRect(
                borderRadius: BorderRadius.circular(5.0 * ui),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 5.5 * ui,
                  backgroundColor: const Color(0xFFDFECFA),
                  valueColor: AlwaysStoppedAnimation<Color>(subAccent),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildSoundButton(double ui) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onToggleSound,
      child: Container(
        constraints: BoxConstraints(minWidth: 58.0 * ui, minHeight: 48.0 * ui),
        padding: EdgeInsets.symmetric(
          horizontal: 10.0 * ui,
          vertical: 5.0 * ui,
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: muted
                ? const [Color(0xFFE8EEF5), Color(0xFFD5E1ED)]
                : const [Color(0xFFE6F4FE), Color(0xFFCDE8FC)],
          ),
          borderRadius: BorderRadius.circular(16.0 * ui),
          border: Border.all(color: const Color(0xFF8CC5F2), width: 2.2 * ui),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF558EC2),
              offset: Offset(0, 4.0 * ui),
              blurRadius: 0,
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            GameSpriteIcon(
              muted ? GameIcons.soundOff : GameIcons.soundOn,
              size: 19.0 * ui,
            ),
            SizedBox(height: 2.0 * ui),
            Text(
              muted ? _tr('muted') : _tr('sound_on'),
              style: TextStyle(
                color: muted
                    ? const Color(0xFF6B829A)
                    : const Color(0xFF1D4D7A),
                fontSize: 9.0 * ui,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.4 * ui,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLanguageButton(double ui) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onCycleLanguage,
      child: Container(
        constraints: BoxConstraints(minWidth: 56.0 * ui, minHeight: 48.0 * ui),
        padding: EdgeInsets.symmetric(
          horizontal: 10.0 * ui,
          vertical: 6.0 * ui,
        ),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFAF8F0), Color(0xFFEFEAD6)],
          ),
          borderRadius: BorderRadius.circular(16.0 * ui),
          border: Border.all(color: const Color(0xFF8CC5F2), width: 2.2 * ui),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF558EC2),
              offset: Offset(0, 4.0 * ui),
              blurRadius: 0,
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            GameSpriteIcon(GameIcons.language, size: 18.0 * ui),
            SizedBox(width: 4.0 * ui),
            Text(
              lang.toUpperCase(),
              style: TextStyle(
                color: const Color(0xFF1D4D7A),
                fontSize: 12.0 * ui,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.6 * ui,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStageInfoBanner(double ui, CarModel? nextToken) {
    final stg = state.stage;
    String? bannerText;
    Color borderCol = const Color(0xFF8CC5F2);
    String iconAsset = GameIcons.carMerge;

    if (nextToken?.role == CTCarRole.police) {
      bannerText = _tr('police_convert_hint');
      borderCol = const Color(0xFF38BDF8);
      iconAsset = GameIcons.modePoliceChase;
    } else if (nextToken?.role == CTCarRole.green) {
      bannerText = _tr('green_exit_hint');
      borderCol = const Color(0xFF34D399);
      iconAsset = GameIcons.carGreenExit;
    } else if (stg?.hint != null && stg!.hint!.isNotEmpty) {
      bannerText = stg.hint!;
      if (stg.isBoss) {
        borderCol = const Color(0xFFF5A623);
        iconAsset = GameIcons.modeBossRush;
      }
    }

    if (bannerText == null) return const SizedBox.shrink();

    return IgnorePointer(
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: 10.0 * ui,
          vertical: 8.0 * ui,
        ),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFEDF6FD), Color(0xFFE0EFFB)],
          ),
          borderRadius: BorderRadius.circular(15.0 * ui),
          border: Border.all(color: borderCol, width: 2.0 * ui),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF558EC2),
              offset: Offset(0, 3.5 * ui),
              blurRadius: 0,
            ),
          ],
        ),
        child: Row(
          children: [
            GameSpriteIcon(iconAsset, size: 20.0 * ui),
            SizedBox(width: 6.0 * ui),
            Expanded(
              child: Text(
                bannerText,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: const Color(0xFF1D4D7A),
                  fontSize: 10.5 * ui,
                  fontWeight: FontWeight.w800,
                  height: 1.22,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBoosterButtons(double ui) {
    final slowActive = state.slowMoRemaining > 0;
    final canSlow = state.slowMoCharges > 0 && !slowActive;
    final canZap =
        state.zapCharges > 0 && state.cars.any((c) => c.path == 'ring');

    return Row(
      children: [
        // Slow-Mo Booster (Image 2 Pastel Sky-Blue sub-card with golden badge)
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: canSlow ? onSlowMo : null,
            child: Container(
              constraints: BoxConstraints(minHeight: 46.0 * ui),
              padding: EdgeInsets.symmetric(
                horizontal: 8.0 * ui,
                vertical: 7.0 * ui,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: slowActive
                      ? const [Color(0xFF7AD3FC), Color(0xFF349CE8)]
                      : canSlow
                      ? const [Color(0xFFEDF6FD), Color(0xFFDFEFFC)]
                      : const [Color(0xFFF3F1E8), Color(0xFFE9E6D8)],
                ),
                borderRadius: BorderRadius.circular(15.0 * ui),
                border: Border.all(
                  color: (canSlow || slowActive)
                      ? const Color(0xFF8CC5F2)
                      : const Color(0xFFD5D1C0),
                  width: 2.0 * ui,
                ),
                boxShadow: [
                  BoxShadow(
                    color: (canSlow || slowActive)
                        ? const Color(0xFF558EC2)
                        : const Color(0xFFB8B3A2),
                    offset: Offset(0, 3.5 * ui),
                    blurRadius: 0,
                  ),
                ],
              ),
              child: Row(
                children: [
                  GameSpriteIcon(GameIcons.boosterSlowMo, size: 20.0 * ui),
                  SizedBox(width: 4.0 * ui),
                  Expanded(
                    child: Text(
                      slowActive
                          ? '${state.slowMoRemaining.toStringAsFixed(1)}s'
                          : _tr('booster_slowmo'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: slowActive
                            ? Colors.white
                            : canSlow
                            ? const Color(0xFF1D4D7A)
                            : const Color(0xFF8594A6),
                        fontSize: 11.0 * ui,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  SizedBox(width: 3.0 * ui),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 6.0 * ui,
                      vertical: 2.0 * ui,
                    ),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0xFFFFEE99), Color(0xFFF7D259)],
                      ),
                      borderRadius: BorderRadius.circular(8.0 * ui),
                      border: Border.all(
                        color: const Color(0xFFE5B532),
                        width: 1.0 * ui,
                      ),
                    ),
                    child: Text(
                      'x${state.slowMoCharges}',
                      style: TextStyle(
                        color: const Color(0xFF6B470A),
                        fontSize: 10.5 * ui,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        SizedBox(width: 8.0 * ui),
        // Zap Clear Booster (Image 2 Pastel Sky-Blue sub-card with golden badge)
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: canZap ? onZapClear : null,
            child: Container(
              constraints: BoxConstraints(minHeight: 46.0 * ui),
              padding: EdgeInsets.symmetric(
                horizontal: 8.0 * ui,
                vertical: 7.0 * ui,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: canZap
                      ? const [Color(0xFFEDF6FD), Color(0xFFDFEFFC)]
                      : const [Color(0xFFF3F1E8), Color(0xFFE9E6D8)],
                ),
                borderRadius: BorderRadius.circular(15.0 * ui),
                border: Border.all(
                  color: canZap
                      ? const Color(0xFF8CC5F2)
                      : const Color(0xFFD5D1C0),
                  width: 2.0 * ui,
                ),
                boxShadow: [
                  BoxShadow(
                    color: canZap
                        ? const Color(0xFF558EC2)
                        : const Color(0xFFB8B3A2),
                    offset: Offset(0, 3.5 * ui),
                    blurRadius: 0,
                  ),
                ],
              ),
              child: Row(
                children: [
                  GameSpriteIcon(GameIcons.boosterZap, size: 20.0 * ui),
                  SizedBox(width: 3.0 * ui),
                  Expanded(
                    child: Text(
                      _tr('booster_zap'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: canZap
                            ? const Color(0xFF1D4D7A)
                            : const Color(0xFF8594A6),
                        fontSize: 11.0 * ui,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  SizedBox(width: 3.0 * ui),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 6.0 * ui,
                      vertical: 2.0 * ui,
                    ),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0xFFFFEE99), Color(0xFFF7D259)],
                      ),
                      borderRadius: BorderRadius.circular(8.0 * ui),
                      border: Border.all(
                        color: const Color(0xFFE5B532),
                        width: 1.0 * ui,
                      ),
                    ),
                    child: Text(
                      'x${state.zapCharges}',
                      style: TextStyle(
                        color: const Color(0xFF6B470A),
                        fontSize: 10.5 * ui,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Stage Clear / Victory Modal modeled 100% after Image 2 (`VICTORY!` screen).
  Widget _buildStageClearPanel(double ui) {
    final stg = state.stage;
    final stgId = stg?.id ?? state.stageId;
    final stgName = stg?.name ?? 'Stage $stgId';
    final theme = ctThemeForStage(stgId);
    final isFinalVictory =
        (state.mode == CTGameMode.campaign && stgId >= kCTStages.length) ||
        (state.mode == CTGameMode.bossRush && state.bossRushIndex >= 9);

    return _buildImage2ResultModal(
      ui: ui,
      ribbonTitle: isFinalVictory
          ? 'VICTORY!'
          : _tr('stage_cleared').toUpperCase(),
      ribbonColors: const [Color(0xFF82D8FA), Color(0xFF3EAEEC)],
      ribbonBorder: const Color(0xFFD9F3FF),
      ribbonShadow: const Color(0xFF2577AE),
      stageSubHeader:
          '${_tr('stage_label')} $stgId · ${theme.name.toUpperCase()}',
      scoreLabel: _tr('clean_merges').toUpperCase(),
      scoreValue: '${state.cleanMerges}',
      leftStatLabel: _tr('stage_label').toUpperCase(),
      leftStatValue: '#$stgId · $stgName',
      rightStatLabel: 'CHUỖI THẮNG',
      rightStatValue: 'x${math.max(1, streak)}',
      statusSummary: isFinalVictory
          ? _tr('victory_sub')
          : _tr('stage_cleared_sub'),
      primaryCtaLabel: (isFinalVictory ? _tr('play_again') : _tr('next_stage'))
          .toUpperCase(),
      onPrimaryCta: onNextStage,
      showLevelSelect: true,
    );
  }

  /// Fail / Traffic Jam Modal modeled 100% after Image 2.
  Widget _buildFailPanel(double ui, String mergeWord) {
    final isTimeUp =
        state.mode == CTGameMode.timeAttack && state.timeRemaining <= 0;
    final stg = state.stage;
    final stgId = stg?.id ?? state.stageId;
    final theme = ctThemeForStage(stgId);

    return _buildImage2ResultModal(
      ui: ui,
      ribbonTitle: (isTimeUp ? _tr('time_up_title') : _tr('traffic_jam'))
          .toUpperCase(),
      ribbonColors: const [Color(0xFFFFAD66), Color(0xFFEB663B)],
      ribbonBorder: const Color(0xFFFFE5CC),
      ribbonShadow: const Color(0xFFA83B19),
      stageSubHeader:
          '${_tr('stage_label')} $stgId · ${theme.name.toUpperCase()}',
      scoreLabel: mergeWord.toUpperCase(),
      scoreValue: '${state.cleanMerges}',
      leftStatLabel: 'TIẾN ĐỘ CHIẾN DỊCH',
      leftStatValue: '${clearedStages.length} / 100',
      rightStatLabel: 'KỶ LỤC ENDLESS',
      rightStatValue: '${math.max(bestEndlessScore, state.cleanMerges)}',
      statusSummary: isTimeUp ? _tr('time_up_sub') : _tr('traffic_jam_sub'),
      primaryCtaLabel: _tr('try_again').toUpperCase(),
      onPrimaryCta: onRetry,
      showLevelSelect: state.useStagePaths,
    );
  }

  /// Shared AAA Casual 3D Modal matching Image 2 (`VICTORY!` screen):
  /// - Sky-Blue 3D outer bezel (`#BDE3FF` -> `#8DC6F5`)
  /// - Warm Creamy-Ivory inner card (`#FCFBF5` -> `#F4F0E1`)
  /// - Floating 3D top ribbon banner straddling the top bezel
  /// - Huge golden score (`#F5A623`), `#E5E1D0` dividers, 2-column stats
  /// - 2 Pastel Sky-Blue sub-cards (`Squad 24` / `Gear 0` style)
  /// - Giant Glossy 3D Gold primary CTA button + clean blue `LEVEL SELECT` link
  Widget _buildImage2ResultModal({
    required double ui,
    required String ribbonTitle,
    required List<Color> ribbonColors,
    required Color ribbonBorder,
    required Color ribbonShadow,
    required String stageSubHeader,
    required String scoreLabel,
    required String scoreValue,
    required String leftStatLabel,
    required String leftStatValue,
    required String rightStatLabel,
    required String rightStatValue,
    required String statusSummary,
    required String primaryCtaLabel,
    required VoidCallback onPrimaryCta,
    required bool showLevelSelect,
  }) {
    return Padding(
      padding: EdgeInsets.only(top: 18.0 * ui),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          // Outer 3D Sky-Blue Bezel
          Container(
            padding: EdgeInsets.all(10.0 * ui),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFBDE3FF), Color(0xFF8DC6F5)],
              ),
              borderRadius: BorderRadius.circular(32.0 * ui),
              border: Border.all(
                color: const Color(0xFFE6F4FF),
                width: 2.5 * ui,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF5D99CC),
                  offset: Offset(0, 7.0 * ui),
                  blurRadius: 0,
                ),
                BoxShadow(
                  color: const Color(0x42000000),
                  offset: Offset(0, 12.0 * ui),
                  blurRadius: 20.0 * ui,
                ),
              ],
            ),
            // Inner Warm Creamy-Ivory Card
            child: Container(
              padding: EdgeInsets.fromLTRB(
                14.0 * ui,
                26.0 * ui,
                14.0 * ui,
                14.0 * ui,
              ),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFFCFBF5), Color(0xFFF4F0E1)],
                ),
                borderRadius: BorderRadius.circular(23.0 * ui),
                border: Border.all(
                  color: const Color(0xFFE2DEC9),
                  width: 1.5 * ui,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // LEVEL 1 · PALM COAST subtitle
                  Text(
                    stageSubHeader,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: const Color(0xFF7087A1),
                      fontSize: 11.5 * ui,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.0 * ui,
                    ),
                  ),
                  SizedBox(height: 5.0 * ui),
                  // TOTAL SCORE label
                  Text(
                    scoreLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: const Color(0xFF34689A),
                      fontSize: 13.0 * ui,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.6 * ui,
                    ),
                  ),
                  SizedBox(height: 2.0 * ui),
                  // Giant Golden Number (176 in Image 2)
                  Text(
                    scoreValue,
                    style: TextStyle(
                      color: const Color(0xFFF5A623),
                      fontSize: 42.0 * ui,
                      fontWeight: FontWeight.w900,
                      height: 1.0,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  SizedBox(height: 8.0 * ui),
                  Container(height: 1.2 * ui, color: const Color(0xFFE5E1D0)),
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 7.0 * ui),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            children: [
                              Text(
                                leftStatLabel,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: const Color(0xFF7A8FA6),
                                  fontSize: 9.5 * ui,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.4 * ui,
                                ),
                              ),
                              SizedBox(height: 2.0 * ui),
                              Text(
                                leftStatValue,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: const Color(0xFF34689A),
                                  fontSize: 13.5 * ui,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          width: 1.2 * ui,
                          height: 24.0 * ui,
                          color: const Color(0xFFE5E1D0),
                        ),
                        Expanded(
                          child: Column(
                            children: [
                              Text(
                                rightStatLabel,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: const Color(0xFF7A8FA6),
                                  fontSize: 9.5 * ui,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.4 * ui,
                                ),
                              ),
                              SizedBox(height: 2.0 * ui),
                              Text(
                                rightStatValue,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: const Color(0xFF34689A),
                                  fontSize: 13.5 * ui,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(height: 1.2 * ui, color: const Color(0xFFE5E1D0)),
                  SizedBox(height: 6.0 * ui),
                  Text(
                    statusSummary,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: const Color(0xFF34689A),
                      fontSize: 12.0 * ui,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: 8.0 * ui),
                  // 2 Pastel Sky-Blue Sub-Cards (matching Squad 24 & Gear 0 in Image 2)
                  Row(
                    children: [
                      Expanded(
                        child: _buildModalSubCard(
                          ui: ui,
                          iconAsset: GameIcons.boosterSlowMo,
                          title: _tr('booster_slowmo'),
                          subtitle: 'Trợ giúp làm chậm',
                          pillText: 'x${state.slowMoCharges}',
                        ),
                      ),
                      SizedBox(width: 8.0 * ui),
                      Expanded(
                        child: _buildModalSubCard(
                          ui: ui,
                          iconAsset: GameIcons.boosterZap,
                          title: _tr('booster_zap'),
                          subtitle: 'Trợ giúp dọn vòng',
                          pillText: 'x${state.zapCharges}',
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 11.0 * ui),
                  // Giant Glossy 3D Gold Primary CTA Button (NEXT LEVEL / TRY AGAIN)
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapDown: (_) => onPrimaryCta(),
                    child: Container(
                      height: 58.0 * ui,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0xFFFFE875), Color(0xFFF8BA2B)],
                        ),
                        borderRadius: BorderRadius.circular(18.0 * ui),
                        border: Border.all(
                          color: const Color(0xFFFFF6C7),
                          width: 2.5 * ui,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFD18A10),
                            offset: Offset(0, 5.0 * ui),
                            blurRadius: 0,
                          ),
                        ],
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Positioned(
                            top: 3.0 * ui,
                            left: 14.0 * ui,
                            right: 14.0 * ui,
                            height: 14.0 * ui,
                            child: IgnorePointer(
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(9.0 * ui),
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Colors.white.withValues(alpha: 0.65),
                                      Colors.white.withValues(alpha: 0.0),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Text(
                            primaryCtaLabel,
                            style: TextStyle(
                              color: const Color(0xFF613A05),
                              fontSize: 18.0 * ui,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.4 * ui,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (showLevelSelect) ...[
                    SizedBox(height: 8.0 * ui),
                    // Clean Blue LEVEL SELECT text link (matching Image 2)
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: onToggleSelector,
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 5.0 * ui),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            GameSpriteIcon(GameIcons.trophy, size: 17.0 * ui),
                            SizedBox(width: 6.0 * ui),
                            Flexible(
                              child: Text(
                                _tr('modes_and_stages').toUpperCase(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: const Color(0xFF34689A),
                                  fontSize: 13.0 * ui,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.5 * ui,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Floating 3D Top Ribbon Banner ("VICTORY!" in Image 2)
          Positioned(
            top: -16.0 * ui,
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: 24.0 * ui,
                vertical: 7.5 * ui,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: ribbonColors,
                ),
                borderRadius: BorderRadius.circular(18.0 * ui),
                border: Border.all(color: ribbonBorder, width: 2.5 * ui),
                boxShadow: [
                  BoxShadow(
                    color: ribbonShadow,
                    offset: Offset(0, 4.0 * ui),
                    blurRadius: 0,
                  ),
                  BoxShadow(
                    color: const Color(0x28000000),
                    offset: Offset(0, 6.0 * ui),
                    blurRadius: 8.0 * ui,
                  ),
                ],
              ),
              child: Text(
                ribbonTitle,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16.5 * ui,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.9 * ui,
                  shadows: [
                    Shadow(
                      color: ribbonShadow,
                      offset: Offset(0, 1.5 * ui),
                      blurRadius: 0,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModalSubCard({
    required double ui,
    required String iconAsset,
    required String title,
    required String subtitle,
    required String pillText,
  }) {
    return Container(
      padding: EdgeInsets.all(8.5 * ui),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFEDF6FD), Color(0xFFE2F0FB)],
        ),
        borderRadius: BorderRadius.circular(14.0 * ui),
        border: Border.all(color: const Color(0xFFA7D2F4), width: 1.6 * ui),
      ),
      child: Column(
        children: [
          Row(
            children: [
              GameSpriteIcon(iconAsset, size: 24.0 * ui),
              SizedBox(width: 6.0 * ui),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: const Color(0xFF1D4D7A),
                        fontSize: 11.5 * ui,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: const Color(0xFF637F9A),
                        fontSize: 9.0 * ui,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 6.0 * ui),
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(vertical: 3.5 * ui),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFFFEE99), Color(0xFFF7D259)],
              ),
              borderRadius: BorderRadius.circular(8.0 * ui),
              border: Border.all(
                color: const Color(0xFFE5B532),
                width: 1.1 * ui,
              ),
            ),
            child: Text(
              pillText,
              style: TextStyle(
                color: const Color(0xFF6B470A),
                fontSize: 10.5 * ui,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDriveMotto(double s) => _DriveMottoWidget(scale: s);

  Widget _buildRewardPopup(RewardPopupData r, Size stageSize, double ui) {
    final motion = TrafficMath.rewardMotion(r.age);
    if (!motion.visible) return const SizedBox.shrink();
    final pt = projectCar(r.carId, motion.height, stageSize);
    if (pt == null) return const SizedBox.shrink();

    final popWidth = 172.0 * ui;
    final popHeight = 40.0 * ui;
    final halfW = popWidth / 2.0 + 8.0 * ui;
    final clampedX = pt.dx.clamp(
      halfW,
      math.max(halfW, stageSize.width - halfW),
    );

    final label = r.customLabel ?? _tr('smooth_merge');
    final badge = r.customBadge ?? '+1';

    final op = motion.opacity.clamp(0.0, 1.0);
    return Positioned(
      left: clampedX - popWidth / 2.0,
      top: pt.dy - popHeight,
      width: popWidth,
      child: IgnorePointer(
        child: Transform.scale(
          scale: motion.scale * (0.85 + 0.15 * op),
          alignment: Alignment.bottomCenter,
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: 10.0 * ui,
              vertical: 7.0 * ui,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFFE7F5B8).withValues(alpha: op),
              borderRadius: BorderRadius.circular(16.0 * ui),
              border: Border.all(
                color: const Color(0xFF4F3154).withValues(alpha: op),
                width: 2.4 * ui,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: const Color(0xFF3C5C3C).withValues(alpha: op),
                      fontSize: 13.5 * ui,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3 * ui,
                    ),
                  ),
                ),
                SizedBox(width: 6.0 * ui),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 6.0 * ui,
                    vertical: 2.5 * ui,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFB9DC8C).withValues(alpha: op),
                    borderRadius: BorderRadius.circular(7.0 * ui),
                  ),
                  child: Text(
                    badge,
                    style: TextStyle(
                      color: const Color(0xFF3C5C3C).withValues(alpha: op),
                      fontSize: 12.5 * ui,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DriveMottoWidget extends StatefulWidget {
  final double scale;

  const _DriveMottoWidget({required this.scale});

  @override
  State<_DriveMottoWidget> createState() => _DriveMottoWidgetState();
}

class _DriveMottoWidgetState extends State<_DriveMottoWidget> {
  late TextSpan _strokeSpan;
  late TextSpan _fillSpan;

  @override
  void initState() {
    super.initState();
    _rebuildSpans();
  }

  @override
  void didUpdateWidget(covariant _DriveMottoWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scale != widget.scale) {
      _rebuildSpans();
    }
  }

  void _rebuildSpans() {
    final s = widget.scale;
    final fontSize = 34.0 * s;
    const strokeColor = Color(0xFF432A49);
    final strokeWidth = 7.5 * s;

    TextSpan buildSpan({required bool isStroke}) {
      Paint? strokePaint;
      if (isStroke) {
        strokePaint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeJoin = StrokeJoin.round
          ..strokeCap = StrokeCap.round
          ..color = strokeColor;
      }

      TextStyle partStyle(Color fillColor, {bool italic = true}) {
        return TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w900,
          fontStyle: italic ? FontStyle.italic : FontStyle.normal,
          letterSpacing: -1.0 * s,
          height: 1.15,
          foreground: isStroke ? strokePaint : null,
          color: isStroke ? null : fillColor,
          shadows: isStroke
              ? [
                  Shadow(
                    color: strokeColor,
                    offset: Offset(0, 4.0 * s),
                    blurRadius: 0,
                  ),
                ]
              : null,
        );
      }

      return TextSpan(
        children: [
          TextSpan(text: 'Plan ', style: partStyle(const Color(0xFFFFF7DF))),
          TextSpan(
            text: '\u00B7',
            style: partStyle(const Color(0xFFDCB4E9), italic: false),
          ),
          TextSpan(text: ' Tap ', style: partStyle(const Color(0xFFFFF7DF))),
          TextSpan(
            text: '\u00B7',
            style: partStyle(const Color(0xFFDCB4E9), italic: false),
          ),
          TextSpan(text: ' Drive', style: partStyle(const Color(0xFFFFCF36))),
        ],
      );
    }

    _strokeSpan = buildSpan(isStroke: true);
    _fillSpan = buildSpan(isStroke: false);
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.scale;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Tilted yellow underline bar (.drive-motto:after)
        Positioned(
          left: 0,
          right: 0,
          bottom: -9.0 * s,
          child: Transform.rotate(
            angle: -3.0 * math.pi / 180.0,
            child: Container(
              height: 6.0 * s,
              decoration: BoxDecoration(
                color: const Color(0xFFFFCE35),
                borderRadius: BorderRadius.circular(6.0 * s),
                border: Border.all(
                  color: const Color(0xFF7A4550),
                  width: 1.0 * s,
                ),
              ),
            ),
          ),
        ),
        // Stroked + filled RichText with cached Paint/TextSpan instances
        Stack(
          children: [
            RichText(text: _strokeSpan),
            RichText(text: _fillSpan),
          ],
        ),
      ],
    );
  }
}

class _StrokedText extends StatefulWidget {
  final String text;
  final double fontSize;
  final FontWeight fontWeight;
  final double height;
  final double letterSpacing;
  final Color fillColor;
  final Color strokeColor;
  final double strokeWidth;
  final Offset shadowOffset;

  const _StrokedText({
    required this.text,
    required this.fontSize,
    required this.fontWeight,
    required this.height,
    required this.letterSpacing,
    required this.fillColor,
    required this.strokeColor,
    required this.strokeWidth,
    required this.shadowOffset,
  });

  @override
  State<_StrokedText> createState() => _StrokedTextState();
}

class _StrokedTextState extends State<_StrokedText> {
  late TextStyle _strokeStyle;
  late TextStyle _fillStyle;

  @override
  void initState() {
    super.initState();
    _rebuildStyles();
  }

  @override
  void didUpdateWidget(covariant _StrokedText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.fontSize != widget.fontSize ||
        oldWidget.fontWeight != widget.fontWeight ||
        oldWidget.height != widget.height ||
        oldWidget.letterSpacing != widget.letterSpacing ||
        oldWidget.fillColor != widget.fillColor ||
        oldWidget.strokeColor != widget.strokeColor ||
        oldWidget.strokeWidth != widget.strokeWidth ||
        oldWidget.shadowOffset != widget.shadowOffset) {
      _rebuildStyles();
    }
  }

  void _rebuildStyles() {
    _strokeStyle = TextStyle(
      fontSize: widget.fontSize,
      fontWeight: widget.fontWeight,
      height: widget.height,
      letterSpacing: widget.letterSpacing,
      foreground: Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = widget.strokeWidth
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round
        ..color = widget.strokeColor,
      shadows: [
        Shadow(
          color: widget.strokeColor,
          offset: widget.shadowOffset,
          blurRadius: 0,
        ),
      ],
    );
    _fillStyle = TextStyle(
      fontSize: widget.fontSize,
      fontWeight: widget.fontWeight,
      height: widget.height,
      letterSpacing: widget.letterSpacing,
      color: widget.fillColor,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Text(widget.text, style: _strokeStyle),
        Text(widget.text, style: _fillStyle),
      ],
    );
  }
}

/// Matches the SVG in .button-arrow:
/// `<svg viewBox="0 0 24 24"><path d="m6 18 12-12M6 6h12v12" stroke-width="2.6"/></svg>`
class _NorthEastArrowPainter extends CustomPainter {
  final Color color;
  const _NorthEastArrowPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / 24.0;
    final sy = size.height / 24.0;
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6 * sx
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path()
      ..moveTo(6 * sx, 18 * sy)
      ..lineTo(18 * sx, 6 * sy)
      ..moveTo(6 * sx, 6 * sy)
      ..lineTo(18 * sx, 6 * sy)
      ..lineTo(18 * sx, 18 * sy);
    canvas.drawPath(path, p);
  }

  @override
  bool shouldRepaint(covariant _NorthEastArrowPainter oldDelegate) =>
      oldDelegate.color != color;
}
