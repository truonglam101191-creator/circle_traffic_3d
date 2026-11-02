import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../data/datasources/circle_traffic_localization.dart';
import '../../data/datasources/circle_traffic_stages.dart';
import '../../data/datasources/circle_traffic_themes.dart';
import '../../domain/entities/circle_traffic_models.dart';
import '../../domain/entities/game_traffic_state.dart';
import '../widgets/game_icons.dart';

/// Main Menu Screen crafted in the bright, tactile Casual 3D Game UI style:
/// - Glossy Sky-Blue 3D outer bezel (`#B8E1FF` -> `#89C4F4`) with 3D bottom lip
/// - Warm Creamy-Ivory inner surface (`#FAF8F0`) with crisp `#E5E1D0` dividers
/// - Floating Sky-Blue 3D top ribbon pill straddling the frame edge
/// - Pastel Ice-Blue sub-cards (`#E6F4FE`) with 3D cartoon icons & golden mini-pills
/// - Giant glossy 3D Gold primary CTA button (`VÀO CHƠI NGAY / PLAY NOW`)
class MenuScreen extends StatefulWidget {
  final GameTrafficState state;
  final bool muted;
  final String lang;
  final Set<int> clearedStages;
  final int bestEndlessScore;
  final VoidCallback onResumeOrPlay;
  final VoidCallback onToggleSound;
  final VoidCallback onCycleLanguage;
  final void Function(CTGameMode mode) onSelectMode;
  final void Function(int stageId) onSelectStage;

  const MenuScreen({
    super.key,
    required this.state,
    required this.muted,
    required this.lang,
    required this.clearedStages,
    required this.bestEndlessScore,
    required this.onResumeOrPlay,
    required this.onToggleSound,
    required this.onCycleLanguage,
    required this.onSelectMode,
    required this.onSelectStage,
  });

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  /// `0` = 6 Game Modes tab, `1` = 100 Stages (10 Districts) tab.
  int _activeTab = 0;
  late int _selectedDistrict;

  @override
  void initState() {
    super.initState();
    _selectedDistrict = ((widget.state.stageId - 1) ~/ 10).clamp(0, 9);
  }

  @override
  void didUpdateWidget(covariant MenuScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state.stageId != widget.state.stageId) {
      _selectedDistrict = ((widget.state.stageId - 1) ~/ 10).clamp(0, 9);
    }
  }

  String _tr(String key) => CTStrings.tr(key, lang: widget.lang);

  @override
  Widget build(BuildContext context) {
    final viewPadding = MediaQuery.viewPaddingOf(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final stageW = constraints.maxWidth;
        final stageH = constraints.maxHeight;
        final ui = (stageW / 390.0).clamp(0.86, 1.30);
        final compactH = stageH < 750;

        final safeTop = math.max(viewPadding.top + 6.0, 12.0 * ui);
        final safeBottom = math.max(viewPadding.bottom + 8.0, 12.0 * ui);
        final safeLeft = math.max(viewPadding.left + 12.0 * ui, 12.0 * ui);
        final safeRight = math.max(viewPadding.right + 12.0 * ui, 12.0 * ui);

        final stg = widget.state.stage;
        final stgId = stg?.id ?? widget.state.stageId;
        final stgName = stg?.name ?? 'Stage $stgId';
        final districtTheme = ctThemeForStage(stgId);

        final currentHeaderSub = switch (widget.state.mode) {
          CTGameMode.campaign =>
            '${_tr('stage_label')} $stgId · ${districtTheme.name.toUpperCase()} · ${stgName.toUpperCase()}',
          CTGameMode.endless =>
            '${_tr('mode_endless').toUpperCase()} · BEST ${widget.bestEndlessScore}',
          CTGameMode.timeAttack =>
            '${_tr('mode_timeAttack').toUpperCase()} · 60S RUSH',
          CTGameMode.rushHour =>
            '${_tr('mode_rushHour').toUpperCase()} · SPEED WAVES',
          CTGameMode.bossRush =>
            '${_tr('mode_bossRush').toUpperCase()} · 10 BOSS STAGES',
          CTGameMode.policeChase =>
            '${_tr('mode_policeChase').toUpperCase()} · ESCORT SQUAD',
        };

        return Container(
          // Soft atmospheric blur-like tint over the live 3D roundabout
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0x383A6B9C),
                Color(0x66294C75),
                Color(0x881F3A5C),
              ],
            ),
          ),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              safeLeft,
              safeTop,
              safeRight,
              safeBottom,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: 470.0 * ui),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 1. Top Utility Row: Trophy Pill + Language + Sound
                    _buildTopBar(ui),
                    SizedBox(height: compactH ? 18.0 * ui : 24.0 * ui),

                    // 2. Main Sky-Blue & Creamy-Ivory 3D Dialog Card (Image 2 Style)
                    Expanded(
                      child: _buildSkyBlueCreamDialog(
                        ui: ui,
                        compactH: compactH,
                        currentHeaderSub: currentHeaderSub,
                        stgId: stgId,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTopBar(double ui) {
    final pillHeight = 42.0 * ui;
    final canPop = Navigator.canPop(context);
    return Row(
      children: [
        if (canPop) ...[
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.maybePop(context),
            child: Container(
              width: pillHeight,
              height: pillHeight,
              decoration: BoxDecoration(
                color: const Color(0xFFFAF8F0),
                borderRadius: BorderRadius.circular(14.0 * ui),
                border: Border.all(
                  color: const Color(0xFF8CC5F2),
                  width: 2.2 * ui,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF558EC2),
                    offset: Offset(0, 3.5 * ui),
                    blurRadius: 0,
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Icon(
                Icons.arrow_back_rounded,
                size: 20.0 * ui,
                color: const Color(0xFF1D4D7A),
              ),
            ),
          ),
          SizedBox(width: 7.0 * ui),
        ],
        // Trophy Progress Pill (Sky-Blue & Cream 3D Pill)
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => setState(() => _activeTab = 1),
          child: Container(
            height: pillHeight,
            padding: EdgeInsets.symmetric(horizontal: 11.0 * ui),
            decoration: BoxDecoration(
              color: const Color(0xFFFAF8F0),
              borderRadius: BorderRadius.circular(14.0 * ui),
              border: Border.all(
                color: const Color(0xFF8CC5F2),
                width: 2.2 * ui,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF558EC2),
                  offset: Offset(0, 3.5 * ui),
                  blurRadius: 0,
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                GameSpriteIcon(GameIcons.trophy, size: 18.0 * ui),
                SizedBox(width: 5.0 * ui),
                Text(
                  '${widget.clearedStages.length}/100',
                  style: TextStyle(
                    color: const Color(0xFF285986),
                    fontSize: 12.5 * ui,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ),
        const Spacer(),
        // Language Pill
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onCycleLanguage,
          child: Container(
            height: pillHeight,
            padding: EdgeInsets.symmetric(horizontal: 10.0 * ui),
            decoration: BoxDecoration(
              color: const Color(0xFFFAF8F0),
              borderRadius: BorderRadius.circular(14.0 * ui),
              border: Border.all(
                color: const Color(0xFF8CC5F2),
                width: 2.2 * ui,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF558EC2),
                  offset: Offset(0, 3.5 * ui),
                  blurRadius: 0,
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                GameSpriteIcon(GameIcons.language, size: 17.0 * ui),
                SizedBox(width: 4.0 * ui),
                Text(
                  widget.lang.toUpperCase(),
                  style: TextStyle(
                    color: const Color(0xFF285986),
                    fontSize: 12.0 * ui,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.4 * ui,
                  ),
                ),
              ],
            ),
          ),
        ),
        SizedBox(width: 7.0 * ui),
        // Sound Pill
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onToggleSound,
          child: Container(
            height: pillHeight,
            padding: EdgeInsets.symmetric(horizontal: 10.0 * ui),
            decoration: BoxDecoration(
              color: widget.muted
                  ? const Color(0xFFEDEAE0)
                  : const Color(0xFFE6F4FE),
              borderRadius: BorderRadius.circular(14.0 * ui),
              border: Border.all(
                color: const Color(0xFF8CC5F2),
                width: 2.2 * ui,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF558EC2),
                  offset: Offset(0, 3.5 * ui),
                  blurRadius: 0,
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                GameSpriteIcon(
                  widget.muted ? GameIcons.soundOff : GameIcons.soundOn,
                  size: 18.0 * ui,
                ),
                SizedBox(width: 4.0 * ui),
                Text(
                  widget.muted ? _tr('sound_off') : _tr('sound_on'),
                  style: TextStyle(
                    color: const Color(0xFF285986),
                    fontSize: 11.0 * ui,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.2 * ui,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSkyBlueCreamDialog({
    required double ui,
    required bool compactH,
    required String currentHeaderSub,
    required int stgId,
  }) {
    final modesTabTitle = switch (widget.lang) {
      'vi' => '6 CHẾ ĐỘ CHƠI',
      'ja' => '6 ゲームモード',
      _ => '6 GAME MODES',
    };
    final stagesTabTitle = switch (widget.lang) {
      'vi' => '100 MÀN CHƠI (${widget.clearedStages.length}/100)',
      'ja' => '100 ステージ (${widget.clearedStages.length}/100)',
      _ => '100 STAGES (${widget.clearedStages.length}/100)',
    };
    final playNowLabel = switch (widget.lang) {
      'vi' => 'VÀO CHƠI NGAY',
      'ja' => '今すぐプレイ',
      _ => 'PLAY NOW',
    };

    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.topCenter,
      children: [
        // Outer Sky-Blue 3D Frame (matches Image 2's glossy light-blue bezel)
        Positioned.fill(
          child: Container(
            padding: EdgeInsets.fromLTRB(
              10.0 * ui,
              12.0 * ui,
              10.0 * ui,
              12.0 * ui,
            ),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFFBDE3FF),
                  Color(0xFF8DC6F5),
                ],
              ),
              borderRadius: BorderRadius.circular(32.0 * ui),
              border: Border.all(
                color: const Color(0xFFE3F3FF),
                width: 2.8 * ui,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF5D99CC),
                  offset: Offset(0, 7.0 * ui),
                  blurRadius: 0,
                ),
                BoxShadow(
                  color: const Color(0x440D233A),
                  offset: Offset(0, 14.0 * ui),
                  blurRadius: 20.0 * ui,
                ),
              ],
            ),
            // Inner Creamy-Ivory Card Surface (#FAF8F0)
            child: Container(
              padding: EdgeInsets.fromLTRB(
                14.0 * ui,
                compactH ? 26.0 * ui : 30.0 * ui,
                14.0 * ui,
                12.0 * ui,
              ),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFFFCFBF5),
                    Color(0xFFF4F0E1),
                  ],
                ),
                borderRadius: BorderRadius.circular(23.0 * ui),
                border: Border.all(
                  color: const Color(0xFFE2DEC9),
                  width: 1.6 * ui,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Subtitle (e.g. "MÀN 1 · MIDNIGHT CITY · TAP TAP TAP")
                  Text(
                    currentHeaderSub,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: const Color(0xFF7087A1),
                      fontSize: 11.5 * ui,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.0 * ui,
                    ),
                  ),
                  SizedBox(height: compactH ? 6.0 * ui : 8.0 * ui),

                  // 2-Column Stat Summary with crisp #E5E1D0 Dividers (Image 2 Style)
                  Container(
                    padding: EdgeInsets.symmetric(vertical: 7.0 * ui),
                    decoration: const BoxDecoration(
                      border: Border(
                        top: BorderSide(color: Color(0xFFE5E1D0), width: 1.2),
                        bottom: BorderSide(
                          color: Color(0xFFE5E1D0),
                          width: 1.2,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            children: [
                              Text(
                                widget.lang == 'vi'
                                    ? 'TIẾN ĐỘ CHIẾN DỊCH'
                                    : 'CAMPAIGN CLEARED',
                                style: TextStyle(
                                  color: const Color(0xFF768BA3),
                                  fontSize: 9.5 * ui,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.6 * ui,
                                ),
                              ),
                              SizedBox(height: 2.0 * ui),
                              Text(
                                '${widget.clearedStages.length} / 100',
                                style: TextStyle(
                                  color: const Color(0xFFF5A623),
                                  fontSize: compactH ? 20.0 * ui : 22.0 * ui,
                                  fontWeight: FontWeight.w900,
                                  height: 1.05,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          width: 1.2,
                          height: 28.0 * ui,
                          color: const Color(0xFFE5E1D0),
                        ),
                        Expanded(
                          child: Column(
                            children: [
                              Text(
                                widget.lang == 'vi'
                                    ? 'MÀN ĐANG CHỌN'
                                    : 'ACTIVE STAGE',
                                style: TextStyle(
                                  color: const Color(0xFF768BA3),
                                  fontSize: 9.5 * ui,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.6 * ui,
                                ),
                              ),
                              SizedBox(height: 2.0 * ui),
                              Text(
                                '#$stgId',
                                style: TextStyle(
                                  color: const Color(0xFF34689A),
                                  fontSize: compactH ? 20.0 * ui : 22.0 * ui,
                                  fontWeight: FontWeight.w900,
                                  height: 1.05,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: compactH ? 8.0 * ui : 10.0 * ui),

                  // Segmented 2-Tab Bar in Pastel Sky-Blue & Cream
                  Container(
                    padding: EdgeInsets.all(3.5 * ui),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE3F0FA),
                      borderRadius: BorderRadius.circular(14.0 * ui),
                      border: Border.all(
                        color: const Color(0xFFB7D9F4),
                        width: 1.4 * ui,
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildSegmentTabButton(
                            ui: ui,
                            selected: _activeTab == 0,
                            iconAsset: GameIcons.carMerge,
                            label: modesTabTitle,
                            onTap: () => setState(() => _activeTab = 0),
                          ),
                        ),
                        SizedBox(width: 5.0 * ui),
                        Expanded(
                          child: _buildSegmentTabButton(
                            ui: ui,
                            selected: _activeTab == 1,
                            iconAsset: GameIcons.modeCampaign,
                            label: stagesTabTitle,
                            onTap: () => setState(() => _activeTab = 1),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: compactH ? 8.0 * ui : 10.0 * ui),

                  // Active Tab Body: 6 Pastel Sub-Cards or 100 Stages Grid
                  Expanded(
                    child: _activeTab == 0
                        ? _buildSixModesGrid(ui)
                        : _buildStagesBrowser(ui),
                  ),
                  SizedBox(height: compactH ? 8.0 * ui : 10.0 * ui),

                  // Giant Glossy 3D Gold Primary CTA Button (Exact Image 2 "NEXT LEVEL" style!)
                  _buildGoldPrimaryCtaButton(ui, playNowLabel),
                  SizedBox(height: 6.0 * ui),

                  // Clean Footer Link (Image 2 "LEVEL SELECT / VIEW LEADERBOARD" style)
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () =>
                        setState(() => _activeTab = _activeTab == 0 ? 1 : 0),
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 2.0 * ui),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          GameSpriteIcon(
                            _activeTab == 0
                                ? GameIcons.modeCampaign
                                : GameIcons.trophy,
                            size: 16.0 * ui,
                          ),
                          SizedBox(width: 6.0 * ui),
                          Text(
                            _activeTab == 0
                                ? (widget.lang == 'vi'
                                      ? 'CHỌN MÀN CHƠI (1–100)'
                                      : 'SELECT STAGE (1–100)')
                                : (widget.lang == 'vi'
                                      ? 'XEM 6 CHẾ ĐỘ CHƠI'
                                      : 'VIEW 6 GAME MODES'),
                            style: TextStyle(
                              color: const Color(0xFF2E6DA4),
                              fontSize: 12.5 * ui,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5 * ui,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // Floating 3D Sky-Blue Top Ribbon Banner straddling the top bezel edge (Image 2 "VICTORY!" banner)
        Positioned(
          top: -16.0 * ui,
          child: Container(
            height: 44.0 * ui,
            padding: EdgeInsets.symmetric(horizontal: 26.0 * ui),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF82D8FA),
                  Color(0xFF3EAEEC),
                ],
              ),
              borderRadius: BorderRadius.circular(18.0 * ui),
              border: Border.all(
                color: const Color(0xFFEAF7FF),
                width: 2.6 * ui,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF267CB5),
                  offset: Offset(0, 4.5 * ui),
                  blurRadius: 0,
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                GameSpriteIcon(GameIcons.modeBossRush, size: 22.0 * ui),
                SizedBox(width: 8.0 * ui),
                Text(
                  'CIRCLE TRAFFIC 3D',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16.5 * ui,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8 * ui,
                    shadows: [
                      Shadow(
                        color: const Color(0xFF1E6A9E),
                        offset: Offset(0, 1.8 * ui),
                        blurRadius: 0,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGoldPrimaryCtaButton(double ui, String label) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onResumeOrPlay,
      child: Container(
        height: 58.0 * ui,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFFFEC85),
              Color(0xFFFFC52E),
            ],
          ),
          borderRadius: BorderRadius.circular(17.0 * ui),
          border: Border.all(
            color: const Color(0xFFEDA818),
            width: 2.2 * ui,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFC48412),
              offset: Offset(0, 4.5 * ui),
              blurRadius: 0,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(15.0 * ui),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Top glossy white highlight bar (Image 2 NEXT LEVEL button shine)
              Positioned(
                top: 2.0 * ui,
                left: 8.0 * ui,
                right: 8.0 * ui,
                height: 16.0 * ui,
                child: IgnorePointer(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10.0 * ui),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.white.withValues(alpha: 0.55),
                          Colors.white.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: const Color(0xFF5E3D04),
                      fontSize: 18.5 * ui,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.4 * ui,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSegmentTabButton({
    required double ui,
    required bool selected,
    required String iconAsset,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        constraints: BoxConstraints(minHeight: 38.0 * ui),
        padding: EdgeInsets.symmetric(
          horizontal: 8.0 * ui,
          vertical: 5.0 * ui,
        ),
        decoration: BoxDecoration(
          gradient: selected
              ? const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFF6CC8F6),
                    Color(0xFF3AA6E4),
                  ],
                )
              : null,
          borderRadius: BorderRadius.circular(11.0 * ui),
          border: selected
              ? Border.all(color: const Color(0xFFEAF7FF), width: 1.5 * ui)
              : null,
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: const Color(0xFF257BB3),
                    offset: Offset(0, 2.0 * ui),
                    blurRadius: 0,
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            GameSpriteIcon(iconAsset, size: 16.0 * ui),
            SizedBox(width: 5.0 * ui),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: selected
                      ? Colors.white
                      : const Color(0xFF496B8C),
                  fontSize: 10.8 * ui,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.2 * ui,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSixModesGrid(double ui) {
    return LayoutBuilder(
      builder: (context, gridConstraints) {
        final cols = gridConstraints.maxWidth >= 460 ? 3 : 2;
        final spacing = 8.0 * ui;
        final cardW = ((gridConstraints.maxWidth - spacing * (cols - 1)) / cols)
            .floorToDouble();
        final rows = (CTGameMode.values.length / cols).ceil();
        final availableH = gridConstraints.maxHeight;
        final idealCardH = ((availableH - spacing * (rows - 1)) / rows).clamp(
          92.0 * ui,
          122.0 * ui,
        );

        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Wrap(
            spacing: spacing,
            runSpacing: spacing,
            children: [
              for (final mode in CTGameMode.values)
                _buildModeSubCard(mode, ui, cardW, idealCardH),
            ],
          ),
        );
      },
    );
  }

  /// Mode Sub-Card modeled directly after the "Squad 24" / "Gear 0" cards in Image 2:
  /// - Soft pastel sky-blue surface (`#E5F3FD`) with `#9CCCF4` border
  /// - 3D cartoon icon on the top-left + bold `#1E4D7B` title & `#67839E` subtitle
  /// - Glossy Golden Mini-Pill button at the bottom (`#FFE780` -> `#F6C63C`)
  Widget _buildModeSubCard(
    CTGameMode mode,
    double ui,
    double cardWidth,
    double cardHeight,
  ) {
    final isCurrent = widget.state.mode == mode;
    final iconAsset = GameIcons.forMode(mode);

    final (title, descKey) = switch (mode) {
      CTGameMode.campaign => (
        switch (widget.lang) {
          'vi' => 'Chiến Dịch 100 Màn',
          'ja' => 'キャンペーン (100ステージ)',
          _ => 'Campaign (100 Stages)',
        },
        'mode_campaign_desc',
      ),
      CTGameMode.endless => (_tr('mode_endless'), 'mode_endless_desc'),
      CTGameMode.timeAttack => (_tr('mode_timeAttack'), 'mode_timeAttack_desc'),
      CTGameMode.rushHour => (_tr('mode_rushHour'), 'mode_rushHour_desc'),
      CTGameMode.bossRush => (_tr('mode_bossRush'), 'mode_bossRush_desc'),
      CTGameMode.policeChase => (
        _tr('mode_policeChase'),
        'mode_policeChase_desc',
      ),
    };

    final pillLabel = isCurrent
        ? (widget.lang == 'vi' ? 'ĐANG CHỌN' : 'SELECTED')
        : (widget.lang == 'vi' ? 'CHƠI NGAY' : 'PLAY');

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => widget.onSelectMode(mode),
      child: Container(
        width: cardWidth,
        constraints: BoxConstraints(minHeight: cardHeight),
        padding: EdgeInsets.fromLTRB(9.0 * ui, 8.0 * ui, 9.0 * ui, 7.0 * ui),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isCurrent
                ? const [Color(0xFFDDF0FE), Color(0xFFCBE7FC)]
                : const [Color(0xFFEDF6FD), Color(0xFFE2F0FB)],
          ),
          borderRadius: BorderRadius.circular(15.0 * ui),
          border: Border.all(
            color: isCurrent
                ? const Color(0xFF53AEEB)
                : const Color(0xFFA7D2F4),
            width: isCurrent ? 2.2 * ui : 1.5 * ui,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFB8D6EE),
              offset: Offset(0, 2.5 * ui),
              blurRadius: 0,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Top Row: 3D Icon on the left + Title & Description on the right (Image 2 "Squad 24" layout)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GameSpriteIcon(iconAsset, size: 30.0 * ui),
                SizedBox(width: 7.0 * ui),
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
                          fontSize: 11.8 * ui,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.2 * ui,
                          height: 1.15,
                        ),
                      ),
                      SizedBox(height: 2.0 * ui),
                      Text(
                        _tr(descKey),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: const Color(0xFF637F9A),
                          fontSize: 9.6 * ui,
                          fontWeight: FontWeight.w700,
                          height: 1.18,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 5.0 * ui),

            // Bottom Golden Mini-Pill Button (Exact Image 2 "140" gold pill inside Squad 24 card!)
            Center(
              child: Container(
                height: 24.0 * ui,
                width: cardWidth * 0.72,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: isCurrent
                        ? const [Color(0xFFFFE880), Color(0xFFF6C436)]
                        : const [Color(0xFFFFEE99), Color(0xFFF7D259)],
                  ),
                  borderRadius: BorderRadius.circular(8.0 * ui),
                  border: Border.all(
                    color: const Color(0xFFE0AC26),
                    width: 1.2 * ui,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFC9961A),
                      offset: Offset(0, 2.0 * ui),
                      blurRadius: 0,
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: Text(
                  pillLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: const Color(0xFF634206),
                    fontSize: 10.0 * ui,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.3 * ui,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStagesBrowser(double ui) {
    final districtStart = _selectedDistrict * 10 + 1;
    final districtStages = kCTStages
        .where((st) => st.id >= districtStart && st.id < districtStart + 10)
        .toList();
    final districtTheme = kCTThemes[_selectedDistrict];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // District Header Row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(
                '${_tr('district').toUpperCase()} ${_selectedDistrict + 1}: ${districtTheme.name}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: const Color(0xFF235687),
                  fontSize: 11.5 * ui,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.4 * ui,
                ),
              ),
            ),
            Text(
              '${_tr('stage_label')} $districtStart–${districtStart + 9}',
              style: TextStyle(
                color: const Color(0xFF6B849E),
                fontSize: 10.5 * ui,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        SizedBox(height: 6.0 * ui),

        // 10 Districts Horizontal Pill Bar
        SizedBox(
          height: 36.0 * ui,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: 10,
            separatorBuilder: (_, _) => SizedBox(width: 6.0 * ui),
            itemBuilder: (context, idx) {
              final theme = kCTThemes[idx];
              final selected = idx == _selectedDistrict;
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() => _selectedDistrict = idx),
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 11.0 * ui,
                    vertical: 5.0 * ui,
                  ),
                  decoration: BoxDecoration(
                    gradient: selected
                        ? const LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Color(0xFF6AC6F6), Color(0xFF39A5E3)],
                          )
                        : const LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Color(0xFFEDF6FD), Color(0xFFDCEBFA)],
                          ),
                    borderRadius: BorderRadius.circular(11.0 * ui),
                    border: Border.all(
                      color: selected
                          ? const Color(0xFF2884BE)
                          : const Color(0xFFA7D2F4),
                      width: 1.5 * ui,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '${idx * 10 + 1}–${(idx + 1) * 10} · ${theme.name}',
                    style: TextStyle(
                      color: selected
                          ? Colors.white
                          : const Color(0xFF285886),
                      fontSize: 11.0 * ui,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        SizedBox(height: 8.0 * ui),

        // 10 Stages Grid (2 columns × 5 rows) in Pastel Sky-Blue cards
        Expanded(
          child: GridView.builder(
            padding: EdgeInsets.only(bottom: 4.0 * ui),
            physics: const BouncingScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 7.0 * ui,
              crossAxisSpacing: 7.0 * ui,
              mainAxisExtent: 56.0 * ui,
            ),
            itemCount: districtStages.length,
            itemBuilder: (context, idx) {
              final st = districtStages[idx];
              return _buildStageTile(st, ui);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildStageTile(
    CTStageDefinition st,
    double ui,
  ) {
    final isCurrent =
        widget.state.mode == CTGameMode.campaign &&
        widget.state.stageId == st.id;
    final isCleared = widget.clearedStages.contains(st.id);
    final hasPolice = st.queue.contains('police');
    final hasExit = st.exit != 'none';
    final isFig8 =
        st.shape == CTRoadShape.figure8 || st.shape == CTRoadShape.figure8_90;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => widget.onSelectStage(st.id),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 8.0 * ui, vertical: 5.0 * ui),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isCurrent
                ? const [Color(0xFFFFF3C4), Color(0xFFFFE48F)]
                : const [Color(0xFFEDF6FD), Color(0xFFE0EFFB)],
          ),
          borderRadius: BorderRadius.circular(13.0 * ui),
          border: Border.all(
            color: isCurrent
                ? const Color(0xFFE6A817)
                : isCleared
                ? const Color(0xFF34C77B)
                : const Color(0xFFA5D1F3),
            width: isCurrent ? 2.2 * ui : 1.5 * ui,
          ),
          boxShadow: [
            BoxShadow(
              color: isCurrent
                  ? const Color(0xFFD49B1A)
                  : const Color(0xFFB7D5ED),
              offset: Offset(0, 2.5 * ui),
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
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: isCleared
                      ? const [Color(0xFF5CE69B), Color(0xFF2BB66E)]
                      : st.isBoss
                      ? const [Color(0xFFFFE270), Color(0xFFF5B822)]
                      : const [Color(0xFF72CAFA), Color(0xFF3DA6E3)],
                ),
                borderRadius: BorderRadius.circular(9.0 * ui),
              ),
              alignment: Alignment.center,
              child: Text(
                '${st.id}',
                style: TextStyle(
                  color: st.isBoss && !isCleared
                      ? const Color(0xFF5E3C04)
                      : Colors.white,
                  fontSize: 13.0 * ui,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            SizedBox(width: 7.0 * ui),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (st.isBoss) ...[
                        GameSpriteIcon(GameIcons.modeBossRush, size: 13.0 * ui),
                        SizedBox(width: 3.0 * ui),
                      ],
                      Expanded(
                        child: Text(
                          st.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: const Color(0xFF1D4D7A),
                            fontSize: 11.5 * ui,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 2.0 * ui),
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          '${st.queue.length} cars',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: const Color(0xFF637F9A),
                            fontSize: 9.8 * ui,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (hasExit) ...[
                        SizedBox(width: 2.5 * ui),
                        GameSpriteIcon(GameIcons.carGreenExit, size: 11.0 * ui),
                      ],
                      if (hasPolice) ...[
                        SizedBox(width: 2.0 * ui),
                        GameSpriteIcon(
                          GameIcons.modePoliceChase,
                          size: 11.0 * ui,
                        ),
                      ],
                      if (isFig8) ...[
                        SizedBox(width: 2.0 * ui),
                        GameSpriteIcon(GameIcons.modeEndless, size: 11.0 * ui),
                      ],
                      if (!st.clockwise) ...[
                        SizedBox(width: 2.0 * ui),
                        Text(
                          '↺',
                          style: TextStyle(
                            color: const Color(0xFF2B7AB8),
                            fontSize: 10.0 * ui,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            if (isCleared)
              Icon(
                Icons.check_circle_rounded,
                color: const Color(0xFF28B46B),
                size: 16.0 * ui,
              ),
          ],
        ),
      ),
    );
  }
}
