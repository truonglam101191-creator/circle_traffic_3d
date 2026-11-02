import 'package:flutter/material.dart';

import '../../domain/entities/circle_traffic_models.dart';

/// Registry of the 16 custom 3D cartoon icons sliced from the 4x4 sprite sheet.
abstract final class GameIcons {
  // Row 1: 4 Game Modes
  static const String modeCampaign =
      'assets/images/icons/icon_mode_campaign.png';
  static const String modeEndless = 'assets/images/icons/icon_mode_endless.png';
  static const String modeTimeAttack =
      'assets/images/icons/icon_mode_time_attack.png';
  static const String modeRushHour =
      'assets/images/icons/icon_mode_rush_hour.png';

  // Row 2: 2 Game Modes + 2 Boosters
  static const String modeBossRush =
      'assets/images/icons/icon_mode_boss_rush.png';
  static const String modePoliceChase =
      'assets/images/icons/icon_mode_police_chase.png';
  static const String boosterSlowMo =
      'assets/images/icons/icon_booster_slowmo.png';
  static const String boosterZap = 'assets/images/icons/icon_booster_zap.png';

  // Row 3: Vehicles & Progression
  static const String carMerge = 'assets/images/icons/icon_car_merge.png';
  static const String carGreenExit =
      'assets/images/icons/icon_car_green_exit.png';
  static const String trophy = 'assets/images/icons/icon_trophy.png';
  static const String streakFire = 'assets/images/icons/icon_streak_fire.png';

  // Row 4: Top Bar & Play Controls
  static const String soundOn = 'assets/images/icons/icon_sound_on.png';
  static const String soundOff = 'assets/images/icons/icon_sound_off.png';
  static const String language = 'assets/images/icons/icon_language.png';
  static const String playGo = 'assets/images/icons/icon_play_go.png';

  /// Returns the sliced icon asset path corresponding to a [CTGameMode].
  static String forMode(CTGameMode mode) {
    return switch (mode) {
      CTGameMode.campaign => modeCampaign,
      CTGameMode.endless => modeEndless,
      CTGameMode.timeAttack => modeTimeAttack,
      CTGameMode.rushHour => modeRushHour,
      CTGameMode.bossRush => modeBossRush,
      CTGameMode.policeChase => modePoliceChase,
    };
  }
}

/// Renders a pre-sliced 128x128 3D cartoon game icon with zero layout jitter.
class GameSpriteIcon extends StatelessWidget {
  final String assetPath;
  final double size;

  const GameSpriteIcon(this.assetPath, {super.key, required this.size});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      assetPath,
      width: size,
      height: size,
      fit: BoxFit.contain,
      gaplessPlayback: true,
      filterQuality: FilterQuality.medium,
    );
  }
}
