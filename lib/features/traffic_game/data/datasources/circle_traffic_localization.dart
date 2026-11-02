import '../../domain/entities/circle_traffic_models.dart';

class CTStrings {
  static String tr(
    String key, {
    String lang = 'vi',
    Map<String, String>? params,
  }) {
    var val = CTLocalization.t(key, lang);
    if (params != null) {
      params.forEach((k, v) {
        val = val.replaceAll('{$k}', v);
      });
    }
    return val;
  }
}

class CTLocalization {
  static const Map<String, String> languages = {
    'vi': '🇻🇳 Tiếng Việt',
    'en': '🇺🇸 English',
    'ja': '🇯🇵 日本語',
  };

  static const Map<String, Map<String, String>> _dict = {
    'en': {
      'gameTitle': 'CIRCLE TRAFFIC 3D',
      'campaign': 'CAMPAIGN',
      'campaignSub': '100 Levels • 10 Districts',
      'endless': 'ENDLESS LOOP',
      'endlessSub': 'Morphing Roads • High Score',
      'timeAttack': 'TIME ATTACK',
      'timeAttackSub': '60s Clock • +1.2s Per Merge',
      'rushHour': 'RUSH HOUR',
      'rushHourSub': 'Speed Waves • Heavy Vehicles',
      'bossRush': 'BOSS RUSH',
      'bossRushSub': '10 Boss Stages Back-to-Back',
      'policeChase': 'POLICE PATROL',
      'policeChaseSub': 'Convert & Clear Jammed Rings',
      'mode_campaign': 'Campaign (100 Stages)',
      'mode_campaign_desc': '100 hand-authored levels across 10 districts',
      'mode_endless': 'Endless Loop',
      'mode_endless_desc': 'Infinite traffic & morphing 3D road shapes',
      'mode_timeAttack': 'Time Attack',
      'mode_timeAttack_desc': '60s race — merges & police adds bonus time',
      'mode_rushHour': 'Rush Hour',
      'mode_rushHour_desc': 'Pulsing speed waves & heavy trucks/buses',
      'mode_bossRush': 'Boss Rush',
      'mode_bossRush_desc': 'All 10 Boss Stages (10..100) back-to-back',
      'mode_policeChase': 'Police Patrol',
      'mode_policeChase_desc': 'Use Police & Green cars to clear jams',
      'modes_and_stages': 'Modes & 100 Levels',
      'select_stage': 'SELECT STAGE',
      'district': 'DISTRICT',
      'stage_label': 'STAGE',
      'clean_merges': 'CLEAN\nMERGES',
      'queue_left': 'CARS LEFT',
      'time_left': 'TIME LEFT',
      'wave_label': 'RUSH WAVE',
      'jam_cleared': 'CONVERTED',
      'sound_on': 'SOUND ON',
      'muted': 'MUTED',
      'release_car': 'Release car',
      'stopped': 'Traffic stopped',
      'lining_up': 'Next car…',
      'one_tap': 'ONE TAP · ONE CAR',
      'next_car_label': 'NEXT',
      'role_police': 'POLICE CONVERTER',
      'role_green': 'GREEN EXIT CAR',
      'find_gap': 'Find a gap.\nLet it roll.',
      'keep_flowing': 'Keep it flowing.\nTraffic’s picking up.',
      'police_convert_hint':
          'Police Car ready! Converts the car ahead into a Green Exit car.',
      'green_exit_hint':
          'Green Exit Car ready! Automatically exits at the glowing green ramp.',
      'booster_slowmo': 'Slow-Mo',
      'booster_zap': 'Zap Clear',
      'stage_cleared': 'Stage Cleared!',
      'stage_cleared_sub': 'Smooth driving! Ready for the next intersection.',
      'victory_title': 'Grand Victory!',
      'victory_sub': 'You conquered every traffic challenge!',
      'next_stage': 'Next Stage',
      'play_again': 'Play Again',
      'run_ended': 'RUN ENDED',
      'traffic_jam': 'Traffic jam!',
      'traffic_jam_sub': 'A little more room next time.',
      'time_up_title': 'Time’s Up!',
      'time_up_sub': 'Keep merging quickly to extend the clock!',
      'try_again': 'Try again',
      'smooth_merge': 'Smooth merge!',
      'close': 'CLOSE',
    },
    'vi': {
      'gameTitle': 'VÒNG QUAY GIAO THÔNG 3D',
      'campaign': 'CHIẾN DỊCH',
      'campaignSub': '100 Màn Chơi • 10 Khu Vực',
      'endless': 'CHẾ ĐỘ VÔ TẬN',
      'endlessSub': 'Đường Biến Đổi • Đua Kỷ Lục',
      'timeAttack': 'CHẠY ĐUA THỜI GIAN',
      'timeAttackSub': '60 Giây • +1.2s Mỗi Xe',
      'rushHour': 'GIỜ CAO ĐIỂM',
      'rushHourSub': 'Sóng Tốc Độ • Xe Tải & Buýt',
      'bossRush': 'ĐẤU TRÙM LIÊN HOÀN',
      'bossRushSub': 'Chinh Phục 10 Màn Boss',
      'policeChase': 'CẢNH SÁT MỞ ĐƯỜNG',
      'policeChaseSub': 'Dẫn Đoàn Giải Tỏa Kẹt Xe',
      'mode_campaign': 'Chiến Dịch (100 Màn)',
      'mode_campaign_desc': '100 màn chơi thiết kế riêng qua 10 khu vực',
      'mode_endless': 'Vòng Lặp Vô Tận',
      'mode_endless_desc': 'Đường đua 3D tự biến đổi hình dạng mỗi 10 xe',
      'mode_timeAttack': 'Chạy Đua Thời Gian',
      'mode_timeAttack_desc': '60 giây nghẹt thở — cộng thêm giờ khi nhập làn',
      'mode_rushHour': 'Giờ Cao Điểm',
      'mode_rushHour_desc': 'Sóng tốc độ nhanh chậm & đoàn xe buýt, xe tải',
      'mode_bossRush': 'Đấu Trùm Liên Hoàn',
      'mode_bossRush_desc': 'Thử thách liên tiếp 10 màn Boss (Màn 10..100)',
      'mode_policeChase': 'Cảnh Sát Mở Đường',
      'mode_policeChase_desc': 'Dùng xe Cảnh Sát & Xe Xanh giải tỏa vòng xoay',
      'modes_and_stages': 'Chế Độ & 100 Màn',
      'select_stage': 'CHỌN MÀN CHƠI',
      'district': 'KHU VỰC',
      'stage_label': 'MÀN',
      'clean_merges': 'NHẬP LÀN\nAN TOÀN',
      'queue_left': 'XE CÒN LẠI',
      'time_left': 'THỜI GIAN',
      'wave_label': 'ĐỢT CAO ĐIỂM',
      'jam_cleared': 'ĐÃ GIẢI TỎA',
      'sound_on': 'BẬT TIẾNG',
      'muted': 'TẮT TIẾNG',
      'release_car': 'Phóng xe',
      'stopped': 'Đã dừng xe',
      'lining_up': 'Xe tiếp…',
      'one_tap': 'MỘT CHẠM · MỘT XE',
      'next_car_label': 'TIẾP THEO',
      'role_police': 'XE CẢNH SÁT',
      'role_green': 'XE THOÁT XANH',
      'find_gap': 'Canh khoảng trống.\nChạm để nhập làn.',
      'keep_flowing': 'Giữ nhịp độ.\nGiao thông đang nhanh hơn.',
      'police_convert_hint':
          'Xe Cảnh Sát sẵn sàng! Biến xe phía trước thành Xe Xanh thoát ra ngoài.',
      'green_exit_hint':
          'Xe Xanh sẵn sàng! Tự động rẽ ra ở làn đường phát sáng màu xanh.',
      'booster_slowmo': 'Làm Chậm',
      'booster_zap': 'Dọn Xe',
      'stage_cleared': 'Qua Màn Thành Công!',
      'stage_cleared_sub': 'Tay lái lụa! Sẵn sàng cho thử thách tiếp theo.',
      'victory_title': 'Chiến Thắng Tuyệt Đối!',
      'victory_sub': 'Bạn đã chinh phục toàn bộ thử thách giao thông!',
      'next_stage': 'Màn tiếp theo',
      'play_again': 'Chơi lại',
      'run_ended': 'KẾT THÚC LƯỢT',
      'traffic_jam': 'Kẹt xe rồi!',
      'traffic_jam_sub': 'Canh khoảng trống rộng hơn ở lượt sau nhé.',
      'time_up_title': 'Hết Giờ!',
      'time_up_sub': 'Nhập làn liên tục để được cộng thêm thời gian!',
      'try_again': 'Thử lại',
      'smooth_merge': 'Nhập làn mượt!',
      'close': 'ĐÓNG',
    },
    'ja': {
      'gameTitle': 'サークルトラフィック 3D',
      'campaign': 'キャンペーン',
      'campaignSub': '全100ステージ • 10エリア',
      'endless': 'エンドレス',
      'endlessSub': '変化する道路 • ハイスコア挑戦',
      'timeAttack': 'タイムアタック',
      'timeAttackSub': '60秒制限 • 合流で+1.2秒',
      'rushHour': 'ラッシュアワー',
      'rushHourSub': '速度変化 • 大型車両ラッシュ',
      'bossRush': 'ボスラッシュ',
      'bossRushSub': '全10ボスステージ連続挑戦',
      'policeChase': 'パトカー誘導',
      'policeChaseSub': 'パトカーで渋滞を解消せよ',
      'mode_campaign': 'キャンペーン (全100面)',
      'mode_campaign_desc': '10のエリアに広がる100種類のステージ',
      'mode_endless': 'エンドレスループ',
      'mode_endless_desc': '10台合流するごとに3Dコースが変形',
      'mode_timeAttack': 'タイムアタック',
      'mode_timeAttack_desc': '制限時間60秒 — 合流と誘導で残り時間プラス',
      'mode_rushHour': 'ラッシュアワー',
      'mode_rushHour_desc': '速度の波と大型バス・トラックのラッシュ',
      'mode_bossRush': 'ボスラッシュ',
      'mode_bossRush_desc': '全10ボスステージ(10〜100)に連続挑戦',
      'mode_policeChase': 'パトカー誘導',
      'mode_policeChase_desc': 'パトカーと緑の車で渋滞を一掃しよう',
      'modes_and_stages': 'モード＆100ステージ',
      'select_stage': 'ステージ選択',
      'district': 'エリア',
      'stage_label': 'ステージ',
      'clean_merges': 'クリーン\nマージ',
      'queue_left': '残り台数',
      'time_left': '残り時間',
      'wave_label': 'ウェーブ',
      'jam_cleared': '誘導完了',
      'sound_on': 'サウンド ON',
      'muted': 'ミュート',
      'release_car': '発進する',
      'stopped': 'ストップ',
      'lining_up': '準備中…',
      'one_tap': 'ワンタップで発進',
      'next_car_label': '次車両',
      'role_police': 'パトカー',
      'role_green': '脱出グリーン車',
      'find_gap': '隙間を見つけて\nタップで合流！',
      'keep_flowing': 'いいリズム！\nペースアップ中。',
      'police_convert_hint': 'パトカー待機中！前の車を緑の車に変えて出口へ誘導します。',
      'green_exit_hint': '緑の車待機中！緑色に光る出口レーンから自動で脱出します。',
      'booster_slowmo': 'スロー',
      'booster_zap': '車両一掃',
      'stage_cleared': 'ステージクリア！',
      'stage_cleared_sub': 'ナイスドライブ！次のステージへ進もう。',
      'victory_title': '完全制覇！',
      'victory_sub': 'すべてのステージをクリアしました！',
      'next_stage': '次のステージ',
      'play_again': 'もう一度遊ぶ',
      'run_ended': 'ラン終了',
      'traffic_jam': 'クラッシュ！',
      'traffic_jam_sub': 'もう少し広い隙間を狙ってみよう。',
      'time_up_title': 'タイムアップ！',
      'time_up_sub': '素早く合流して残り時間を増やそう！',
      'try_again': 'リトライ',
      'smooth_merge': 'ナイス合流！',
      'close': '閉じる',
    },
  };

  static String t(String key, String lang) {
    return _dict[lang]?[key] ?? _dict['en']?[key] ?? key;
  }

  static String modeTitle(CTGameMode mode, String lang) {
    switch (mode) {
      case CTGameMode.campaign:
        return t('campaign', lang);
      case CTGameMode.endless:
        return t('endless', lang);
      case CTGameMode.timeAttack:
        return t('timeAttack', lang);
      case CTGameMode.rushHour:
        return t('rushHour', lang);
      case CTGameMode.bossRush:
        return t('bossRush', lang);
      case CTGameMode.policeChase:
        return t('policeChase', lang);
    }
  }
}
