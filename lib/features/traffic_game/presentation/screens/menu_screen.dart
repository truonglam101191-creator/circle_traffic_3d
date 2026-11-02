import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../data/datasources/circle_traffic_localization.dart';
import '../../data/datasources/circle_traffic_stages.dart';
import '../../data/datasources/circle_traffic_themes.dart';
import '../../domain/entities/circle_traffic_models.dart';
import '../../domain/entities/game_traffic_state.dart';

/// Dedicated full-screen Main Menu page styled after the original Circle Traffic 3D
/// aesthetic (sunset sky header, cream-bordered plum panels, tactile 3D buttons).
///
/// Uses a clean 2-tab segmented card ("6 Chế Độ Chơi" / "100 Màn Chơi") so mode
/// cards never truncate and stage cards never overflow or get cut off at the bottom.
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
        final ui = (stageW / 390.0).clamp(0.86, 1.32);
        final compactH = stageH < 740;

        final safeTop = math.max(viewPadding.top + 8.0, 14.0 * ui);
        final safeBottom = math.max(viewPadding.bottom + 10.0, 14.0 * ui);
        final safeLeft = math.max(viewPadding.left + 14.0 * ui, 14.0 * ui);
        final safeRight = math.max(viewPadding.right + 14.0 * ui, 14.0 * ui);

        final stg = widget.state.stage;
        final stgId = stg?.id ?? widget.state.stageId;
        final stgName = stg?.name ?? 'Stage $stgId';
        final currentModeSub = switch (widget.state.mode) {
          CTGameMode.campaign =>
            '${_tr('mode_campaign')} · ${_tr('stage_label')} $stgId: $stgName',
          CTGameMode.endless =>
            '${_tr('mode_endless')} · ${_tr('mode_endless_desc')}',
          CTGameMode.timeAttack =>
            '${_tr('mode_timeAttack')} · ${_tr('mode_timeAttack_desc')}',
          CTGameMode.rushHour =>
            '${_tr('mode_rushHour')} · ${_tr('mode_rushHour_desc')}',
          CTGameMode.bossRush =>
            '${_tr('mode_bossRush')} · ${_tr('stage_label')} $stgId',
          CTGameMode.policeChase =>
            '${_tr('mode_policeChase')} · ${_tr('mode_policeChase_desc')}',
        };

        final logoHeight = compactH ? 84.0 * ui : 104.0 * ui;

        return Container(
          // Soft top tint lets the sunset sky backdrop shine behind the Crown Logo
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0x38281536),
                Color(0xB82E193C),
                Color(0xEB261433),
              ],
              stops: [0.0, 0.34, 1.0],
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
                constraints: BoxConstraints(maxWidth: 520.0 * ui),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 1. Uniform Top Bar: Trophy Progress + Language + Sound
                    _buildTopBar(ui),
                    SizedBox(height: compactH ? 6.0 * ui : 10.0 * ui),

                    // 2. Clean Crown Logo over Sunset Sky (zero ghost HUD behind it)
                    Center(
                      child: SizedBox(
                        height: logoHeight,
                        child: const Image(
                          image: ResizeImage(
                            AssetImage('assets/images/logo.png'),
                            width: 520,
                          ),
                          fit: BoxFit.contain,
                          gaplessPlayback: true,
                          filterQuality: FilterQuality.medium,
                        ),
                      ),
                    ),
                    SizedBox(height: compactH ? 8.0 * ui : 12.0 * ui),

                    // 3. Tactile 3D Gold Hero Play Button (matches original Release Car button)
                    _buildHeroPlayButton(ui, currentModeSub),
                    SizedBox(height: compactH ? 10.0 * ui : 14.0 * ui),

                    // 4. Framed Game Card containing Segmented Tabs + Content
                    Expanded(
                      child: _buildFramedMenuPanel(ui),
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
    final pillHeight = 44.0 * ui;
    return Row(
      children: [
        // Stage Clear Progress Pill
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => setState(() => _activeTab = 1),
          child: Container(
            height: pillHeight,
            padding: EdgeInsets.symmetric(horizontal: 12.0 * ui),
            decoration: BoxDecoration(
              color: const Color(0xF0482E52),
              borderRadius: BorderRadius.circular(15.0 * ui),
              border: Border.all(
                color: const Color(0xFFFFF0CA),
                width: 2.2 * ui,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF2B1733),
                  offset: Offset(0, 4.0 * ui),
                  blurRadius: 0,
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.emoji_events_rounded,
                  size: 18.0 * ui,
                  color: const Color(0xFFFFD34B),
                ),
                SizedBox(width: 6.0 * ui),
                Text(
                  '${widget.clearedStages.length}/100',
                  style: TextStyle(
                    color: const Color(0xFFFFF5DF),
                    fontSize: 13.0 * ui,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (widget.bestEndlessScore > 0) ...[
                  SizedBox(width: 8.0 * ui),
                  Text(
                    '· ♾️ ${widget.bestEndlessScore}',
                    style: TextStyle(
                      color: const Color(0xFF52FFA8),
                      fontSize: 12.0 * ui,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
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
            constraints: BoxConstraints(minWidth: 58.0 * ui),
            padding: EdgeInsets.symmetric(horizontal: 11.0 * ui),
            decoration: BoxDecoration(
              color: const Color(0xF0482E52),
              borderRadius: BorderRadius.circular(15.0 * ui),
              border: Border.all(
                color: const Color(0xFFFFF0CA),
                width: 2.2 * ui,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF2B1733),
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
                  size: 16.0 * ui,
                  color: const Color(0xFFFFD34B),
                ),
                SizedBox(width: 5.0 * ui),
                Text(
                  widget.lang.toUpperCase(),
                  style: TextStyle(
                    color: const Color(0xFFFFF5DF),
                    fontSize: 12.5 * ui,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5 * ui,
                  ),
                ),
              ],
            ),
          ),
        ),
        SizedBox(width: 8.0 * ui),
        // Sound Pill
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onToggleSound,
          child: Container(
            height: pillHeight,
            padding: EdgeInsets.symmetric(horizontal: 12.0 * ui),
            decoration: BoxDecoration(
              color: widget.muted
                  ? const Color(0xF05E3E5C)
                  : const Color(0xF07E549E),
              borderRadius: BorderRadius.circular(15.0 * ui),
              border: Border.all(
                color: const Color(0xFFFFF0CA),
                width: 2.2 * ui,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF2B1733),
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
                  widget.muted
                      ? Icons.volume_off_rounded
                      : Icons.volume_up_rounded,
                  size: 18.0 * ui,
                  color: const Color(0xFFFFF5DF),
                ),
                SizedBox(width: 5.0 * ui),
                Text(
                  widget.muted ? _tr('sound_off') : _tr('sound_on'),
                  style: TextStyle(
                    color: const Color(0xFFFFF5DF),
                    fontSize: 11.5 * ui,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.3 * ui,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeroPlayButton(double ui, String currentModeSub) {
    final playNowLabel = switch (widget.lang) {
      'vi' => 'VÀO CHƠI NGAY',
      'ja' => '今すぐプレイ',
      _ => 'PLAY NOW',
    };

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onResumeOrPlay,
      child: Container(
        height: 68.0 * ui,
        padding: EdgeInsets.symmetric(horizontal: 14.0 * ui),
        decoration: BoxDecoration(
          color: const Color(0xFFFFCA3A),
          borderRadius: BorderRadius.circular(20.0 * ui),
          border: Border.all(
            color: const Color(0xFFFFF3C4),
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
        child: Row(
          children: [
            Container(
              width: 44.0 * ui,
              height: 44.0 * ui,
              decoration: BoxDecoration(
                color: const Color(0xFF4B2C4E),
                borderRadius: BorderRadius.circular(14.0 * ui),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF2B1730),
                    offset: Offset(0, 2.5 * ui),
                    blurRadius: 0,
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Icon(
                Icons.play_arrow_rounded,
                size: 28.0 * ui,
                color: const Color(0xFFFFD34B),
              ),
            ),
            SizedBox(width: 12.0 * ui),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    playNowLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: const Color(0xFF3F2341),
                      fontSize: 18.0 * ui,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.2 * ui,
                      height: 1.1,
                    ),
                  ),
                  SizedBox(height: 3.0 * ui),
                  Text(
                    currentModeSub.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: const Color(0xFF613B34),
                      fontSize: 11.0 * ui,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.3 * ui,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: 8.0 * ui),
            Container(
              width: 38.0 * ui,
              height: 38.0 * ui,
              decoration: BoxDecoration(
                color: const Color(0xFFAA75C8),
                borderRadius: BorderRadius.circular(12.0 * ui),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF77475F),
                    offset: Offset(0, 2.5 * ui),
                    blurRadius: 0,
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Icon(
                Icons.arrow_forward_rounded,
                size: 20.0 * ui,
                color: const Color(0xFFFFF5DD),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFramedMenuPanel(double ui) {
    final modesHeading = switch (widget.lang) {
      'vi' => 'CHỌN CHẾ ĐỘ CHƠI (6 MODES)',
      'ja' => 'ゲームモードを選択 (6 MODES)',
      _ => 'SELECT GAME MODE (6 MODES)',
    };
    final stagesTabTitle = switch (widget.lang) {
      'vi' => '100 MÀN CHƠI (${widget.clearedStages.length}/100)',
      'ja' => '100 ステージ (${widget.clearedStages.length}/100)',
      _ => '100 STAGES (${widget.clearedStages.length}/100)',
    };

    return Container(
      padding: EdgeInsets.fromLTRB(
        12.0 * ui,
        12.0 * ui,
        12.0 * ui,
        12.0 * ui,
      ),
      decoration: BoxDecoration(
        color: const Color(0xF53B2446),
        borderRadius: BorderRadius.circular(24.0 * ui),
        border: Border.all(
          color: const Color(0xFFFFF0CA),
          width: 2.6 * ui,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E0F26),
            offset: Offset(0, 6.0 * ui),
            blurRadius: 0,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Segmented 2-Tab Bar ("6 Chế Độ" | "100 Màn Chơi")
          Container(
            padding: EdgeInsets.all(4.0 * ui),
            decoration: BoxDecoration(
              color: const Color(0xFF2B1834),
              borderRadius: BorderRadius.circular(16.0 * ui),
              border: Border.all(
                color: const Color(0x44FFF0CA),
                width: 1.5 * ui,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildSegmentTabButton(
                    ui: ui,
                    selected: _activeTab == 0,
                    icon: Icons.sports_esports_rounded,
                    label: modesHeading,
                    onTap: () => setState(() => _activeTab = 0),
                  ),
                ),
                SizedBox(width: 6.0 * ui),
                Expanded(
                  child: _buildSegmentTabButton(
                    ui: ui,
                    selected: _activeTab == 1,
                    icon: Icons.map_rounded,
                    label: stagesTabTitle,
                    onTap: () => setState(() => _activeTab = 1),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 10.0 * ui),

          // Active Tab Body
          Expanded(
            child: _activeTab == 0
                ? _buildSixModesGrid(ui)
                : _buildStagesBrowser(ui),
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentTabButton({
    required double ui,
    required bool selected,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        constraints: BoxConstraints(minHeight: 40.0 * ui),
        padding: EdgeInsets.symmetric(
          horizontal: 8.0 * ui,
          vertical: 6.0 * ui,
        ),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF6B427E) : Colors.transparent,
          borderRadius: BorderRadius.circular(12.0 * ui),
          border: selected
              ? Border.all(color: const Color(0xFFFFD34B), width: 1.8 * ui)
              : null,
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: const Color(0xFF22112B),
                    offset: Offset(0, 2.5 * ui),
                    blurRadius: 0,
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 15.0 * ui,
              color: selected
                  ? const Color(0xFFFFD34B)
                  : const Color(0xFFD6B8E0),
            ),
            SizedBox(width: 5.0 * ui),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: selected
                      ? const Color(0xFFFFF5DF)
                      : const Color(0xFFD6B8E0),
                  fontSize: 11.0 * ui,
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
        // Dynamically size card height to fit 3 rows comfortably without scrolling on tall screens
        final rows = (CTGameMode.values.length / cols).ceil();
        final availableH = gridConstraints.maxHeight;
        final idealCardH = ((availableH - spacing * (rows - 1)) / rows).clamp(
          96.0 * ui,
          132.0 * ui,
        );

        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Wrap(
            spacing: spacing,
            runSpacing: spacing,
            children: [
              for (final mode in CTGameMode.values)
                _buildModeCard(mode, ui, cardW, idealCardH),
            ],
          ),
        );
      },
    );
  }

  Widget _buildModeCard(
    CTGameMode mode,
    double ui,
    double cardWidth,
    double cardHeight,
  ) {
    final isCurrent = widget.state.mode == mode;
    final (title, descKey, color, icon) = switch (mode) {
      CTGameMode.campaign => (
        switch (widget.lang) {
          'vi' => 'Chiến Dịch 100 Màn',
          'ja' => 'キャンペーン (100ステージ)',
          _ => 'Campaign (100 Stages)',
        },
        'mode_campaign_desc',
        const Color(0xFFFFC83E),
        Icons.map_rounded,
      ),
      CTGameMode.endless => (
        _tr('mode_endless'),
        'mode_endless_desc',
        const Color(0xFF52FFA8),
        Icons.all_inclusive_rounded,
      ),
      CTGameMode.timeAttack => (
        _tr('mode_timeAttack'),
        'mode_timeAttack_desc',
        const Color(0xFF38BDF8),
        Icons.timer_rounded,
      ),
      CTGameMode.rushHour => (
        _tr('mode_rushHour'),
        'mode_rushHour_desc',
        const Color(0xFFFF9F43),
        Icons.speed_rounded,
      ),
      CTGameMode.bossRush => (
        _tr('mode_bossRush'),
        'mode_bossRush_desc',
        const Color(0xFFF472B6),
        Icons.workspace_premium_rounded,
      ),
      CTGameMode.policeChase => (
        _tr('mode_policeChase'),
        'mode_policeChase_desc',
        const Color(0xFF7DD3FC),
        Icons.local_police_rounded,
      ),
    };

    final activeBadgeText = switch (widget.lang) {
      'vi' => 'ĐANG CHỌN',
      'ja' => '選択中',
      _ => 'ACTIVE',
    };
    final playBadgeText = switch (widget.lang) {
      'vi' => 'CHƠI ▶',
      'ja' => 'プレイ ▶',
      _ => 'PLAY ▶',
    };

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => widget.onSelectMode(mode),
      child: Container(
        width: cardWidth,
        constraints: BoxConstraints(minHeight: cardHeight),
        padding: EdgeInsets.symmetric(
          horizontal: 10.0 * ui,
          vertical: 9.0 * ui,
        ),
        decoration: BoxDecoration(
          color: isCurrent ? const Color(0xFF5D386E) : const Color(0xFF4A2E57),
          borderRadius: BorderRadius.circular(16.0 * ui),
          border: Border.all(
            color: isCurrent ? color : const Color(0x88FFF0CA),
            width: isCurrent ? 2.6 * ui : 1.8 * ui,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF25132E),
              offset: Offset(0, 3.5 * ui),
              blurRadius: 0,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Row 1: Colored 3D Icon Box + Status Pill (leaves Row 2 full width for Title!)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 30.0 * ui,
                  height: 30.0 * ui,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(9.0 * ui),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0x44000000),
                        offset: Offset(0, 2.0 * ui),
                        blurRadius: 0,
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    icon,
                    size: 17.0 * ui,
                    color: const Color(0xFF24132C),
                  ),
                ),
                SizedBox(width: 4.0 * ui),
                if (mode == CTGameMode.campaign)
                  Flexible(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => setState(() => _activeTab = 1),
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 6.0 * ui,
                          vertical: 3.5 * ui,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF3B2247),
                          borderRadius: BorderRadius.circular(8.0 * ui),
                          border: Border.all(
                            color: color,
                            width: 1.4 * ui,
                          ),
                        ),
                        child: Text(
                          widget.lang == 'vi' ? '🗺️ Chọn màn' : '🗺️ Stages',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: color,
                            fontSize: 9.0 * ui,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                  )
                else
                  Flexible(
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 6.0 * ui,
                        vertical: 3.0 * ui,
                      ),
                      decoration: BoxDecoration(
                        color: isCurrent
                            ? color.withValues(alpha: 0.22)
                            : const Color(0xFF392244),
                        borderRadius: BorderRadius.circular(8.0 * ui),
                        border: Border.all(
                          color: isCurrent ? color : const Color(0x55FFF0CA),
                          width: 1.2 * ui,
                        ),
                      ),
                      child: Text(
                        isCurrent ? activeBadgeText : playBadgeText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isCurrent ? color : const Color(0xFFE7CEE9),
                          fontSize: 9.0 * ui,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.3 * ui,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            SizedBox(height: 6.0 * ui),

            // Row 2: Full-width Mode Title (never truncated!)
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: const Color(0xFFFFF5DF),
                fontSize: 13.0 * ui,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.2 * ui,
              ),
            ),
            SizedBox(height: 3.0 * ui),

            // Row 3: Mode Description
            Text(
              _tr(descKey),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: const Color(0xFFE5C9EA),
                fontSize: 10.5 * ui,
                fontWeight: FontWeight.w600,
                height: 1.22,
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
                  color: districtTheme.accent,
                  fontSize: 12.0 * ui,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.4 * ui,
                ),
              ),
            ),
            Text(
              '${_tr('stage_label')} $districtStart–${districtStart + 9}',
              style: TextStyle(
                color: const Color(0xFFE7C3D2),
                fontSize: 11.0 * ui,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        SizedBox(height: 7.0 * ui),

        // 10 Districts Horizontal Pill Bar
        SizedBox(
          height: 40.0 * ui,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: 10,
            separatorBuilder: (_, _) => SizedBox(width: 7.0 * ui),
            itemBuilder: (context, idx) {
              final theme = kCTThemes[idx];
              final selected = idx == _selectedDistrict;
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() => _selectedDistrict = idx),
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 12.0 * ui,
                    vertical: 6.0 * ui,
                  ),
                  decoration: BoxDecoration(
                    color: selected ? theme.accent : const Color(0xFF4D315B),
                    borderRadius: BorderRadius.circular(12.0 * ui),
                    border: Border.all(
                      color: selected
                          ? const Color(0xFFFFF5DF)
                          : theme.accent.withValues(alpha: 0.55),
                      width: 1.8 * ui,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF24132C),
                        offset: Offset(0, 2.5 * ui),
                        blurRadius: 0,
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '${idx * 10 + 1}–${(idx + 1) * 10} · ${theme.name}',
                    style: TextStyle(
                      color: selected
                          ? const Color(0xFF231429)
                          : const Color(0xFFFFF0D7),
                      fontSize: 11.5 * ui,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        SizedBox(height: 10.0 * ui),

        // 10 Stages Grid (2 columns × 5 rows) cleanly framed inside the panel
        Expanded(
          child: GridView.builder(
            padding: EdgeInsets.only(bottom: 4.0 * ui),
            physics: const BouncingScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 8.0 * ui,
              crossAxisSpacing: 8.0 * ui,
              mainAxisExtent: 58.0 * ui,
            ),
            itemCount: districtStages.length,
            itemBuilder: (context, idx) {
              final st = districtStages[idx];
              return _buildStageTile(st, districtTheme, ui);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildStageTile(
    CTStageDefinition st,
    CTGameThemeData theme,
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
        padding: EdgeInsets.symmetric(horizontal: 9.0 * ui, vertical: 6.0 * ui),
        decoration: BoxDecoration(
          color: isCurrent ? const Color(0xFF633C75) : const Color(0xFF4A2E57),
          borderRadius: BorderRadius.circular(14.0 * ui),
          border: Border.all(
            color: isCurrent
                ? const Color(0xFFFFD34B)
                : st.isBoss
                ? const Color(0xFFF472B6)
                : isCleared
                ? const Color(0xFF52FFA8)
                : const Color(0x77FFF0CA),
            width: isCurrent ? 2.5 * ui : 1.6 * ui,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF25132E),
              offset: Offset(0, 3.0 * ui),
              blurRadius: 0,
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 34.0 * ui,
              height: 34.0 * ui,
              decoration: BoxDecoration(
                color: isCleared
                    ? const Color(0xFF52FFA8)
                    : st.isBoss
                    ? const Color(0xFFFFD34B)
                    : theme.accent,
                borderRadius: BorderRadius.circular(10.0 * ui),
              ),
              alignment: Alignment.center,
              child: Text(
                '${st.id}',
                style: TextStyle(
                  color: const Color(0xFF23132B),
                  fontSize: 13.5 * ui,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            SizedBox(width: 8.0 * ui),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    st.isBoss ? '👑 ${st.name}' : st.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: const Color(0xFFFFF5DF),
                      fontSize: 12.0 * ui,
                      fontWeight: FontWeight.w900,
                    ),
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
                            color: const Color(0xFFDDC2E8),
                            fontSize: 10.5 * ui,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (hasExit) ...[
                        SizedBox(width: 4.0 * ui),
                        Text('🟢', style: TextStyle(fontSize: 9.5 * ui)),
                      ],
                      if (hasPolice) ...[
                        SizedBox(width: 3.0 * ui),
                        Text('🚓', style: TextStyle(fontSize: 9.5 * ui)),
                      ],
                      if (isFig8) ...[
                        SizedBox(width: 3.0 * ui),
                        Text(
                          '∞',
                          style: TextStyle(
                            color: const Color(0xFFFFD34B),
                            fontSize: 11.0 * ui,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                      if (!st.clockwise) ...[
                        SizedBox(width: 3.0 * ui),
                        Text(
                          '↺',
                          style: TextStyle(
                            color: const Color(0xFF7DD3FC),
                            fontSize: 11.0 * ui,
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
                color: const Color(0xFF52FFA8),
                size: 16.0 * ui,
              ),
          ],
        ),
      ),
    );
  }
}
