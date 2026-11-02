import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_scene/scene.dart';

import '../../data/datasources/circle_traffic_localization.dart';
import '../../domain/services/traffic_math_service.dart';
import '../providers/game_providers.dart';
import '../widgets/game_overlay.dart';

/// Main game screen powered by Clean Architecture + Riverpod (`ConsumerStatefulWidget`).
///
/// The visual layers (Backdrop, 3D `SceneView`, Floating Rewards, and 2D `GameOverlay`)
/// are isolated into independent `RepaintBoundary` + `ConsumerWidget`s with granular
/// subscriptions so HUD state updates never rebuild the 3D viewport or backdrop, and
/// floating merge popups never rebuild the main 2D HUD.
class GameScreen extends ConsumerStatefulWidget {
  const GameScreen({super.key});

  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends ConsumerState<GameScreen>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;

  bool _onKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.space) {
      if (mounted) {
        ref.read(gameSessionProvider.notifier).releaseCar();
      }
      return true;
    }
    return false;
  }

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_onKeyEvent);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final notifier = ref.read(gameSessionProvider.notifier);
        notifier.openMenu();
        notifier.init3D();
      }
    });
    _ticker = createTicker((elapsed) {
      if (mounted) {
        ref.read(gameSessionProvider.notifier).onTick(elapsed);
      }
    })..start();
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKeyEvent);
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final screenSize = Size(
            constraints.maxWidth,
            constraints.maxHeight,
          );
          return Stack(
            fit: StackFit.expand,
            children: [
              const RepaintBoundary(
                child: _BackdropLayer(),
              ),
              RepaintBoundary(
                child: _Scene3DViewportLayer(screenSize: screenSize),
              ),
              RepaintBoundary(
                child: _FloatingRewardsLayer(screenSize: screenSize),
              ),
              const RepaintBoundary(
                child: _HudOverlayLayer(),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _BackdropLayer extends ConsumerWidget {
  const _BackdropLayer();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stageId = ref.watch(
      gameSessionProvider.select((s) => s.traffic.stageId),
    );
    final theme = ref.watch(stageRepositoryProvider).themeForStage(stageId);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.lerp(
              const Color(0xFF8E72B7),
              theme.accent,
              0.18,
            )!,
            const Color(0xFFFFCC96),
            const Color(0xFFEEA2AB),
          ],
          stops: const [0.0, 0.30, 1.0],
        ),
      ),
      child: Image.asset(
        'assets/images/backdrop.webp',
        fit: BoxFit.fill,
        alignment: Alignment.topCenter,
        cacheWidth: 540,
        gaplessPlayback: true,
        filterQuality: FilterQuality.low,
      ),
    );
  }
}

class _Scene3DViewportLayer extends ConsumerWidget {
  final Size screenSize;

  const _Scene3DViewportLayer({required this.screenSize});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sceneReady = ref.watch(
      gameSessionProvider.select((s) => s.sceneReady),
    );
    if (!sceneReady) {
      return const SizedBox.shrink();
    }
    final world3d = ref.watch(scene3DWorldProvider);
    final sceneTick = ref.watch(sceneTickProvider);
    final notifier = ref.read(gameSessionProvider.notifier);

    return ValueListenableBuilder<int>(
      valueListenable: sceneTick,
      builder: (context, _, _) {
        return SceneView(
          world3d.scene,
          camera: world3d.buildCamera(
            notifier.liveTraffic,
            screenSize,
          ),
        );
      },
    );
  }
}

class _FloatingRewardsLayer extends ConsumerWidget {
  final Size screenSize;

  const _FloatingRewardsLayer({required this.screenSize});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inMenu = ref.watch(
      gameSessionProvider.select((s) => s.showModeStageSelector),
    );
    if (inMenu) {
      return const SizedBox.shrink();
    }
    final rewardTick = ref.watch(rewardTickProvider);
    final world3d = ref.watch(scene3DWorldProvider);
    final notifier = ref.read(gameSessionProvider.notifier);
    final lang = ref.watch(gameSessionProvider.select((s) => s.lang));
    final ui = (screenSize.width / 390.0).clamp(0.85, 1.35);

    return ValueListenableBuilder<int>(
      valueListenable: rewardTick,
      builder: (context, _, _) {
        final rewards = notifier.activeRewards;
        if (rewards.isEmpty) {
          return const SizedBox.shrink();
        }
        return IgnorePointer(
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              for (final r in rewards)
                _buildPopup(r, world3d, screenSize, ui, lang),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPopup(
    RewardPopupData r,
    dynamic world3d,
    Size stageSize,
    double ui,
    String lang,
  ) {
    final motion = TrafficMath.rewardMotion(r.age);
    if (!motion.visible) return const SizedBox.shrink();
    final pt = world3d.projectCar(r.carId, motion.height, stageSize) as Offset?;
    if (pt == null) return const SizedBox.shrink();

    final popWidth = 172.0 * ui;
    final popHeight = 40.0 * ui;
    final halfW = popWidth / 2.0 + 8.0 * ui;
    final clampedX = pt.dx.clamp(
      halfW,
      math.max(halfW, stageSize.width - halfW),
    );
    final label = r.customLabel ?? CTStrings.tr('smooth_merge', lang: lang);
    final badge = r.customBadge ?? '+1';
    final op = motion.opacity.clamp(0.0, 1.0);

    return Positioned(
      left: clampedX - popWidth / 2.0,
      top: pt.dy - popHeight,
      width: popWidth,
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
    );
  }
}

class _HudOverlayLayer extends ConsumerWidget {
  const _HudOverlayLayer();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(gameSessionProvider);
    final notifier = ref.read(gameSessionProvider.notifier);
    final world3d = ref.watch(scene3DWorldProvider);

    return GameOverlay(
      state: session.traffic,
      muted: session.isMuted,
      lang: session.lang,
      streak: session.streak,
      bestEndlessScore: session.bestEndlessScore,
      clearedStages: session.clearedStages,
      showModeStageSelector: session.showModeStageSelector,
      onRelease: notifier.releaseCar,
      onToggleSound: notifier.toggleSound,
      onCycleLanguage: notifier.cycleLanguage,
      onToggleSelector: notifier.toggleSelector,
      onNextStage: notifier.nextStage,
      onRetry: notifier.retry,
      onSlowMo: notifier.triggerSlowMo,
      onZapClear: notifier.triggerZapClear,
      onSelectMode: notifier.selectMode,
      onSelectStage: notifier.selectStage,
      rewards: const [],
      projectCar: (id, elevation, stageSize) =>
          world3d.projectCar(id, elevation, stageSize),
      badgeBounceScale: 1.0,
      releaseBounceScale: 1.0,
      crashFlashOpacity: session.crashFlashOpacity,
    );
  }
}
