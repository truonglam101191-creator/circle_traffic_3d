import 'dart:math' as math;
import '../../data/datasources/circle_traffic_stages.dart';
import '../../data/datasources/circle_traffic_themes.dart';
import '../services/traffic_math_service.dart';
import 'circle_traffic_models.dart';

class CarModel {
  final int id;
  String path; // 'ring', 'ramp', 'exit', or 'waiting'
  double angle;
  double progress;
  double launchAge;
  double travel;
  double? mergeAge;
  final int colorIndex;

  // Extended Stage & Vehicle properties
  final CTVehicleType vehicleType;
  CTCarRole role;
  final bool isPlayer;
  final bool useStagePose;
  int customHexColor;

  // 2D stage path coordinates (720x1080 space)
  double px;
  double py;
  double pang;
  double zElevation;
  double alpha;

  // Loop / Entrance / Exit arc parameters
  double s0;
  double dm;
  double es;
  double xs;
  double exitAtD;
  double mergedT;
  bool counted;
  bool pendingConvert;
  double sirenTimer;
  double flashAmount;
  double targetY;

  CarModel({
    required this.id,
    this.path = 'ring',
    this.angle = 0.0,
    this.progress = 0.0,
    this.launchAge = 0.0,
    this.travel = 0.0,
    this.mergeAge,
    required this.colorIndex,
    this.vehicleType = CTVehicleType.car,
    this.role = CTCarRole.normal,
    this.isPlayer = false,
    this.useStagePose = false,
    this.customHexColor = 0,
    this.px = 360.0,
    this.py = 468.0,
    this.pang = -math.pi / 2,
    this.zElevation = 0.0,
    this.alpha = 1.0,
    this.s0 = 0.0,
    this.dm = 0.0,
    this.es = 0.0,
    this.xs = 0.0,
    this.exitAtD = 1e9,
    this.mergedT = -1.0,
    this.counted = false,
    this.pendingConvert = false,
    this.sirenTimer = 0.0,
    this.flashAmount = 0.0,
    this.targetY = 0.0,
  });

  CarModel clone() {
    return CarModel(
      id: id,
      path: path,
      angle: angle,
      progress: progress,
      launchAge: launchAge,
      travel: travel,
      mergeAge: mergeAge,
      colorIndex: colorIndex,
      vehicleType: vehicleType,
      role: role,
      isPlayer: isPlayer,
      useStagePose: useStagePose,
      customHexColor: customHexColor,
      px: px,
      py: py,
      pang: pang,
      zElevation: zElevation,
      alpha: alpha,
      s0: s0,
      dm: dm,
      es: es,
      xs: xs,
      exitAtD: exitAtD,
      mergedT: mergedT,
      counted: counted,
      pendingConvert: pendingConvert,
      sirenTimer: sirenTimer,
      flashAmount: flashAmount,
      targetY: targetY,
    );
  }

  CTVehicleSpec get spec => CTVehicles.get(vehicleType);

  /// 3D elevation (in meters) including figure-8 overpass bridge height.
  double get elevationY => TrafficMath.surfaceY + zElevation * 0.92;

  /// Length multiplier relative to standard car for 3D rendering.
  double get lengthScale {
    switch (vehicleType) {
      case CTVehicleType.mini:
        return 0.78;
      case CTVehicleType.car:
        return 1.0;
      case CTVehicleType.van:
        return 1.28;
      case CTVehicleType.truck:
        return 1.56;
      case CTVehicleType.bus:
        return 1.92;
    }
  }

  double get widthScale {
    switch (vehicleType) {
      case CTVehicleType.mini:
        return 0.92;
      case CTVehicleType.car:
        return 1.0;
      case CTVehicleType.van:
        return 1.06;
      case CTVehicleType.truck:
        return 1.12;
      case CTVehicleType.bus:
        return 1.14;
    }
  }

  ({double x, double z, double fx, double fz}) get pose {
    if (useStagePose) {
      return (
        x: CTDimensions.to3DX(px),
        z: CTDimensions.to3DZ(py),
        fx: math.cos(pang),
        fz: math.sin(pang),
      );
    }
    if (path == 'ramp') {
      return TrafficMath.approachPose(progress);
    }
    return TrafficMath.ringPose(angle);
  }
}

class GameTrafficState {
  final List<CarModel> cars;
  final List<CarModel> queue;
  final int nextId;
  final double cooldown;
  final double releaseDuration;
  final int cleanMerges;
  final ({int id, int serial, double x, double z})? lastMerge;
  final ({int id, int serial, double x, double z})? lastConversion;
  final bool crashed;
  final double crashTime;
  final ({double x, double z, List<int> ids})? impact;

  // Stage & Mode fields
  final bool useStagePaths;
  final CTGameMode mode;
  final int stageId;
  final CTStageDefinition? stage;
  final CTGameThemeData theme;
  final CTGamePath? loop;
  final CTGamePath? entrance;
  final CTGamePath? exit;
  final double exitDist;
  final double simT;
  final int playersTotal;
  final int playersDone;
  final bool stageCleared;
  final double clearTime;
  final bool timeUp;
  final double timeAttackTimer;
  final int modeScore;
  final int rushWave;
  final int bossRushIndex; // 0..9 for Boss stages 10..100
  final double slowMoTimer;
  final int slowMoCharges;
  final int zapCharges;
  final int conversionSerial;

  static final CTPose _mp = CTPose();

  GameTrafficState({
    required this.cars,
    this.queue = const [],
    required this.nextId,
    this.cooldown = 0.0,
    this.releaseDuration = TrafficMath.releaseCooldown,
    this.cleanMerges = 0,
    this.lastMerge,
    this.lastConversion,
    this.crashed = false,
    this.crashTime = 0.0,
    this.impact,
    this.useStagePaths = false,
    this.mode = CTGameMode.campaign,
    this.stageId = 1,
    this.stage,
    CTGameThemeData? theme,
    this.loop,
    this.entrance,
    this.exit,
    this.exitDist = 0.0,
    this.simT = 0.0,
    this.playersTotal = 0,
    this.playersDone = 0,
    this.stageCleared = false,
    this.clearTime = 0.0,
    this.timeUp = false,
    this.timeAttackTimer = 60.0,
    this.modeScore = 0,
    this.rushWave = 1,
    this.bossRushIndex = 0,
    this.slowMoTimer = 0.0,
    this.slowMoCharges = 2,
    this.zapCharges = 2,
    this.conversionSerial = 0,
  }) : theme = theme ?? kCTThemes.first;

  String get runPhase {
    if (crashed) {
      return crashTime < TrafficMath.failReveal ? 'crashing' : 'failed';
    }
    if (timeUp) {
      return 'failed';
    }
    if (stageCleared) {
      return clearTime < 0.55 ? 'clearing' : 'cleared';
    }
    return 'playing';
  }

  double get slowMoRemaining => slowMoTimer;
  int get initialQueueCount => playersTotal;
  double get timeRemaining => timeAttackTimer;
  int get waveNumber => rushWave;
  int get convertedCleared => conversionSerial;

  String get trackKey {
    if (!useStagePaths || stage == null || loop == null) {
      return 'classic_circle';
    }
    final shapeName = loop!.meta?.shape ?? stage!.shape.name;
    final cw = loop!.meta?.clockwise ?? stage!.clockwise;
    final ex = exit?.side ?? 'none';
    return '${shapeName}_${cw ? 'cw' : 'ccw'}_$ex';
  }

  /// Classic initializer (preserves unit test & original behavior).
  static GameTrafficState createInitial([List<double>? angles]) {
    TrafficMath.initialize();
    final initialAngles = angles ?? TrafficMath.initialAngles;
    final cars = <CarModel>[];
    for (int i = 0; i < initialAngles.length; i++) {
      cars.add(CarModel(
        id: i,
        path: 'ring',
        angle: TrafficMath.wrapAngle(initialAngles[i]),
        progress: 0.0,
        travel: 0.0,
        colorIndex: i % GameTheme.accentColors.length,
      ));
    }
    return GameTrafficState(
      cars: cars,
      nextId: initialAngles.length,
      cooldown: 0.0,
      releaseDuration: TrafficMath.releaseCooldown,
      cleanMerges: 0,
      crashed: false,
      crashTime: 0.0,
      useStagePaths: false,
    );
  }

  /// Creates a state for any of the 100 hand-authored stages or 6 game modes.
  static GameTrafficState createForStage(
    int stageId, {
    CTGameMode mode = CTGameMode.campaign,
    int bossRushIndex = 0,
  }) {
    TrafficMath.initialize();
    CTVehicles.applyScale(CTGameConfig.defaults.carScale);

    final clampedId = stageId.clamp(1, kCTStages.length);
    CTStageDefinition st = kCTStages[clampedId - 1];

    if (mode == CTGameMode.endless) {
      st = const CTStageDefinition(
        id: 101,
        name: 'Infinite Loop',
        shape: CTRoadShape.circle,
        speed: 158,
        exit: 'top',
        clockwise: false,
        queue: [
          'car',
          'mini',
          'green',
          'car',
          'police',
          'van',
          'car',
          'green',
        ],
        traffic: [
          CTTrafficEntry(type: CTVehicleType.car, at: 0.15),
          CTTrafficEntry(type: CTVehicleType.car, at: 0.48),
          CTTrafficEntry(type: CTVehicleType.van, at: 0.80),
        ],
        hint: 'Merge endlessly! Road morphs every 10 points.',
      );
    } else if (mode == CTGameMode.timeAttack) {
      st = const CTStageDefinition(
        id: 102,
        name: 'Time Attack 60s',
        shape: CTRoadShape.roundedSquare,
        speed: 166,
        exit: 'top',
        clockwise: false,
        queue: [
          'car',
          'green',
          'mini',
          'police',
          'car',
          'green',
          'van',
          'police',
        ],
        traffic: [
          CTTrafficEntry(type: CTVehicleType.car, at: 0.12),
          CTTrafficEntry(type: CTVehicleType.car, at: 0.38),
          CTTrafficEntry(
            type: CTVehicleType.car,
            at: 0.64,
            role: CTCarRole.green,
          ),
          CTTrafficEntry(type: CTVehicleType.car, at: 0.88),
        ],
        hint: 'Beat the 60s clock! Every merge & exit adds bonus time.',
      );
    } else if (mode == CTGameMode.rushHour) {
      st = const CTStageDefinition(
        id: 103,
        name: 'Rush Hour Chaos',
        shape: CTRoadShape.wideLoop,
        speed: 164,
        exit: 'right',
        clockwise: false,
        pulse: CTPulseConfig(amp: 0.22, period: 2.6),
        queue: [
          'mini',
          'car',
          'police',
          'van',
          'green',
          'truck',
          'police',
          'bus',
          'green',
        ],
        traffic: [
          CTTrafficEntry(type: CTVehicleType.bus, at: 0.10),
          CTTrafficEntry(type: CTVehicleType.car, at: 0.28),
          CTTrafficEntry(type: CTVehicleType.truck, at: 0.52),
          CTTrafficEntry(type: CTVehicleType.van, at: 0.76),
          CTTrafficEntry(type: CTVehicleType.mini, at: 0.90),
        ],
        hint: 'Watch the pulsing speed waves and heavy trucks & buses!',
      );
    } else if (mode == CTGameMode.bossRush) {
      final bossStageId = ((bossRushIndex.clamp(0, 9) + 1) * 10);
      st = kCTStages[bossStageId - 1];
    } else if (mode == CTGameMode.policeChase) {
      st = const CTStageDefinition(
        id: 105,
        name: 'Police Patrol',
        shape: CTRoadShape.oval,
        speed: 160,
        exit: 'top',
        clockwise: false,
        queue: [
          'police',
          'green',
          'police',
          'mini',
          'police',
          'green',
          'police',
          'car',
        ],
        traffic: [
          CTTrafficEntry(type: CTVehicleType.car, at: 0.08),
          CTTrafficEntry(type: CTVehicleType.van, at: 0.16),
          CTTrafficEntry(type: CTVehicleType.car, at: 0.28),
          CTTrafficEntry(type: CTVehicleType.truck, at: 0.42),
          CTTrafficEntry(type: CTVehicleType.car, at: 0.54),
          CTTrafficEntry(type: CTVehicleType.van, at: 0.68),
          CTTrafficEntry(type: CTVehicleType.car, at: 0.80),
          CTTrafficEntry(type: CTVehicleType.car, at: 0.91),
        ],
        hint: 'Use POLICE cars to convert & clear jammed traffic!',
      );
    }

    final theme = mode == CTGameMode.campaign || mode == CTGameMode.bossRush
        ? ctThemeForStage(st.id)
        : kCTThemes[mode.index % kCTThemes.length];

    const cfg = CTGameConfig.defaults;
    final loop = CTPathBuilder.cachedLoop(st.shape, st.clockwise);
    final ent = CTPathBuilder.cachedEntrance(
      st.shape,
      st.clockwise,
      cfg.queueOffset,
      cfg.launchDistance,
    );
    final exi = st.exit == 'none'
        ? null
        : CTPathBuilder.cachedExit(st.shape, st.exit, st.clockwise);

    final L = loop.len;
    final exitDist = exi != null
        ? ((exi.sExit - CTDimensions.mergeS) % L + L) % L
        : 0.0;

    final cars = <CarModel>[];
    final queue = <CarModel>[];
    int idCounter = 1;

    // 1. Populate initial ring traffic
    for (int i = 0; i < st.traffic.length; i++) {
      final tj = st.traffic[i];
      final trRole = tj.role;
      final s0 = (CTDimensions.mergeS + tj.at * L) % L;
      loop.pointAtInto(s0, _mp);
      final zElev = CTPathBuilder.getCarZ(s0, loop);

      double exitAtD = 1e9;
      if (trRole == CTCarRole.green && exi != null) {
        double g0 = ((exi.sExit - s0) % L + L) % L;
        if (g0 < CTDimensions.exitLeadMin) g0 += L;
        exitAtD = g0 + (tj.lap > 0 ? tj.lap * L : 0.0);
      }

      final colorIdx = (i * 2 + st.id) % GameTheme.accentHexColors.length;
      final hex = trRole == CTCarRole.green
          ? CTColors.greenHex
          : trRole == CTCarRole.police
              ? CTColors.policeBodyHex
              : GameTheme.accentHexColors[colorIdx];

      cars.add(CarModel(
        id: idCounter++,
        path: 'ring',
        colorIndex: colorIdx,
        vehicleType: tj.type,
        role: trRole,
        isPlayer: false,
        useStagePose: true,
        customHexColor: hex,
        px: _mp.x,
        py: _mp.y,
        pang: _mp.ang,
        zElevation: zElev,
        s0: s0,
        exitAtD: exitAtD,
        pendingConvert: trRole == CTCarRole.police,
      ));
    }

    // 2. Populate player launch queue
    for (int q = 0; q < st.queue.length; q++) {
      final tk = CTStageDefinition.parseQueueToken(st.queue[q]) ??
          const CTQueueToken(CTVehicleType.car, CTCarRole.normal);
      final colorIdx = (q * 3 + st.id) % GameTheme.accentHexColors.length;
      final hex = tk.role == CTCarRole.green
          ? CTColors.greenHex
          : tk.role == CTCarRole.police
              ? CTColors.policeBodyHex
              : CTColors.playerHexColors[colorIdx % CTColors.playerHexColors.length];

      queue.add(CarModel(
        id: idCounter++,
        path: 'waiting',
        colorIndex: colorIdx,
        vehicleType: tk.type,
        role: tk.role,
        isPlayer: true,
        useStagePose: true,
        customHexColor: hex,
      ));
    }

    _layoutStageQueue(queue, ent, snap: true);

    return GameTrafficState(
      cars: cars,
      queue: queue,
      nextId: idCounter,
      cooldown: 0.0,
      releaseDuration: 0.34,
      cleanMerges: 0,
      crashed: false,
      crashTime: 0.0,
      useStagePaths: true,
      mode: mode,
      stageId: st.id,
      stage: st,
      theme: theme,
      loop: loop,
      entrance: ent,
      exit: exi,
      exitDist: exitDist,
      simT: 0.0,
      playersTotal: queue.length,
      playersDone: 0,
      timeAttackTimer: 60.0,
      modeScore: 0,
      rushWave: 1,
      bossRushIndex: bossRushIndex,
    );
  }

  static void _layoutStageQueue(
    List<CarModel> queue,
    CTGamePath? ent, {
    required bool snap,
  }) {
    if (ent == null) return;
    final qX = ent.queueX;
    double y = ent.startY - 6.0;
    for (int i = 0; i < queue.length; i++) {
      final c = queue[i];
      if (i == 0) {
        y += c.spec.len / 2.0;
      } else {
        y += (queue[i - 1].spec.len / 2.0) + (c.spec.len / 2.0) + 18.0;
      }
      c.targetY = y;
      if (snap) {
        c.px = qX;
        c.py = y + 20.0;
        c.pang = -math.pi / 2;
      }
    }
  }

  bool get canRelease {
    if (crashed || timeUp || stageCleared || cooldown > 0) return false;
    if (useStagePaths && queue.isEmpty) return false;
    return true;
  }

  /// Releases the next car onto the approach ramp.
  GameTrafficState releaseCar(double speed) {
    if (!canRelease) return this;

    if (!useStagePaths) {
      final duration = TrafficMath.launchCooldown(TrafficMath.radius * speed);
      final newCars = cars.map((c) => c.clone()).toList();
      newCars.add(CarModel(
        id: nextId,
        path: 'ramp',
        progress: 0.0,
        angle: 0.0,
        launchAge: 0.0,
        travel: 0.0,
        colorIndex: nextId % GameTheme.accentColors.length,
      ));

      return GameTrafficState(
        cars: newCars,
        nextId: nextId + 1,
        cooldown: duration,
        releaseDuration: duration,
        cleanMerges: cleanMerges,
        lastMerge: lastMerge,
        crashed: false,
        crashTime: 0.0,
        impact: null,
        useStagePaths: false,
      );
    }

    // Stage/mode launch
    const cfg = CTGameConfig.defaults;
    final newQueue = queue.map((c) => c.clone()).toList();
    final newCars = cars.map((c) => c.clone()).toList();

    final launched = newQueue.removeAt(0);
    launched.path = 'ramp';
    final effectiveLaunch = ctClampD(cfg.launchDistance, 2.0, entrance!.len);
    launched.es = entrance!.len - effectiveLaunch;
    entrance!.pointAtInto(launched.es, _mp);
    launched.px = _mp.x;
    launched.py = _mp.y;
    launched.pang = _mp.ang;
    newCars.add(launched);

    _layoutStageQueue(newQueue, entrance, snap: false);

    final entSpd = _entSpeedAt(stage!, cfg);
    final nextFrontLen = newQueue.isNotEmpty ? newQueue.first.spec.len : 45.0;
    final needGap =
        (launched.spec.len + nextFrontLen) / 2.0 + CTDimensions.spawnGap;
    final duration = math.max(cfg.minLaunchInterval, needGap / entSpd);

    return _copyWith(
      cars: newCars,
      queue: newQueue,
      cooldown: duration,
      releaseDuration: duration,
    );
  }

  static double _entSpeedAt(CTStageDefinition st, CTGameConfig cfg) {
    final minLoop = st.speed *
        cfg.speedScale *
        (1.0 - (st.pulse != null ? st.pulse!.amp : 0.0));
    return math.min(cfg.entranceSpeed, minLoop);
  }

  static double _loopSpeedNow(
    CTStageDefinition st,
    CTGameConfig cfg,
    double simT,
  ) {
    double spd = st.speed * cfg.speedScale;
    if (st.pulse != null && st.pulse!.amp > 0) {
      spd *= 1.0 + st.pulse!.amp * math.sin(ctTau * simT / st.pulse!.period);
    }
    return spd;
  }

  /// Activates 5 seconds of Slow-Motion (traffic slows to 0.45x).
  GameTrafficState triggerSlowMo() {
    if (crashed || stageCleared || timeUp || slowMoCharges <= 0) return this;
    return _copyWith(
      slowMoTimer: 5.0,
      slowMoCharges: slowMoCharges - 1,
    );
  }

  /// Zaps up to 4 non-player / settled looping cars off the ring.
  GameTrafficState triggerZapClear() {
    if (crashed || stageCleared || timeUp || zapCharges <= 0) return this;
    final nextCars = <CarModel>[];
    int zapped = 0;
    for (final c in cars) {
      if (c.path == 'ring' && zapped < 4 && (!c.isPlayer || cars.length > 3)) {
        zapped++;
        continue;
      }
      nextCars.add(c.clone());
    }
    return _copyWith(
      cars: nextCars,
      zapCharges: zapCharges - 1,
    );
  }

  GameTrafficState advance(double dt, double speed) {
    double remaining = dt.clamp(0.0, 0.11);
    if (crashed) {
      return _copyWith(crashTime: crashTime + remaining);
    }
    if (timeUp) {
      return this;
    }
    if (stageCleared) {
      return _copyWith(clearTime: clearTime + remaining);
    }
    if (remaining <= 0) return this;

    if (!useStagePaths) {
      return _advanceClassic(remaining, speed);
    }
    return _advanceStage(remaining);
  }

  GameTrafficState _advanceClassic(double remaining, double speed) {
    final nextCars = cars.map((c) => c.clone()).toList();
    double nextCooldown = cooldown;
    int nextCleanMerges = cleanMerges;
    ({int id, int serial, double x, double z})? nextLastMerge = lastMerge;

    while (remaining > 1e-8) {
      final step = math.min(remaining, 1.0 / 90.0);
      remaining -= step;
      nextCooldown = math.max(0.0, nextCooldown - step);

      final merged = <CarModel>[];
      for (final car in nextCars) {
        if (car.path == 'ring') {
          car.angle = TrafficMath.wrapAngle(car.angle - speed * step);
          car.travel += TrafficMath.radius * speed * step;
          if (car.mergeAge != null) {
            car.mergeAge = car.mergeAge! + step;
          }
        } else {
          final age = car.launchAge;
          final movement = TrafficMath.launchDistance(
                age + step,
                TrafficMath.radius * speed,
              ) -
              TrafficMath.launchDistance(age, TrafficMath.radius * speed);
          car.launchAge = age + step;
          car.progress += movement;
          car.travel += movement;
          if (car.progress >= TrafficMath.rampLength) {
            car.path = 'ring';
            car.angle = TrafficMath.wrapAngle(
              TrafficMath.mergeAngle -
                  (car.progress - TrafficMath.rampLength) / TrafficMath.radius,
            );
            car.mergeAge = 0.0;
            merged.add(car);
          }
        }
      }

      for (int i = 0; i < nextCars.length; i++) {
        for (int j = i + 1; j < nextCars.length; j++) {
          final a = nextCars[i];
          final b = nextCars[j];
          final pa = a.pose;
          final pb = b.pose;
          if (TrafficMath.carsOverlap(pa, pb)) {
            return GameTrafficState(
              cars: nextCars,
              nextId: nextId,
              cooldown: nextCooldown,
              releaseDuration: releaseDuration,
              cleanMerges: nextCleanMerges,
              lastMerge: nextLastMerge,
              crashed: true,
              crashTime: 0.0,
              impact: (
                x: (pa.x + pb.x) / 2.0,
                z: (pa.z + pb.z) / 2.0,
                ids: [a.id, b.id],
              ),
              useStagePaths: false,
            );
          }
        }
      }

      for (final car in merged) {
        nextCleanMerges++;
        final p = car.pose;
        nextLastMerge = (
          id: car.id,
          serial: nextCleanMerges,
          x: p.x,
          z: p.z,
        );
      }
    }

    return GameTrafficState(
      cars: nextCars,
      nextId: nextId,
      cooldown: nextCooldown,
      releaseDuration: releaseDuration,
      cleanMerges: nextCleanMerges,
      lastMerge: nextLastMerge,
      crashed: false,
      crashTime: 0.0,
      impact: null,
      useStagePaths: false,
    );
  }

  GameTrafficState _advanceStage(double remaining) {
    const cfg = CTGameConfig.defaults;
    final nextCars = cars.map((c) => c.clone()).toList();
    final nextQueue = queue.map((c) => c.clone()).toList();

    double nextCooldown = cooldown;
    double nextSimT = simT;
    double nextSlowMo = math.max(0.0, slowMoTimer - remaining);
    double nextTimeAttack = timeAttackTimer;
    int nextCleanMerges = cleanMerges;
    int nextPlayersDone = playersDone;
    int nextModeScore = modeScore;
    int nextRushWave = rushWave;
    int nextIdCounter = nextId;
    int nextConvSerial = conversionSerial;
    ({int id, int serial, double x, double z})? nextLastMerge = lastMerge;
    ({int id, int serial, double x, double z})? nextLastConv = lastConversion;

    CTGamePath currentLoop = loop!;
    CTGamePath currentEnt = entrance!;
    CTGamePath? currentExi = exit;
    double currentExitDist = exitDist;
    CTStageDefinition currentStage = stage!;

    if (mode == CTGameMode.timeAttack) {
      nextTimeAttack = math.max(0.0, nextTimeAttack - remaining);
      if (nextTimeAttack <= 0.0) {
        return _copyWith(
          timeAttackTimer: 0.0,
          timeUp: true,
        );
      }
    }

    final timeScale = slowMoTimer > 0 ? 0.45 : 1.0;

    // Speed multiplier for endless / rushHour waves
    double modeSpeedBoost = 1.0;
    if (mode == CTGameMode.endless) {
      modeSpeedBoost = 1.0 + math.min(0.35, nextModeScore * 0.008);
    } else if (mode == CTGameMode.rushHour) {
      modeSpeedBoost = 1.0 + math.min(0.40, (nextRushWave - 1) * 0.06);
    }

    while (remaining > 1e-8) {
      // Only sub-step at 60Hz when a car is actively launching or within the post-merge collision window.
      // When all cars are settled on the ring, advance in a single analytical step!
      bool needSubstep = false;
      for (int i = 0; i < nextCars.length; i++) {
        final c = nextCars[i];
        if (c.path == 'ramp' ||
            (c.isPlayer &&
                c.mergedT >= 0 &&
                (nextSimT - c.mergedT) < CTDimensions.activeAfterMerge)) {
          needSubstep = true;
          break;
        }
      }
      final wallStep = needSubstep ? math.min(remaining, 1.0 / 60.0) : remaining;
      remaining -= wallStep;
      nextCooldown = math.max(0.0, nextCooldown - wallStep);

      final simStep = wallStep * timeScale * modeSpeedBoost;
      nextSimT += simStep;

      final L = currentLoop.len;
      final D = CTPathBuilder.loopDistAt(currentStage, cfg.speedScale, nextSimT);
      final vNow = _loopSpeedNow(currentStage, cfg, nextSimT);

      // 1. Roll queue cars forward smoothly
      final qX = currentEnt.queueX;
      for (int i = 0; i < nextQueue.length; i++) {
        final c = nextQueue[i];
        c.px = qX;
        c.py += (c.targetY - c.py) * math.min(1.0, 28.0 * wallStep);
        c.pang = -math.pi / 2;
      }

      // 2. Advance launching cars along entrance ramp (unscaled by slow-mo so player launches feel snappy)
      final entSpd = _entSpeedAt(currentStage, cfg);
      final newlyMerged = <CarModel>[];
      for (final c in nextCars) {
        if (c.path == 'ramp') {
          final movePx = entSpd * wallStep;
          c.es += movePx;
          c.launchAge += wallStep;
          c.travel += movePx * CTDimensions.to3DScale;
          if (c.es >= currentEnt.len) {
            final overshoot = c.es - currentEnt.len;
            c.path = 'ring';
            c.dm = D - overshoot;
            c.s0 = ((CTDimensions.mergeS - c.dm) % L + L) % L;
            c.mergedT = nextSimT;
            c.mergeAge = 0.0;
            if (c.role == CTCarRole.green && currentExi != null) {
              c.exitAtD = c.dm + currentExitDist;
            }
            if (c.role == CTCarRole.police) {
              c.pendingConvert = true;
              c.sirenTimer = 2.4;
            }
            newlyMerged.add(c);
          } else {
            currentEnt.pointAtInto(c.es, _mp);
            c.px = _mp.x;
            c.py = _mp.y;
            c.pang = _mp.ang;
          }
        }
      }

      // 3. Advance looping & exiting cars
      for (final c in nextCars) {
        if (c.flashAmount > 0) {
          c.flashAmount = math.max(0.0, c.flashAmount - wallStep * 3.2);
        }
        if (c.sirenTimer > 0) {
          c.sirenTimer = math.max(0.0, c.sirenTimer - wallStep);
        }

        if (c.path == 'ring') {
          if (c.mergeAge != null) {
            c.mergeAge = c.mergeAge! + wallStep;
          }
          if (currentExi != null && c.exitAtD < 1e8 && D >= c.exitAtD) {
            c.path = 'exit';
            c.xs = D - c.exitAtD;
            c.zElevation = 0.0;
          } else {
            final s = (c.s0 + D) % L;
            currentLoop.pointAtInto(s, _mp);
            c.px = _mp.x;
            c.py = _mp.y;
            c.pang = _mp.ang;
            c.zElevation = CTPathBuilder.getCarZ(s, currentLoop);
            c.travel += vNow * simStep * CTDimensions.to3DScale;
          }
        }

        if (c.path == 'exit' && currentExi != null) {
          final exitStep = vNow * 1.08 * simStep;
          c.xs += exitStep;
          c.travel += exitStep * CTDimensions.to3DScale;

          if (!c.counted && c.xs >= 145.0) {
            c.counted = true;
            nextPlayersDone++;
            if (mode != CTGameMode.campaign && mode != CTGameMode.bossRush) {
              nextModeScore++;
              if (mode == CTGameMode.timeAttack) {
                nextTimeAttack = math.min(99.0, nextTimeAttack + 1.5);
              }
            }
          }

          if (c.xs >= currentExi.len - 30.0) {
            c.path = 'done';
          } else {
            currentExi.pointAtInto(c.xs, _mp);
            c.px = _mp.x;
            c.py = _mp.y;
            c.pang = _mp.ang;
            final fadeStart = currentExi.len - 160.0;
            c.alpha = c.xs > fadeStart
                ? ctClampD(1.0 - (c.xs - fadeStart) / 130.0, 0.0, 1.0)
                : 1.0;
          }
        }
      }

      // 4. Police Car Conversion scan (turns nearest normal car ahead GREEN)
      if (currentExi != null) {
        for (final pol in nextCars) {
          if (!pol.pendingConvert || pol.path != 'ring') continue;

          double bestRel = 1e9;
          CarModel? target;
          for (final c in nextCars) {
            if (c == pol || c.path != 'ring' || c.role != CTCarRole.normal) {
              continue;
            }
            final rel = ((c.s0 - pol.s0) % L + L) % L;
            if (rel < bestRel) {
              bestRel = rel;
              target = c;
            }
          }
          if (target == null) {
            // Even if no normal car is left on the ring, police car still exits!
            pol.pendingConvert = false;
            final sPol = (pol.s0 + D) % L;
            var polTo = ((currentExi.sExit - sPol) % L + L) % L;
            if (polTo < CTDimensions.exitLeadMin) polTo += L;
            pol.exitAtD = D + polTo;
            continue;
          }

          pol.pendingConvert = false;
          target.role = CTCarRole.green;
          target.customHexColor = CTColors.greenHex;
          target.flashAmount = 1.0;

          final sNow = (target.s0 + D) % L;
          var distTo = ((currentExi.sExit - sNow) % L + L) % L;
          if (distTo < CTDimensions.exitLeadMin) distTo += L;
          target.exitAtD = D + distTo;

          final sPol = (pol.s0 + D) % L;
          var polTo = ((currentExi.sExit - sPol) % L + L) % L;
          if (polTo < CTDimensions.exitLeadMin) polTo += L;
          pol.exitAtD = D + polTo;

          nextConvSerial++;
          final tp = target.pose;
          nextLastConv = (
            id: target.id,
            serial: nextConvSerial,
            x: tp.x,
            z: tp.z,
          );
          if (mode == CTGameMode.timeAttack) {
            nextTimeAttack = math.min(99.0, nextTimeAttack + 1.5);
          } else if (mode == CTGameMode.policeChase) {
            nextModeScore += 2;
          }
        }
      }

      // 5. Multi-circle collision detection (matching CTCollisionService)
      final collision = _checkStageCollisions(
        nextCars,
        nextSimT,
        cfg.collisionScale,
      );
      if (collision != null) {
        final pa = collision.$1.pose;
        final pb = collision.$2.pose;
        return _copyWith(
          cars: nextCars,
          queue: nextQueue,
          cooldown: nextCooldown,
          simT: nextSimT,
          slowMoTimer: nextSlowMo,
          timeAttackTimer: nextTimeAttack,
          cleanMerges: nextCleanMerges,
          playersDone: nextPlayersDone,
          modeScore: nextModeScore,
          rushWave: nextRushWave,
          lastMerge: nextLastMerge,
          lastConversion: nextLastConv,
          conversionSerial: nextConvSerial,
          crashed: true,
          crashTime: 0.0,
          impact: (
            x: (pa.x + pb.x) / 2.0,
            z: (pa.z + pb.z) / 2.0,
            ids: [collision.$1.id, collision.$2.id],
          ),
        );
      }

      // 6. Process newly merged cars
      for (final car in newlyMerged) {
        nextCleanMerges++;
        final p = car.pose;
        nextLastMerge = (
          id: car.id,
          serial: nextCleanMerges,
          x: p.x,
          z: p.z,
        );

        if (mode != CTGameMode.campaign && mode != CTGameMode.bossRush) {
          nextModeScore++;
          if (mode == CTGameMode.timeAttack) {
            nextTimeAttack = math.min(99.0, nextTimeAttack + 1.2);
          } else if (mode == CTGameMode.rushHour &&
              nextCleanMerges % 8 == 0) {
            nextRushWave++;
            nextModeScore += 5;
          } else if (mode == CTGameMode.endless &&
              nextCleanMerges % 10 == 0) {
            // Morph road shape in Endless mode
            final shapes = CTRoadShape.values;
            final nextShape =
                shapes[(nextCleanMerges ~/ 10) % shapes.length];
            final cw = ((nextCleanMerges ~/ 10) % 2) == 1;
            currentLoop = CTPathBuilder.cachedLoop(nextShape, cw);
            currentEnt = CTPathBuilder.cachedEntrance(
              nextShape,
              cw,
              cfg.queueOffset,
              cfg.launchDistance,
            );
            currentExi = CTPathBuilder.cachedExit(nextShape, 'top', cw);
            final newL = currentLoop.len;
            currentExitDist =
                ((currentExi.sExit - CTDimensions.mergeS) % newL + newL) %
                    newL;
          }
        }
      }

      nextCars.removeWhere((c) => c.path == 'done');
    }

    // 7. Replenish queue in non-finite modes (endless, timeAttack, rushHour, policeChase)
    if (mode != CTGameMode.campaign && mode != CTGameMode.bossRush) {
      final rng = math.Random(nextIdCounter * 37 + nextCleanMerges);
      final ringCount = nextCars.where((c) => c.path == 'ring').length;

      // In Police Chase mode, if ring is nearly cleared, spawn a fresh wave of jammed traffic
      if (mode == CTGameMode.policeChase && ringCount <= 2) {
        final L = currentLoop.len;
        final D =
            CTPathBuilder.loopDistAt(currentStage, cfg.speedScale, nextSimT);
        for (int k = 0; k < 6; k++) {
          final frac = (k + 0.5) / 6.0;
          final s0 = (CTDimensions.mergeS + frac * L - D) % L;
          final normS0 = (s0 + L) % L;
          final sNow = (normS0 + D) % L;
          currentLoop.pointAtInto(sNow, _mp);
          // Only spawn if not overlapping an existing car
          final tooClose = nextCars.any(
            (c) =>
                (c.px - _mp.x) * (c.px - _mp.x) +
                    (c.py - _mp.y) * (c.py - _mp.y) <
                85 * 85,
          );
          if (!tooClose) {
            final vTypes = [
              CTVehicleType.car,
              CTVehicleType.van,
              CTVehicleType.truck,
              CTVehicleType.mini,
            ];
            final vt = vTypes[(nextIdCounter + k) % vTypes.length];
            final cIdx = (nextIdCounter + k) % GameTheme.accentHexColors.length;
            nextCars.add(CarModel(
              id: nextIdCounter++,
              path: 'ring',
              colorIndex: cIdx,
              vehicleType: vt,
              role: CTCarRole.normal,
              isPlayer: false,
              useStagePose: true,
              customHexColor: GameTheme.accentHexColors[cIdx],
              px: _mp.x,
              py: _mp.y,
              pang: _mp.ang,
              s0: normS0,
            ));
          }
        }
        nextModeScore += 5;
      }

      while (nextQueue.length < 6) {
        CTCarRole role = CTCarRole.normal;
        CTVehicleType vType = CTVehicleType.car;

        if (mode == CTGameMode.policeChase) {
          final r = rng.nextDouble();
          if (r < 0.52) {
            role = CTCarRole.police;
            vType = CTVehicleType.car;
          } else if (r < 0.82) {
            role = CTCarRole.green;
            vType = CTVehicleType.car;
          } else {
            role = CTCarRole.normal;
            vType = CTVehicleType.mini;
          }
        } else if (mode == CTGameMode.rushHour) {
          final vPool = [
            CTVehicleType.mini,
            CTVehicleType.car,
            CTVehicleType.van,
            CTVehicleType.truck,
            CTVehicleType.bus,
          ];
          vType = vPool[rng.nextInt(vPool.length)];
          if (ringCount >= 5 && rng.nextDouble() < 0.60) {
            role = rng.nextBool() ? CTCarRole.police : CTCarRole.green;
            vType = CTVehicleType.car;
          } else if (rng.nextDouble() < 0.30) {
            role = CTCarRole.green;
          }
        } else {
          // Endless & Time Attack
          final vPool = [
            CTVehicleType.mini,
            CTVehicleType.car,
            CTVehicleType.car,
            CTVehicleType.van,
          ];
          vType = vPool[rng.nextInt(vPool.length)];
          if (ringCount >= 6 && rng.nextDouble() < 0.65) {
            role = rng.nextBool() ? CTCarRole.police : CTCarRole.green;
            vType = CTVehicleType.car;
          } else if (rng.nextDouble() < 0.28) {
            role = rng.nextDouble() < 0.45
                ? CTCarRole.police
                : CTCarRole.green;
            vType = CTVehicleType.car;
          }
        }

        final colorIdx = nextIdCounter % GameTheme.accentHexColors.length;
        final hex = role == CTCarRole.green
            ? CTColors.greenHex
            : role == CTCarRole.police
                ? CTColors.policeBodyHex
                : CTColors.playerHexColors[
                    colorIdx % CTColors.playerHexColors.length];

        nextQueue.add(CarModel(
          id: nextIdCounter++,
          path: 'waiting',
          colorIndex: colorIdx,
          vehicleType: vType,
          role: role,
          isPlayer: true,
          useStagePose: true,
          customHexColor: hex,
        ));
      }
      _layoutStageQueue(nextQueue, currentEnt, snap: false);
    }

    // 8. Check Stage Clear condition for Campaign & Boss Rush
    bool nextCleared = stageCleared;
    if ((mode == CTGameMode.campaign || mode == CTGameMode.bossRush) &&
        !nextCleared &&
        nextQueue.isEmpty) {
      final anyLaunching = nextCars.any((c) => c.path == 'ramp');
      if (!anyLaunching) {
        // Ensure all recently merged player cars have survived at least 0.18s on the loop
        final allSafe = nextCars.every(
          (c) =>
              !c.isPlayer ||
              c.path != 'ring' ||
              c.mergedT < 0 ||
              (nextSimT - c.mergedT) >= 0.18,
        );
        if (allSafe) {
          nextCleared = true;
        }
      }
    }

    return _copyWith(
      cars: nextCars,
      queue: nextQueue,
      nextId: nextIdCounter,
      cooldown: nextCooldown,
      simT: nextSimT,
      slowMoTimer: nextSlowMo,
      timeAttackTimer: nextTimeAttack,
      cleanMerges: nextCleanMerges,
      playersDone: nextPlayersDone,
      modeScore: nextModeScore,
      rushWave: nextRushWave,
      stageCleared: nextCleared,
      lastMerge: nextLastMerge,
      lastConversion: nextLastConv,
      conversionSerial: nextConvSerial,
      loop: currentLoop,
      entrance: currentEnt,
      exit: currentExi,
      exitDist: currentExitDist,
    );
  }

  static (CarModel, CarModel)? _checkStageCollisions(
    List<CarModel> cars,
    double simT,
    double collisionScale,
  ) {
    final act = <CarModel>[];
    final set = <CarModel>[];

    for (int i = 0; i < cars.length; i++) {
      final c = cars[i];
      if (c.path == 'ramp') {
        act.add(c);
      } else if (c.path == 'ring') {
        if (c.isPlayer &&
            c.mergedT >= 0 &&
            simT - c.mergedT < CTDimensions.activeAfterMerge) {
          act.add(c);
        } else {
          set.add(c);
        }
      } else if (c.path == 'exit' && c.xs < 150.0) {
        set.add(c);
      }
    }

    if (act.isEmpty || set.isEmpty) return null;

    final scale = ctClampD(collisionScale, 0.6, 1.2);

    for (int ia = 0; ia < act.length; ia++) {
      final a = act[ia];
      final ra = a.spec.w * 0.52 * scale;
      final na = a.spec.circles;
      final halfA = math.max(0.0, (a.spec.len - a.spec.w) * 0.5);
      final caA = math.cos(a.pang), saA = math.sin(a.pang);

      for (int ib = 0; ib < set.length; ib++) {
        final b = set[ib];
        if (a.id == b.id) continue;
        if ((a.zElevation - b.zElevation).abs() > 0.4) continue;

        final cdx = a.px - b.px, cdy = a.py - b.py;
        final reach = (a.spec.len + b.spec.len) * 0.75 + 40.0;
        if (cdx * cdx + cdy * cdy > reach * reach) continue;

        final rb = b.spec.w * 0.52 * scale;
        final rr2 = (ra + rb) * (ra + rb);
        final nb = b.spec.circles;
        final halfB = math.max(0.0, (b.spec.len - b.spec.w) * 0.5);
        final caB = math.cos(b.pang), saB = math.sin(b.pang);

        for (int ka = 0; ka < na; ka++) {
          final offA = na == 1 ? 0.0 : -halfA + (2.0 * halfA * ka) / (na - 1);
          final pax = a.px + caA * offA;
          final pay = a.py + saA * offA;

          for (int kb = 0; kb < nb; kb++) {
            final offB = nb == 1 ? 0.0 : -halfB + (2.0 * halfB * kb) / (nb - 1);
            final dx = pax - (b.px + caB * offB);
            final dy = pay - (b.py + saB * offB);
            if (dx * dx + dy * dy < rr2) {
              return (a, b);
            }
          }
        }
      }
    }
    return null;
  }

  GameTrafficState _copyWith({
    List<CarModel>? cars,
    List<CarModel>? queue,
    int? nextId,
    double? cooldown,
    double? releaseDuration,
    int? cleanMerges,
    ({int id, int serial, double x, double z})? lastMerge,
    ({int id, int serial, double x, double z})? lastConversion,
    bool? crashed,
    double? crashTime,
    ({double x, double z, List<int> ids})? impact,
    CTGamePath? loop,
    CTGamePath? entrance,
    CTGamePath? exit,
    double? exitDist,
    double? simT,
    int? playersDone,
    bool? stageCleared,
    double? clearTime,
    bool? timeUp,
    double? timeAttackTimer,
    int? modeScore,
    int? rushWave,
    double? slowMoTimer,
    int? slowMoCharges,
    int? zapCharges,
    int? conversionSerial,
  }) {
    return GameTrafficState(
      cars: cars ?? this.cars,
      queue: queue ?? this.queue,
      nextId: nextId ?? this.nextId,
      cooldown: cooldown ?? this.cooldown,
      releaseDuration: releaseDuration ?? this.releaseDuration,
      cleanMerges: cleanMerges ?? this.cleanMerges,
      lastMerge: lastMerge ?? this.lastMerge,
      lastConversion: lastConversion ?? this.lastConversion,
      crashed: crashed ?? this.crashed,
      crashTime: crashTime ?? this.crashTime,
      impact: impact ?? this.impact,
      useStagePaths: useStagePaths,
      mode: mode,
      stageId: stageId,
      stage: stage,
      theme: theme,
      loop: loop ?? this.loop,
      entrance: entrance ?? this.entrance,
      exit: exit ?? this.exit,
      exitDist: exitDist ?? this.exitDist,
      simT: simT ?? this.simT,
      playersTotal: playersTotal,
      playersDone: playersDone ?? this.playersDone,
      stageCleared: stageCleared ?? this.stageCleared,
      clearTime: clearTime ?? this.clearTime,
      timeUp: timeUp ?? this.timeUp,
      timeAttackTimer: timeAttackTimer ?? this.timeAttackTimer,
      modeScore: modeScore ?? this.modeScore,
      rushWave: rushWave ?? this.rushWave,
      bossRushIndex: bossRushIndex,
      slowMoTimer: slowMoTimer ?? this.slowMoTimer,
      slowMoCharges: slowMoCharges ?? this.slowMoCharges,
      zapCharges: zapCharges ?? this.zapCharges,
      conversionSerial: conversionSerial ?? this.conversionSerial,
    );
  }
}
