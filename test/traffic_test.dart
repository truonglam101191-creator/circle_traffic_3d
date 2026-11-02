import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:circle_traffic_3d/features/traffic_game/data/datasources/circle_traffic_localization.dart';
import 'package:circle_traffic_3d/features/traffic_game/domain/entities/circle_traffic_models.dart';
import 'package:circle_traffic_3d/features/traffic_game/domain/entities/game_traffic_state.dart';
import 'package:circle_traffic_3d/features/traffic_game/domain/repositories/audio_repository.dart';
import 'package:circle_traffic_3d/features/traffic_game/domain/services/traffic_math_service.dart';
import 'package:circle_traffic_3d/features/traffic_game/presentation/providers/game_providers.dart';
import 'package:circle_traffic_3d/features/traffic_game/presentation/screens/menu_screen.dart';
import 'package:circle_traffic_3d/features/traffic_game/presentation/widgets/game_icons.dart';
import 'package:circle_traffic_3d/features/traffic_game/presentation/widgets/game_overlay.dart';
import 'package:circle_traffic_3d/game/data/circle_traffic_stages.dart';
import 'package:circle_traffic_3d/game/data/circle_traffic_themes.dart';

class _FakeAudioRepository implements AudioRepository {
  @override
  bool isMuted = false;
  int releaseCount = 0;
  int mergeCount = 0;
  int crashCount = 0;
  int policeCount = 0;
  int convertCount = 0;
  int stageClearCount = 0;
  int clickCount = 0;
  int powerupCount = 0;

  @override
  void toggleMute() => isMuted = !isMuted;

  @override
  Future<void> warmUp() async {}

  @override
  Future<void> playRelease() async => releaseCount++;

  @override
  Future<void> playMerge() async => mergeCount++;

  @override
  Future<void> playCrash() async => crashCount++;

  @override
  Future<void> playPolice() async => policeCount++;

  @override
  Future<void> playConvert() async => convertCount++;

  @override
  Future<void> playStageClear() async => stageClearCount++;

  @override
  Future<void> playClick() async => clickCount++;

  @override
  Future<void> playPowerup() async => powerupCount++;

  @override
  void dispose() {}
}

void main() {
  test('Traffic math initialization and arc length', () {
    TrafficMath.initialize();
    expect(TrafficMath.rampLength, greaterThan(5.0));
    expect(TrafficMath.lookup.length, 641);
  });

  test('Game initial state and cars advance', () {
    final state = GameTrafficState.createInitial();
    expect(state.cars.length, 3);
    expect(state.crashed, false);

    final advanced = state.advance(0.1, 1.0);
    expect(advanced.cars.length, 3);
    expect(advanced.crashed, false);
  });

  test('Release car adds car to ramp', () {
    final state = GameTrafficState.createInitial();
    final released = state.releaseCar(1.0);
    expect(released.cars.length, 4);
    expect(released.cars.last.path, 'ramp');
    expect(released.cooldown, greaterThan(0.0));
  });

  test('All 100 hand-authored stages load, build 3D paths, and advance', () {
    expect(kCTStages.length, 100);
    expect(kCTThemes.length, 10);

    for (final stg in kCTStages) {
      final state = GameTrafficState.createForStage(
        stg.id,
        mode: CTGameMode.campaign,
      );
      expect(state.useStagePaths, true);
      expect(state.stageId, stg.id);
      expect(state.loop, isNotNull);
      expect(state.entrance, isNotNull);
      expect(state.loop!.len, greaterThan(500.0));
      if (stg.exit != 'none') {
        expect(state.exit, isNotNull);
      } else {
        expect(state.exit, isNull);
      }

      final next = state.advance(0.016, 1.0);
      expect(next.crashed, false);
    }
  });

  test('All 6 game modes initialize and support car release & boosters', () {
    for (final mode in CTGameMode.values) {
      var state = GameTrafficState.createForStage(1, mode: mode);
      expect(state.useStagePaths, true);
      expect(state.mode, mode);
      expect(state.queue, isNotEmpty);

      final beforeCount = state.cars.length;
      state = state.releaseCar(1.0);
      expect(state.cars.length, beforeCount + 1);
      expect(state.cars.last.path, 'ramp');

      // Slow-Mo booster
      final slowState = state.triggerSlowMo();
      expect(slowState.slowMoRemaining, greaterThan(0.0));
      expect(slowState.slowMoCharges, state.slowMoCharges - 1);

      // Zap Clear booster
      final zapState = slowState.triggerZapClear();
      expect(zapState.zapCharges, slowState.zapCharges - 1);
    }
  });

  test('Figure-8 overpass bridge elevates cars at s1', () {
    final fig8Stage = kCTStages.firstWhere(
      (s) => s.shape == CTRoadShape.figure8,
    );
    final state = GameTrafficState.createForStage(fig8Stage.id);
    final loop = state.loop!;
    expect(loop.meta!.shape, 'figure8');
    final zAtOverpass = CTPathBuilder.getCarZ(loop.meta!.s1, loop);
    final zAtUnderpass = CTPathBuilder.getCarZ(loop.meta!.s2, loop);
    expect(zAtOverpass, closeTo(1.0, 0.05));
    expect(zAtUnderpass, closeTo(0.0, 0.05));
  });

  test(
    'Clean Architecture + Riverpod GameSessionNotifier orchestrates use cases',
    () {
      final fakeAudio = _FakeAudioRepository();
      final container = ProviderContainer(
        overrides: [
          audioRepositoryProvider.overrideWithValue(fakeAudio),
        ],
      );
      addTearDown(container.dispose);

      final initialSession = container.read(gameSessionProvider);
      expect(initialSession.traffic.stageId, 1);
      expect(initialSession.traffic.mode, CTGameMode.campaign);
      expect(initialSession.isMuted, false);

      final notifier = container.read(gameSessionProvider.notifier);

      // 1. Release car via UseCase
      final carsBefore = initialSession.traffic.cars.length;
      notifier.releaseCar();
      final afterRelease = container.read(gameSessionProvider);
      expect(afterRelease.traffic.cars.length, carsBefore + 1);
      expect(fakeAudio.releaseCount, 1);

      // 2. Step simulation tick via AdvanceTrafficUseCase
      notifier.onTick(const Duration(milliseconds: 16), forceStateSync: true);
      final afterTick = container.read(gameSessionProvider);
      expect(afterTick.elapsedTime, greaterThan(0.0));

      // 3. Toggle sound via ToggleSoundUseCase
      notifier.toggleSound();
      expect(container.read(gameSessionProvider).isMuted, true);

      // 4. Switch mode & stage via ResetGameUseCase
      notifier.selectMode(CTGameMode.timeAttack);
      expect(
        container.read(gameSessionProvider).traffic.mode,
        CTGameMode.timeAttack,
      );

      notifier.selectStage(25);
      expect(container.read(gameSessionProvider).traffic.stageId, 25);
      expect(
        container.read(gameSessionProvider).traffic.mode,
        CTGameMode.campaign,
      );

      // 5. Trigger Slow-Mo & Zap-Clear boosters via Booster UseCases
      final chargesBefore =
          container.read(gameSessionProvider).traffic.slowMoCharges;
      notifier.triggerSlowMo();
      expect(
        container.read(gameSessionProvider).traffic.slowMoCharges,
        chargesBefore - 1,
      );
      expect(fakeAudio.powerupCount, 1);
    },
  );

  testWidgets(
    'GameOverlay respects statusBar safe area and mobile touch sizes on 360x760 phone',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 760));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final state = GameTrafficState.createForStage(1, mode: CTGameMode.campaign);

      Widget buildTestApp({required bool showSelector}) {
        return MediaQuery(
          data: const MediaQueryData(
            size: Size(360, 760),
            viewPadding: EdgeInsets.only(top: 36, bottom: 24),
            padding: EdgeInsets.only(top: 36, bottom: 24),
          ),
          child: MaterialApp(
            home: Scaffold(
              body: GameOverlay(
                state: state,
                muted: false,
                lang: 'vi',
                showModeStageSelector: showSelector,
                onRelease: () {},
                onToggleSound: () {},
                rewards: const [],
                projectCar: (_, _, _) => const Offset(180, 380),
              ),
            ),
          ),
        );
      }

      await tester.pumpWidget(buildTestApp(showSelector: false));
      expect(tester.takeException(), isNull);

      // Verify in-game HUD has removed the title logo image and uses sliced GameSpriteIcons
      expect(find.byType(MenuScreen), findsNothing);
      expect(find.byType(GameSpriteIcon), findsWidgets);

      // Verify language button ("VI") sits below the 36dp status bar and has >= 42dp touch height
      final langFinder = find.text('VI');
      expect(langFinder, findsOneWidget);
      final langButtonBox = tester.getRect(
        find.ancestor(of: langFinder, matching: find.byType(GestureDetector)).first,
      );
      expect(langButtonBox.top, greaterThanOrEqualTo(36.0));
      expect(langButtonBox.height, greaterThanOrEqualTo(42.0));

      // Verify release car button has large mobile touch target
      final releaseFinder = find.text(CTStrings.tr('release_car', lang: 'vi'));
      expect(releaseFinder, findsOneWidget);
      final releaseBox = tester.getRect(
        find.ancestor(of: releaseFinder, matching: find.byType(GestureDetector)).first,
      );
      expect(releaseBox.height, greaterThanOrEqualTo(58.0));
      expect(releaseBox.bottom, lessThanOrEqualTo(760.0 - 24.0));

      // Verify dedicated MenuScreen renders 6 Modes & 100 Stages without overflow on 360x760 phone
      await tester.pumpWidget(buildTestApp(showSelector: true));
      expect(tester.takeException(), isNull);
      expect(find.byType(MenuScreen), findsOneWidget);
      expect(find.text('6 CHẾ ĐỘ CHƠI'), findsOneWidget);
      expect(find.text('Chiến Dịch 100 Màn'), findsOneWidget);

      // Switch to 100 Stages tab and verify stages render without overflow
      await tester.tap(find.text('100 MÀN CHƠI (0/100)'));
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.text('Tap Tap Tap'), findsOneWidget);
    },
  );
}
