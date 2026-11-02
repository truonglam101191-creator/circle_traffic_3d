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

            // Left HUD Badges: Clean Merges + Mode/Queue Progress
            Positioned(
              left: safeLeft,
              top: topSubRowY,
              width: math.min(stageW * 0.42, 162.0 * ui),
              child: RepaintBoundary(
                child: IgnorePointer(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Transform.scale(
                        scale: badgeBounceScale,
                        child: _buildCleanMergesBadge(ui, hotFlow),
                      ),
                      if (state.useStagePaths) ...[
                        SizedBox(height: 8.0 * ui),
                        _buildSecondaryModeBadge(ui),
                      ],
                    ],
                  ),
                ),
              ),
            ),

            // Right Stage Hint / Next Special Car Banner
            if (state.useStagePaths && phase == 'playing' && !isCrashed)
              Positioned(
                right: safeRight,
                top: topSubRowY,
                width: math.min(stageW * 0.44, 174.0 * ui),
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

                    // Main Release Car Button (large, comfortable thumb target)
                    Transform.scale(
                      scale: releaseBounceScale,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTapDown: (_) => onRelease(),
                        child: Container(
                          width: leftColumnW,
                          height: 68.0 * ui,
                          decoration: BoxDecoration(
                            color: _releaseButtonColor(nextToken),
                            borderRadius: BorderRadius.circular(20.0 * ui),
                            border: Border.all(
                              color: const Color(0xFFFFF0B7),
                              width: 3.0 * ui,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF54314F),
                                offset: Offset(0, 5.0 * ui),
                                blurRadius: 0,
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(17.0 * ui),
                            child: Stack(
                              children: [
                                // .charge-fill
                                Positioned.fill(
                                  child: FractionallySizedBox(
                                    alignment: Alignment.centerLeft,
                                    widthFactor: chargeFactor,
                                    child: Container(
                                      color: const Color(0xFFFFF0A0)
                                          .withValues(alpha: 0.64),
                                    ),
                                  ),
                                ),
                                // Button content
                                Padding(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 14.0 * ui,
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
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
                                                    ? const Color(0xFF432A43)
                                                    : const Color(0xFF805954),
                                                fontSize: 18.0 * ui,
                                                fontWeight: FontWeight.w900,
                                                height: 1.1,
                                                letterSpacing: -0.4 * ui,
                                              ),
                                            ),
                                            SizedBox(height: 4.0 * ui),
                                            Text(
                                              buttonDetail,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                color: ready
                                                    ? const Color(0xFF5A3B2E)
                                                    : const Color(0xFF8C6860),
                                                fontSize: 10.5 * ui,
                                                fontWeight: FontWeight.w900,
                                                height: 1.0,
                                                letterSpacing: 0.4 * ui,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      SizedBox(width: 8.0 * ui),
                                      Container(
                                        width: 40.0 * ui,
                                        height: 40.0 * ui,
                                        decoration: BoxDecoration(
                                          color: ready
                                              ? const Color(0xFFAA75C8)
                                              : const Color(0xFFB3959B),
                                          borderRadius: BorderRadius.circular(
                                            13.0 * ui,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: const Color(0xFF77475F),
                                              offset: Offset(0, 2.5 * ui),
                                              blurRadius: 0,
                                            ),
                                          ],
                                        ),
                                        alignment: Alignment.center,
                                        child: CustomPaint(
                                          size: Size(22.0 * ui, 22.0 * ui),
                                          painter: _NorthEastArrowPainter(
                                            color: const Color(0xFFFFF5DD),
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

  Color _releaseButtonColor(CarModel? token) {
    if (token == null) return const Color(0xFFFFC83E);
    switch (token.role) {
      case CTCarRole.police:
        return const Color(0xFF7DD3FC);
      case CTCarRole.green:
        return const Color(0xFF52FFA8);
      case CTCarRole.normal:
        return const Color(0xFFFFC83E);
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
          color: const Color(0xEB432C4D),
          borderRadius: BorderRadius.circular(16.0 * ui),
          border: Border.all(
            color: isBoss ? const Color(0xFFFFD34B) : const Color(0xFFFFF1CE),
            width: 2.2 * ui,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0x6539243E),
              offset: Offset(0, 4.0 * ui),
              blurRadius: 0,
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 32.0 * ui,
              height: 32.0 * ui,
              decoration: BoxDecoration(
                color: theme.accent,
                borderRadius: BorderRadius.circular(10.0 * ui),
              ),
              alignment: Alignment.center,
              child: Icon(
                _modeIcon(state.mode),
                size: 18.0 * ui,
                color: const Color(0xFF2B1B30),
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
                      color: const Color(0xFFFFD34B),
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
                      color: const Color(0xFFFFF0D7),
                      fontSize: 10.5 * ui,
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
              color: const Color(0xFFFFF1CE),
            ),
          ],
        ),
      ),
    );
  }

  IconData _modeIcon(CTGameMode mode) {
    switch (mode) {
      case CTGameMode.campaign:
        return Icons.map_rounded;
      case CTGameMode.endless:
        return Icons.all_inclusive_rounded;
      case CTGameMode.timeAttack:
        return Icons.timer_rounded;
      case CTGameMode.rushHour:
        return Icons.speed_rounded;
      case CTGameMode.bossRush:
        return Icons.workspace_premium_rounded;
      case CTGameMode.policeChase:
        return Icons.local_police_rounded;
    }
  }

  Widget _buildCleanMergesBadge(double ui, bool hotFlow) {
    return Container(
      constraints: BoxConstraints(minHeight: 50.0 * ui),
      padding: EdgeInsets.symmetric(horizontal: 10.0 * ui, vertical: 7.0 * ui),
      decoration: BoxDecoration(
        color: const Color(0xEB432C4D),
        borderRadius: BorderRadius.circular(16.0 * ui),
        border: Border.all(color: const Color(0xFFFFF1CE), width: 2.2 * ui),
        boxShadow: [
          BoxShadow(
            color: const Color(0x6539243E),
            offset: Offset(0, 4.0 * ui),
            blurRadius: 0,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 30.0 * ui,
            height: 32.0 * ui,
            decoration: BoxDecoration(
              color: hotFlow
                  ? const Color(0xFFFFCD40)
                  : const Color(0xFFAA75C7),
              borderRadius: BorderRadius.circular(9.0 * ui),
            ),
            alignment: Alignment.center,
            child: CustomPaint(
              size: Size(22.0 * ui, 22.0 * ui),
              painter: _CarBadgeIconPainter(
                color: hotFlow
                    ? const Color(0xFF69414E)
                    : const Color(0xFFFFF5DC),
              ),
            ),
          ),
          SizedBox(width: 7.0 * ui),
          Expanded(
            child: Text(
              _tr('clean_merges'),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: const Color(0xFFFFF0D7),
                fontSize: 9.5 * ui,
                fontWeight: FontWeight.w900,
                height: 1.2,
                letterSpacing: 0.6 * ui,
              ),
            ),
          ),
          SizedBox(width: 4.0 * ui),
          Text(
            '${state.cleanMerges}',
            style: TextStyle(
              color: const Color(0xFFFFD34B),
              fontSize: 22.0 * ui,
              fontWeight: FontWeight.w900,
              height: 1.0,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSecondaryModeBadge(double ui) {
    String label;
    String valueText;
    Color accentColor;
    double? progress;

    switch (state.mode) {
      case CTGameMode.campaign:
      case CTGameMode.bossRush:
        label = _tr('queue_left');
        valueText = '${state.queue.length}';
        accentColor = const Color(0xFF52FFA8);
        final total = math.max(1, state.initialQueueCount);
        progress = ((total - state.queue.length) / total).clamp(0.0, 1.0);
        break;
      case CTGameMode.timeAttack:
        label = _tr('time_left');
        valueText = '${state.timeRemaining.toStringAsFixed(1)}s';
        accentColor = state.timeRemaining < 10.0
            ? const Color(0xFFFF6B8B)
            : const Color(0xFF38BDF8);
        progress = (state.timeRemaining / 60.0).clamp(0.0, 1.0);
        break;
      case CTGameMode.rushHour:
        label = _tr('wave_label');
        valueText = '#${state.waveNumber}';
        accentColor = const Color(0xFFFF9F43);
        progress = ((state.cleanMerges % 8) / 8.0).clamp(0.0, 1.0);
        break;
      case CTGameMode.policeChase:
        label = _tr('jam_cleared');
        valueText = '${state.convertedCleared}';
        accentColor = const Color(0xFF7DD3FC);
        break;
      case CTGameMode.endless:
        label = 'BEST';
        valueText = '${math.max(bestEndlessScore, state.cleanMerges)}';
        accentColor = const Color(0xFFFFD34B);
        break;
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.0 * ui, vertical: 7.0 * ui),
      decoration: BoxDecoration(
        color: const Color(0xE03A2444),
        borderRadius: BorderRadius.circular(14.0 * ui),
        border: Border.all(color: const Color(0xFFFFEAC4), width: 1.8 * ui),
        boxShadow: [
          BoxShadow(
            color: const Color(0x55291830),
            offset: Offset(0, 3.0 * ui),
            blurRadius: 0,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: const Color(0xFFE9D2F4),
                    fontSize: 9.5 * ui,
                    fontWeight: FontWeight.w900,
                    height: 1.2,
                    letterSpacing: 0.6 * ui,
                  ),
                ),
              ),
              SizedBox(width: 4.0 * ui),
              Text(
                valueText,
                style: TextStyle(
                  color: accentColor,
                  fontSize: 18.0 * ui,
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
              borderRadius: BorderRadius.circular(4.0 * ui),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 5.0 * ui,
                backgroundColor: const Color(0xFF281730),
                valueColor: AlwaysStoppedAnimation<Color>(accentColor),
              ),
            ),
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
          color: muted ? const Color(0xFF785C90) : const Color(0xFFA275C4),
          borderRadius: BorderRadius.circular(16.0 * ui),
          border: Border.all(color: const Color(0xFFFFF0D2), width: 2.2 * ui),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF57344E),
              offset: Offset(0, 4.0 * ui),
              blurRadius: 0,
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            CustomPaint(
              size: Size(20.0 * ui, 20.0 * ui),
              painter: _SpeakerIconPainter(
                muted: muted,
                color: muted
                    ? const Color(0xFFF4DFDB)
                    : const Color(0xFFFFF5DF),
              ),
            ),
            SizedBox(height: 2.0 * ui),
            Text(
              muted ? _tr('muted') : _tr('sound_on'),
              style: TextStyle(
                color: muted
                    ? const Color(0xFFF4DFDB)
                    : const Color(0xFFFFF5DF),
                fontSize: 9.0 * ui,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5 * ui,
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
          color: const Color(0xEB432C4D),
          borderRadius: BorderRadius.circular(16.0 * ui),
          border: Border.all(color: const Color(0xFFFFF0D2), width: 2.2 * ui),
          boxShadow: [
            BoxShadow(
              color: const Color(0x6539243E),
              offset: Offset(0, 4.0 * ui),
              blurRadius: 0,
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.language_rounded,
              size: 17.0 * ui,
              color: const Color(0xFFFFD34B),
            ),
            SizedBox(width: 4.0 * ui),
            Text(
              lang.toUpperCase(),
              style: TextStyle(
                color: const Color(0xFFFFF5DF),
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
    Color borderCol = const Color(0xFFFFEAC4);
    IconData icon = Icons.lightbulb_outline_rounded;

    if (nextToken?.role == CTCarRole.police) {
      bannerText = _tr('police_convert_hint');
      borderCol = const Color(0xFF38BDF8);
      icon = Icons.local_police_rounded;
    } else if (nextToken?.role == CTCarRole.green) {
      bannerText = _tr('green_exit_hint');
      borderCol = const Color(0xFF52FFA8);
      icon = Icons.alt_route_rounded;
    } else if (stg?.hint != null && stg!.hint!.isNotEmpty) {
      bannerText = stg.hint!;
      if (stg.isBoss) {
        borderCol = const Color(0xFFFFD34B);
        icon = Icons.workspace_premium_rounded;
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
          color: const Color(0xE03A2444),
          borderRadius: BorderRadius.circular(14.0 * ui),
          border: Border.all(color: borderCol, width: 1.8 * ui),
          boxShadow: [
            BoxShadow(
              color: const Color(0x55291830),
              offset: Offset(0, 3.0 * ui),
              blurRadius: 0,
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(icon, size: 17.0 * ui, color: borderCol),
            SizedBox(width: 6.0 * ui),
            Expanded(
              child: Text(
                bannerText,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: const Color(0xFFFFF3DD),
                  fontSize: 10.5 * ui,
                  fontWeight: FontWeight.w700,
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
        // Slow-Mo Booster (44dp+ touch height, right above Release Car button)
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: canSlow ? onSlowMo : null,
            child: Container(
              constraints: BoxConstraints(minHeight: 44.0 * ui),
              padding: EdgeInsets.symmetric(
                horizontal: 8.0 * ui,
                vertical: 7.0 * ui,
              ),
              decoration: BoxDecoration(
                color: slowActive
                    ? const Color(0xFF0284C7)
                    : canSlow
                    ? const Color(0xEB432C4D)
                    : const Color(0x9935243D),
                borderRadius: BorderRadius.circular(14.0 * ui),
                border: Border.all(
                  color: (canSlow || slowActive)
                      ? const Color(0xFF7DD3FC)
                      : const Color(0x777DD3FC),
                  width: 2.0 * ui,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0x6539243E),
                    offset: Offset(0, 3.5 * ui),
                    blurRadius: 0,
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.ac_unit_rounded,
                    size: 16.0 * ui,
                    color: const Color(0xFF7DD3FC),
                  ),
                  SizedBox(width: 4.0 * ui),
                  Expanded(
                    child: Text(
                      slowActive
                          ? '${state.slowMoRemaining.toStringAsFixed(1)}s'
                          : _tr('booster_slowmo'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: const Color(0xFFFFF5DF),
                        fontSize: 11.0 * ui,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  SizedBox(width: 3.0 * ui),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 5.0 * ui,
                      vertical: 2.0 * ui,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF38BDF8),
                      borderRadius: BorderRadius.circular(6.0 * ui),
                    ),
                    child: Text(
                      'x${state.slowMoCharges}',
                      style: TextStyle(
                        color: const Color(0xFF0F172A),
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
        // Zap Clear Booster (44dp+ touch height, right above Release Car button)
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: canZap ? onZapClear : null,
            child: Container(
              constraints: BoxConstraints(minHeight: 44.0 * ui),
              padding: EdgeInsets.symmetric(
                horizontal: 8.0 * ui,
                vertical: 7.0 * ui,
              ),
              decoration: BoxDecoration(
                color: canZap
                    ? const Color(0xEB432C4D)
                    : const Color(0x9935243D),
                borderRadius: BorderRadius.circular(14.0 * ui),
                border: Border.all(
                  color: canZap
                      ? const Color(0xFFFFD34B)
                      : const Color(0x77FFD34B),
                  width: 2.0 * ui,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0x6539243E),
                    offset: Offset(0, 3.5 * ui),
                    blurRadius: 0,
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.bolt_rounded,
                    size: 17.0 * ui,
                    color: const Color(0xFFFFD34B),
                  ),
                  SizedBox(width: 3.0 * ui),
                  Expanded(
                    child: Text(
                      _tr('booster_zap'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: const Color(0xFFFFF5DF),
                        fontSize: 11.0 * ui,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  SizedBox(width: 3.0 * ui),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 5.0 * ui,
                      vertical: 2.0 * ui,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFD34B),
                      borderRadius: BorderRadius.circular(6.0 * ui),
                    ),
                    child: Text(
                      'x${state.zapCharges}',
                      style: TextStyle(
                        color: const Color(0xFF422006),
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

  Widget _buildStageClearPanel(double ui) {
    final stg = state.stage;
    final stgId = stg?.id ?? state.stageId;
    final stgName = stg?.name ?? 'Stage $stgId';
    final isFinalVictory =
        (state.mode == CTGameMode.campaign && stgId >= kCTStages.length) ||
        (state.mode == CTGameMode.bossRush && state.bossRushIndex >= 9);

    return Container(
      padding: EdgeInsets.fromLTRB(18.0 * ui, 16.0 * ui, 18.0 * ui, 18.0 * ui),
      decoration: BoxDecoration(
        color: const Color(0xFF422B4A),
        borderRadius: BorderRadius.circular(24.0 * ui),
        border: Border.all(color: const Color(0xFF52FFA8), width: 3.0 * ui),
        boxShadow: [
          BoxShadow(
            color: const Color(0x88261B36),
            offset: Offset(0, 7.0 * ui),
            blurRadius: 0,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  '${_tr('stage_label')} $stgId · ${stgName.toUpperCase()}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: const Color(0xFF52FFA8),
                    fontSize: 11.5 * ui,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.0 * ui,
                  ),
                ),
              ),
              if (streak > 1)
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 8.0 * ui,
                    vertical: 3.0 * ui,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF9F43),
                    borderRadius: BorderRadius.circular(9.0 * ui),
                  ),
                  child: Text(
                    '🔥 x$streak',
                    style: TextStyle(
                      color: const Color(0xFF2E1503),
                      fontSize: 11.0 * ui,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(height: 6.0 * ui),
          Text(
            isFinalVictory ? _tr('victory_title') : _tr('stage_cleared'),
            style: TextStyle(
              color: const Color(0xFFFFF2D5),
              fontSize: 22.0 * ui,
              fontWeight: FontWeight.w900,
              height: 1.1,
              letterSpacing: -0.5 * ui,
            ),
          ),
          SizedBox(height: 6.0 * ui),
          Text(
            isFinalVictory ? _tr('victory_sub') : _tr('stage_cleared_sub'),
            style: TextStyle(
              color: const Color(0xFFE7C3D2),
              fontSize: 13.5 * ui,
              height: 1.3,
            ),
          ),
          SizedBox(height: 12.0 * ui),
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: 12.0 * ui,
              vertical: 8.0 * ui,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFF55365E),
              borderRadius: BorderRadius.circular(14.0 * ui),
              border: Border.all(
                color: const Color(0xFF90619A),
                width: 1.0 * ui,
              ),
            ),
            child: Row(
              children: [
                Text(
                  '${state.cleanMerges}',
                  style: TextStyle(
                    color: const Color(0xFFFFD34B),
                    fontSize: 26.0 * ui,
                    fontWeight: FontWeight.w800,
                    height: 1.0,
                  ),
                ),
                SizedBox(width: 8.0 * ui),
                Text(
                  'clean merges',
                  style: TextStyle(
                    color: const Color(0xFFF1D3DB),
                    fontSize: 14.0 * ui,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 12.0 * ui),
          // Primary Next Stage button
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (_) => onNextStage(),
            child: Container(
              height: 58.0 * ui,
              padding: EdgeInsets.symmetric(horizontal: 16.0 * ui),
              decoration: BoxDecoration(
                color: const Color(0xFF52FFA8),
                borderRadius: BorderRadius.circular(18.0 * ui),
                border: Border.all(
                  color: const Color(0xFFD1FAE5),
                  width: 2.5 * ui,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF155E43),
                    offset: Offset(0, 4.0 * ui),
                    blurRadius: 0,
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isFinalVictory ? _tr('play_again') : _tr('next_stage'),
                    style: TextStyle(
                      color: const Color(0xFF132A20),
                      fontSize: 18.0 * ui,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.3 * ui,
                    ),
                  ),
                  Container(
                    width: 36.0 * ui,
                    height: 36.0 * ui,
                    decoration: BoxDecoration(
                      color: const Color(0xFF132A20),
                      borderRadius: BorderRadius.circular(12.0 * ui),
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.arrow_forward_rounded,
                      color: const Color(0xFF52FFA8),
                      size: 20.0 * ui,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 10.0 * ui),
          // Secondary Modes & Levels button (46dp+ touch height)
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onToggleSelector,
            child: Container(
              height: 46.0 * ui,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFF55365E),
                borderRadius: BorderRadius.circular(14.0 * ui),
                border: Border.all(
                  color: const Color(0xFFFFEAC4),
                  width: 1.5 * ui,
                ),
              ),
              child: Text(
                _tr('modes_and_stages'),
                style: TextStyle(
                  color: const Color(0xFFFFF0D7),
                  fontSize: 13.5 * ui,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFailPanel(double ui, String mergeWord) {
    final isTimeUp =
        state.mode == CTGameMode.timeAttack && state.timeRemaining <= 0;

    return Container(
      padding: EdgeInsets.fromLTRB(18.0 * ui, 16.0 * ui, 18.0 * ui, 18.0 * ui),
      decoration: BoxDecoration(
        color: const Color(0xFF422B4A),
        borderRadius: BorderRadius.circular(24.0 * ui),
        border: Border.all(color: const Color(0xFFFFEAC4), width: 2.5 * ui),
        boxShadow: [
          BoxShadow(
            color: const Color(0x88261B36),
            offset: Offset(0, 7.0 * ui),
            blurRadius: 0,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 26.0 * ui,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _tr('run_ended'),
                  style: TextStyle(
                    color: const Color(0xFFE7B3DD),
                    fontSize: 11.0 * ui,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5 * ui,
                  ),
                ),
                Container(
                  width: 24.0 * ui,
                  height: 24.0 * ui,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEDB49A),
                    borderRadius: BorderRadius.circular(8.0 * ui),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '!',
                    style: TextStyle(
                      color: const Color(0xFFA85F4C),
                      fontSize: 16.0 * ui,
                      fontWeight: FontWeight.w900,
                      height: 1.0,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 6.0 * ui),
          Text(
            isTimeUp ? _tr('time_up_title') : _tr('traffic_jam'),
            style: TextStyle(
              color: const Color(0xFFFFF2D5),
              fontSize: 22.0 * ui,
              fontWeight: FontWeight.w900,
              height: 1.1,
              letterSpacing: -0.5 * ui,
            ),
          ),
          SizedBox(height: 6.0 * ui),
          Text(
            isTimeUp ? _tr('time_up_sub') : _tr('traffic_jam_sub'),
            style: TextStyle(
              color: const Color(0xFFE7C3D2),
              fontSize: 13.5 * ui,
              height: 1.3,
            ),
          ),
          SizedBox(height: 12.0 * ui),
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: 12.0 * ui,
              vertical: 8.0 * ui,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFF55365E),
              borderRadius: BorderRadius.circular(14.0 * ui),
              border: Border.all(
                color: const Color(0xFF90619A),
                width: 1.0 * ui,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  '${state.cleanMerges}',
                  style: TextStyle(
                    color: const Color(0xFFFFD34B),
                    fontSize: 26.0 * ui,
                    fontWeight: FontWeight.w800,
                    height: 1.0,
                  ),
                ),
                SizedBox(width: 8.0 * ui),
                Text(
                  mergeWord,
                  style: TextStyle(
                    color: const Color(0xFFF1D3DB),
                    fontSize: 14.0 * ui,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 12.0 * ui),
          // .retry-button
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (_) => onRetry(),
            child: Container(
              height: 58.0 * ui,
              padding: EdgeInsets.symmetric(horizontal: 16.0 * ui),
              decoration: BoxDecoration(
                color: const Color(0xFFFFCF3C),
                borderRadius: BorderRadius.circular(18.0 * ui),
                border: Border.all(
                  color: const Color(0xFFFFF1C7),
                  width: 2.5 * ui,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFA77155),
                    offset: Offset(0, 4.0 * ui),
                    blurRadius: 0,
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _tr('try_again'),
                    style: TextStyle(
                      color: const Color(0xFF55344B),
                      fontSize: 18.0 * ui,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.3 * ui,
                    ),
                  ),
                  Container(
                    width: 36.0 * ui,
                    height: 36.0 * ui,
                    decoration: BoxDecoration(
                      color: const Color(0xFFAD78CE),
                      borderRadius: BorderRadius.circular(12.0 * ui),
                    ),
                    alignment: Alignment.center,
                    child: CustomPaint(
                      size: Size(22.0 * ui, 22.0 * ui),
                      painter: _RetryIconPainter(
                        color: const Color(0xFFFFF3DA),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (state.useStagePaths) ...[
            SizedBox(height: 10.0 * ui),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onToggleSelector,
              child: Container(
                height: 46.0 * ui,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFF55365E),
                  borderRadius: BorderRadius.circular(14.0 * ui),
                  border: Border.all(
                    color: const Color(0xFFFFEAC4),
                    width: 1.5 * ui,
                  ),
                ),
                child: Text(
                  _tr('modes_and_stages'),
                  style: TextStyle(
                    color: const Color(0xFFFFF0D7),
                    fontSize: 13.5 * ui,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ],
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

/// Matches the SVG in .badge-symbol:
/// `<svg viewBox="0 0 32 32"><path d="m9 13 3-6h8l3 6M6 13h20v11H6z"/><path d="M10 24v3m12-3v3M9 18h3m8 0h3"/></svg>`
class _CarBadgeIconPainter extends CustomPainter {
  final Color color;
  const _CarBadgeIconPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / 32.0;
    final sy = size.height / 32.0;

    final p1 = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2 * sx
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;

    final roofAndBody = Path()
      ..moveTo(9 * sx, 13 * sy)
      ..lineTo(12 * sx, 7 * sy)
      ..lineTo(20 * sx, 7 * sy)
      ..lineTo(23 * sx, 13 * sy)
      ..moveTo(6 * sx, 13 * sy)
      ..lineTo(26 * sx, 13 * sy)
      ..lineTo(26 * sx, 24 * sy)
      ..lineTo(6 * sx, 24 * sy)
      ..close();
    canvas.drawPath(roofAndBody, p1);

    final p2 = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4 * sx
      ..strokeCap = StrokeCap.round;

    final details = Path()
      ..moveTo(10 * sx, 24 * sy)
      ..lineTo(10 * sx, 27 * sy)
      ..moveTo(22 * sx, 24 * sy)
      ..lineTo(22 * sx, 27 * sy)
      ..moveTo(9 * sx, 18 * sy)
      ..lineTo(12 * sx, 18 * sy)
      ..moveTo(20 * sx, 18 * sy)
      ..lineTo(23 * sx, 18 * sy);
    canvas.drawPath(details, p2);
  }

  @override
  bool shouldRepaint(covariant _CarBadgeIconPainter oldDelegate) =>
      oldDelegate.color != color;
}

/// Matches the SVG in .sound-button:
/// `<svg viewBox="0 0 32 32"><path d="M5 12h5l7-6v20l-7-6H5z" fill="currentColor"/>...</svg>`
class _SpeakerIconPainter extends CustomPainter {
  final bool muted;
  final Color color;
  const _SpeakerIconPainter({required this.muted, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / 32.0;
    final sy = size.height / 32.0;

    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final speaker = Path()
      ..moveTo(5 * sx, 12 * sy)
      ..lineTo(10 * sx, 12 * sy)
      ..lineTo(17 * sx, 6 * sy)
      ..lineTo(17 * sx, 26 * sy)
      ..lineTo(10 * sx, 20 * sy)
      ..lineTo(5 * sx, 20 * sy)
      ..close();
    canvas.drawPath(speaker, fillPaint);

    final strokePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5 * sx
      ..strokeCap = StrokeCap.round;

    if (!muted) {
      final waves = Path()
        ..moveTo(22 * sx, 11 * sy)
        ..quadraticBezierTo(27 * sx, 16 * sy, 22 * sx, 21 * sy)
        ..moveTo(26 * sx, 7 * sy)
        ..quadraticBezierTo(35 * sx, 16 * sy, 26 * sx, 25 * sy);
      canvas.drawPath(waves, strokePaint);
    } else {
      final cross = Path()
        ..moveTo(22 * sx, 12 * sy)
        ..lineTo(29 * sx, 20 * sy)
        ..moveTo(29 * sx, 12 * sy)
        ..lineTo(22 * sx, 20 * sy);
      canvas.drawPath(cross, strokePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _SpeakerIconPainter oldDelegate) =>
      oldDelegate.muted != muted || oldDelegate.color != color;
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

/// Matches the SVG in .retry-icon:
/// `<svg viewBox="0 0 24 24"><path d="M19 8a8 8 0 1 0 1 7M19 3v5h-5" stroke-width="2.4"/></svg>`
class _RetryIconPainter extends CustomPainter {
  final Color color;
  const _RetryIconPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / 24.0;
    final sy = size.height / 24.0;
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4 * sx
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final rect = Rect.fromCircle(
      center: Offset(12 * sx, 12 * sy),
      radius: 8 * sx,
    );
    canvas.drawArc(rect, -0.52, 5.1, false, p);

    final head = Path()
      ..moveTo(19 * sx, 3 * sy)
      ..lineTo(19 * sx, 8 * sy)
      ..lineTo(14 * sx, 8 * sy);
    canvas.drawPath(head, p);
  }

  @override
  bool shouldRepaint(covariant _RetryIconPainter oldDelegate) =>
      oldDelegate.color != color;
}
