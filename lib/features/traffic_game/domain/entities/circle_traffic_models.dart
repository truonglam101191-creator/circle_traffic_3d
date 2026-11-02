import 'dart:math';
import 'dart:typed_data';
import 'dart:ui';

/// TAU = 2π for convenience.
const double ctTau = 2 * pi;

/// Clamp [v] between [a] and [b].
double ctClampD(double v, double a, double b) => v < a ? a : (v > b ? b : v);

/// Integer clamp.
int ctClampI(int v, int a, int b) => v < a ? a : (v > b ? b : v);

/// Linear interpolation.
double ctLerp(double a, double b, double t) => a + (b - a) * t;

/// Wrap a delta into [-half, +half) range of a circular path of length [len].
double ctWrapDelta(double d, double len) {
  d = d % len;
  if (d < 0) d += len;
  if (d > len / 2) d -= len;
  return d;
}

/// 2D Point in stage world space (720x1080).
class CTPoint2 {
  double x;
  double y;
  CTPoint2(this.x, this.y);
}

/// 2D Pose: position + orientation angle.
class CTPose {
  double x = 0;
  double y = 0;
  double ang = 0;
}

/// World-space dimensions — the stage math runs in a 720×1080 coordinate system
/// that maps directly to 3D world space centered at (loopCx, loopCy).
class CTDimensions {
  CTDimensions._();

  static const double worldW = 720;
  static const double worldH = 1080;

  // Loop center in 2D stage coordinates
  static const double loopCx = 360;
  static const double loopCy = 468;

  // Road width in 2D stage coordinates
  static const double roadW = 64;

  // Merge point on the loop (arc distance from bottom-mid)
  static const double mergeS = 26;

  // Spawn gap between fast-tapped convoy cars
  static const double spawnGap = 4;

  // Merge margin for gridlock math
  static const double mergeMargin = 12;

  // Converted car needs this much arc before exit branch
  static const double exitLeadMin = 12;

  // Seconds a merged car stays "active" for collision
  static const double activeAfterMerge = 1.2;

  // Queue visible count
  static const int queueVisible = 4;

  // Scale factor mapping 2D stage pixels (radius 252) to 3D meters (radius 4.3)
  static const double to3DScale = 4.3 / 252.0;

  static double to3DX(double px) => (px - loopCx) * to3DScale;
  static double to3DZ(double py) => (py - loopCy) * to3DScale;
}

/// Tunable game configuration.
class CTGameConfig {
  final double speedScale;
  final double entranceSpeed;
  final double collisionScale;
  final double queueOffset;
  final double launchDistance;
  final double carScale;
  final double minLaunchInterval;
  final int launchBuffer;
  final double queueScale;

  const CTGameConfig({
    this.speedScale = 1.8,
    this.entranceSpeed = 400,
    this.collisionScale = 0.9,
    this.queueOffset = 65,
    this.launchDistance = 80,
    this.carScale = 1.4,
    this.minLaunchInterval = 0.13,
    this.launchBuffer = 20,
    this.queueScale = 1.0,
  });

  static const CTGameConfig defaults = CTGameConfig();
}

/// Game color palette for cars, roles, and UI accents.
class CTColors {
  CTColors._();

  static const Color accent = Color(0xFF52FFA8);
  static const Color accentDark = Color(0xFF23D97E);
  static const Color accentGlow = Color(0x593DF58C);

  static const int greenHex = 0xFF28E089;
  static const int policeBodyHex = 0xFFF2F6FF;
  static const int policeDarkHex = 0xFF1C2440;
  static const int policeRedHex = 0xFFFF3B4E;
  static const int policeBlueHex = 0xFF2E9BFF;

  static const List<int> playerHexColors = [
    0xFF20BCE3,
    0xFFFF702E,
    0xFF66DCB7,
    0xFFC179E3,
    0xFFFFC735,
    0xFF729BED,
    0xFFF58AB2,
    0xFFFFF4DF,
  ];
}

/// Vehicle types available in the game.
enum CTVehicleType { mini, car, van, truck, bus }

/// Vehicle specification driving visuals and physics hitboxes.
class CTVehicleSpec {
  final double baseLen;
  final double baseW;
  final int circles;

  double len;
  double w;

  CTVehicleSpec({
    required this.baseLen,
    required this.baseW,
    required this.circles,
  })  : len = baseLen * 1.4,
        w = baseW * 1.4;

  void applyScale(double scale) {
    len = baseLen * scale;
    w = baseW * scale;
  }
}

/// Vehicle specifications catalogue.
class CTVehicles {
  CTVehicles._();

  static final Map<CTVehicleType, CTVehicleSpec> specs = {
    CTVehicleType.mini: CTVehicleSpec(baseLen: 30, baseW: 24, circles: 2),
    CTVehicleType.car: CTVehicleSpec(baseLen: 38, baseW: 26, circles: 2),
    CTVehicleType.van: CTVehicleSpec(baseLen: 50, baseW: 28, circles: 3),
    CTVehicleType.truck: CTVehicleSpec(baseLen: 64, baseW: 30, circles: 3),
    CTVehicleType.bus: CTVehicleSpec(baseLen: 80, baseW: 30, circles: 4),
  };

  static CTVehicleSpec get(CTVehicleType type) => specs[type]!;

  static void applyScale(double scale) {
    for (final spec in specs.values) {
      spec.applyScale(scale);
    }
  }
}

/// Gameplay roles:
/// - normal: Standard cars merging and staying on the loop
/// - green: Cars that drive out through the glowing green exit road
/// - police: Converts nearest non-green car ahead to green, then both exit
enum CTCarRole { normal, green, police }

/// Car lifecycle states in the simulation.
enum CTCarLifecycleState {
  queued,
  launching,
  looping,
  exiting,
  crashed,
  done,
}

/// Game modes available:
/// - campaign: 100 hand-authored stages across 10 themed districts
/// - endless: Infinite loop with morphing 3D tracks & rising speed
/// - timeAttack: 60s countdown clock; each merge/clear adds bonus seconds
/// - rushHour: High-density multi-vehicle traffic with speed waves
/// - bossRush: All 10 Boss stages (10, 20, ..., 100) back-to-back
/// - policeChase: Jammed traffic rings cleared with Police & Green cars
enum CTGameMode {
  campaign,
  endless,
  timeAttack,
  rushHour,
  bossRush,
  policeChase,
}

/// Road loop shapes.
enum CTRoadShape {
  circle,
  roundedSquare,
  oval,
  compactLoop,
  wideLoop,
  figure8,
  figure8_90,
}

/// Parsed queue token.
class CTQueueToken {
  final CTVehicleType type;
  final CTCarRole role;
  const CTQueueToken(this.type, this.role);
}

/// Traffic car entry in stage.
class CTTrafficEntry {
  final CTVehicleType type;
  final double at; // 0..1 fraction around the loop
  final CTCarRole role;
  final int lap;

  const CTTrafficEntry({
    required this.type,
    required this.at,
    this.role = CTCarRole.normal,
    this.lap = 0,
  });
}

/// Pulse breathing for traffic speed.
class CTPulseConfig {
  final double amp;
  final double period;
  const CTPulseConfig({required this.amp, this.period = 2.5});
}

/// Stage definition.
class CTStageDefinition {
  final int id;
  final String name;
  final CTRoadShape shape;
  final double speed;
  final String exit;
  final bool clockwise;
  final List<String> queue;
  final List<CTTrafficEntry> traffic;
  final String? hint;
  final CTPulseConfig? pulse;
  final bool finger;
  final bool boss;

  bool get isBoss => boss;

  const CTStageDefinition({
    required this.id,
    required this.name,
    required this.shape,
    required this.speed,
    required this.exit,
    this.clockwise = false,
    required this.queue,
    required this.traffic,
    this.hint,
    this.pulse,
    this.finger = false,
    this.boss = false,
  });

  static CTQueueToken? parseQueueToken(String tok) {
    switch (tok) {
      case 'green':
        return const CTQueueToken(CTVehicleType.car, CTCarRole.green);
      case 'police':
        return const CTQueueToken(CTVehicleType.car, CTCarRole.police);
      case 'mini':
        return const CTQueueToken(CTVehicleType.mini, CTCarRole.normal);
      case 'car':
        return const CTQueueToken(CTVehicleType.car, CTCarRole.normal);
      case 'van':
        return const CTQueueToken(CTVehicleType.van, CTCarRole.normal);
      case 'truck':
        return const CTQueueToken(CTVehicleType.truck, CTCarRole.normal);
      case 'bus':
        return const CTQueueToken(CTVehicleType.bus, CTCarRole.normal);
      default:
        return null;
    }
  }
}

/// Metadata about the loop geometry.
class CTPathMeta {
  final String shape;
  final double cx;
  final double cy;
  final double hw;
  final double hh;
  final bool clockwise;

  double s1 = 0;
  double s2 = 0;

  CTPathMeta({
    required this.shape,
    required this.cx,
    required this.cy,
    required this.hw,
    required this.hh,
    required this.clockwise,
  });
}

/// Arc-length parameterized polyline path with O(1) precomputed lookup table.
class CTGamePath {
  static const int _lutSteps = 1024;

  final List<CTPoint2> pts;
  final Float64List cum;
  final double len;
  final bool closed;

  late final Float64List _lutX;
  late final Float64List _lutY;
  late final Float64List _lutAng;
  late final double _invStepLen;

  double anchorBottom = 0;
  double anchorRight = 0;
  double anchorTop = 0;
  double anchorLeft = 0;

  CTPathMeta? meta;

  double startY = 0;
  double bottomY = 0;
  double queueX = 0;

  double sExit = 0;
  CTPoint2? dir;
  String side = '';

  CTGamePath({
    required this.pts,
    required this.cum,
    required this.len,
    required this.closed,
  }) {
    _lutX = Float64List(_lutSteps + 1);
    _lutY = Float64List(_lutSteps + 1);
    _lutAng = Float64List(_lutSteps + 1);
    _invStepLen = len > 1e-6 ? _lutSteps / len : 0.0;

    const window = 4.5;
    for (int i = 0; i <= _lutSteps; i++) {
      final s = (i / _lutSteps) * len;
      final p = _rawXY(s);
      _lutX[i] = p.$1;
      _lutY[i] = p.$2;

      final p0 = _rawXY(s - window);
      final p1 = _rawXY(s + window);
      final dx = p1.$1 - p0.$1;
      final dy = p1.$2 - p0.$2;
      _lutAng[i] = (dx * dx + dy * dy > 1e-6) ? atan2(dy, dx) : 0.0;
    }
  }

  CTPose pointAt(double s) {
    final pose = CTPose();
    pointAtInto(s, pose);
    return pose;
  }

  (double, double) _rawXY(double s) {
    if (closed) {
      s = s % len;
      if (s < 0) s += len;
    } else {
      s = ctClampD(s, 0, len);
    }

    int lo = 0, hi = pts.length - 1;
    while (lo + 1 < hi) {
      final mid = (lo + hi) >> 1;
      if (cum[mid] <= s) {
        lo = mid;
      } else {
        hi = mid;
      }
    }

    final segLen = cum[hi] - cum[lo];
    final t = segLen > 0 ? (s - cum[lo]) / segLen : 0.0;
    final a = pts[lo], b = pts[hi];
    return (a.x + (b.x - a.x) * t, a.y + (b.y - a.y) * t);
  }

  void pointAtInto(double s, CTPose out) {
    if (len <= 1e-6) {
      out.x = pts.first.x;
      out.y = pts.first.y;
      out.ang = 0.0;
      return;
    }
    if (closed) {
      s = s % len;
      if (s < 0) s += len;
    } else {
      if (s <= 0) {
        out.x = _lutX[0];
        out.y = _lutY[0];
        out.ang = _lutAng[0];
        return;
      } else if (s >= len) {
        out.x = _lutX[_lutSteps];
        out.y = _lutY[_lutSteps];
        out.ang = _lutAng[_lutSteps];
        return;
      }
    }

    final u = s * _invStepLen;
    int idx = u.toInt();
    if (idx >= _lutSteps) idx = _lutSteps - 1;
    final t = u - idx;

    out.x = _lutX[idx] + (_lutX[idx + 1] - _lutX[idx]) * t;
    out.y = _lutY[idx] + (_lutY[idx + 1] - _lutY[idx]) * t;

    final a0 = _lutAng[idx];
    double da = _lutAng[idx + 1] - a0;
    if (da > pi) {
      da -= ctTau;
    } else if (da < -pi) {
      da += ctTau;
    }
    out.ang = a0 + da * t;
  }
}

/// District theme configuration.
class CTGameThemeData {
  final String name;
  final String bgImage;
  final Color bgA;
  final Color bgB;
  final Color deco;
  final Color road;
  final Color edge;
  final Color island;
  final Color tree;
  final bool stars;
  final List<Color> cars;

  Color get accent => tree;

  const CTGameThemeData({
    required this.name,
    required this.bgImage,
    required this.bgA,
    required this.bgB,
    required this.deco,
    required this.road,
    required this.edge,
    required this.island,
    required this.tree,
    required this.stars,
    required this.cars,
  });
}

class _CTShapeDef {
  final String kind;
  final double rx, ry;
  final double hw, hh, r;
  const _CTShapeDef.ellipse(this.rx, this.ry)
      : kind = 'ellipse',
        hw = 0,
        hh = 0,
        r = 0;
  const _CTShapeDef.rrect(this.hw, this.hh, this.r)
      : kind = 'rrect',
        rx = 0,
        ry = 0;
  const _CTShapeDef.figure8(this.rx, this.ry)
      : kind = 'figure8',
        hw = 0,
        hh = 0,
        r = 0;
  const _CTShapeDef.figure8_90(this.rx, this.ry)
      : kind = 'figure8_90',
        hw = 0,
        hh = 0,
        r = 0;
}

final Map<CTRoadShape, _CTShapeDef> _shapeDefs = {
  CTRoadShape.circle: const _CTShapeDef.ellipse(252, 252),
  CTRoadShape.oval: const _CTShapeDef.ellipse(226, 272),
  CTRoadShape.roundedSquare: const _CTShapeDef.rrect(250, 250, 118),
  CTRoadShape.compactLoop: const _CTShapeDef.rrect(212, 212, 104),
  CTRoadShape.wideLoop: const _CTShapeDef.rrect(272, 228, 112),
  CTRoadShape.figure8: const _CTShapeDef.figure8(180, 270),
  CTRoadShape.figure8_90: const _CTShapeDef.figure8_90(180, 270),
};

/// Builds all path geometries for Circle Traffic stages & modes.
class CTPathBuilder {
  CTPathBuilder._();

  static final Map<String, CTGamePath> _loopCache = {};
  static final Map<String, CTGamePath> _entCache = {};
  static final Map<String, CTGamePath> _exitCache = {};

  static final CTPose _mp = CTPose();

  static CTGamePath cachedLoop(CTRoadShape shape, bool clockwise) {
    final key = '${shape.name}_${clockwise ? 'cw' : 'ccw'}';
    return _loopCache.putIfAbsent(key, () => buildLoop(shape, clockwise));
  }

  static CTGamePath cachedEntrance(
    CTRoadShape shape,
    bool clockwise,
    double queueOffset,
    double launchDistance,
  ) {
    final key =
        '${shape.name}_${clockwise ? 'cw' : 'ccw'}_${queueOffset}_$launchDistance';
    return _entCache.putIfAbsent(key, () {
      final loop = cachedLoop(shape, clockwise);
      return buildEntrance(loop, queueOffset, launchDistance);
    });
  }

  static CTGamePath cachedExit(
    CTRoadShape shape,
    String side,
    bool clockwise,
  ) {
    final key = '${shape.name}_${side}_${clockwise ? 'cw' : 'ccw'}';
    return _exitCache.putIfAbsent(key, () {
      final loop = cachedLoop(shape, clockwise);
      return buildExit(loop, side);
    });
  }

  static CTGamePath _makePath(List<CTPoint2> pts, bool closed) {
    final cum = Float64List(pts.length);
    double total = 0;
    for (int i = 1; i < pts.length; i++) {
      final dx = pts[i].x - pts[i - 1].x;
      final dy = pts[i].y - pts[i - 1].y;
      total += sqrt(dx * dx + dy * dy);
      cum[i] = total;
    }
    return CTGamePath(pts: pts, cum: cum, len: total, closed: closed);
  }

  static List<CTPoint2> _ellipsePts(
    double cx,
    double cy,
    double rx,
    double ry,
  ) {
    final pts = <CTPoint2>[];
    const n = 220;
    for (int i = 0; i <= n; i++) {
      final a = pi / 2 - ctTau * i / n;
      pts.add(CTPoint2(cx + rx * cos(a), cy + ry * sin(a)));
    }
    return pts;
  }

  static List<CTPoint2> _figure8Pts(
    double cx,
    double cy,
    double rx,
    double ry,
  ) {
    final pts = <CTPoint2>[];
    const n = 220;
    for (int i = 0; i <= n; i++) {
      final t = ctTau * i / n;
      pts.add(CTPoint2(cx + rx * sin(2 * t), cy + ry * cos(t)));
    }
    return pts;
  }

  static List<CTPoint2> _figure8RotatedPts(
    double cx,
    double cy,
    double rx,
    double ry,
  ) {
    final pts = <CTPoint2>[];
    const n = 220;
    for (int i = 0; i <= n; i++) {
      final t = ctTau * i / n;
      final vx = rx * sin(2 * t);
      final vy = ry * cos(t);
      pts.add(CTPoint2(cx - vy, cy + vx));
    }
    return pts;
  }

  static List<CTPoint2> _roundedRectPts(
    double cx,
    double cy,
    double hw,
    double hh,
    double r,
  ) {
    final pts = <CTPoint2>[];
    const arcStep = pi / 36;
    const lineStep = 7.0;

    void line(double x0, double y0, double x1, double y1) {
      final dx = x1 - x0, dy = y1 - y0;
      final d = sqrt(dx * dx + dy * dy);
      final n = max(1, (d / lineStep).round());
      for (int i = 0; i <= n; i++) {
        if (pts.isNotEmpty && i == 0) continue;
        pts.add(CTPoint2(x0 + dx * i / n, y0 + dy * i / n));
      }
    }

    void arc(double ax, double ay, double a0, double a1) {
      final n = max(2, ((a1 - a0).abs() / arcStep).round());
      for (int i = 0; i <= n; i++) {
        if (pts.isNotEmpty && i == 0) continue;
        final a = a0 + (a1 - a0) * i / n;
        pts.add(CTPoint2(ax + r * cos(a), ay + r * sin(a)));
      }
    }

    line(cx, cy + hh, cx + hw - r, cy + hh);
    arc(cx + hw - r, cy + hh - r, pi / 2, 0);
    line(cx + hw, cy + hh - r, cx + hw, cy - hh + r);
    arc(cx + hw - r, cy - hh + r, 0, -pi / 2);
    line(cx + hw - r, cy - hh, cx - hw + r, cy - hh);
    arc(cx - hw + r, cy - hh + r, -pi / 2, -pi);
    line(cx - hw, cy - hh + r, cx - hw, cy + hh - r);
    arc(cx - hw + r, cy + hh - r, pi, pi / 2);
    line(cx - hw + r, cy + hh, cx, cy + hh);

    return pts;
  }

  static List<CTPoint2> _alignPointsToBottom(
    List<CTPoint2> pts,
    double cx,
    double cy,
    double hw,
    double hh,
    String shape,
  ) {
    if (pts.length < 3) return pts;

    if ((pts.first.x - pts.last.x).abs() < 0.1 &&
        (pts.first.y - pts.last.y).abs() < 0.1) {
      pts.removeLast();
    }

    double targetX = cx - 30;
    double targetY = cy + hh + 200;
    if (shape == 'figure8_90') {
      targetX = cx - hw * 0.707;
      targetY = cy + hh;
    }

    int bestI = 0;
    double bestD = 1e18;
    for (int i = 0; i < pts.length; i++) {
      final dx = pts[i].x - targetX;
      final dy = pts[i].y - targetY;
      final d = dx * dx + dy * dy;
      if (d < bestD) {
        bestD = d;
        bestI = i;
      }
    }

    final reordered = [...pts.sublist(bestI), ...pts.sublist(0, bestI)];
    reordered.add(CTPoint2(reordered.first.x, reordered.first.y));
    return reordered;
  }

  static CTGamePath buildLoop(CTRoadShape shape, bool clockwise) {
    final def = _shapeDefs[shape] ?? _shapeDefs[CTRoadShape.circle]!;
    List<CTPoint2> pts;
    double hw, hh;
    final cx = CTDimensions.loopCx;
    final cy = CTDimensions.loopCy;

    switch (def.kind) {
      case 'ellipse':
        pts = _ellipsePts(cx, cy, def.rx, def.ry);
        hw = def.rx;
        hh = def.ry;
      case 'figure8':
        pts = _figure8Pts(cx, cy, def.rx, def.ry);
        pts = _alignPointsToBottom(pts, cx, cy, def.rx, def.ry, 'figure8');
        hw = def.rx;
        hh = def.ry;
      case 'figure8_90':
        pts = _figure8RotatedPts(cx, cy, def.rx, def.ry);
        pts = _alignPointsToBottom(pts, cx, cy, def.ry, def.rx, 'figure8_90');
        hw = def.ry;
        hh = def.rx;
      default:
        pts = _roundedRectPts(cx, cy, def.hw, def.hh, def.r);
        hw = def.hw;
        hh = def.hh;
    }

    if (clockwise) {
      pts = pts.reversed.toList();
    }

    final path = _makePath(pts, true);

    double nearestS(double px, double py) {
      double best = 0;
      double bd = 1e18;
      for (int i = 0; i < pts.length; i++) {
        final dx = pts[i].x - px;
        final dy = pts[i].y - py;
        final d = dx * dx + dy * dy;
        if (d < bd) {
          bd = d;
          best = path.cum[i];
        }
      }
      return best;
    }

    path.meta = CTPathMeta(
      shape: shape.name,
      cx: cx,
      cy: cy,
      hw: hw,
      hh: hh,
      clockwise: clockwise,
    );

    if (shape == CTRoadShape.figure8 || shape == CTRoadShape.figure8_90) {
      final crossings = <double>[];
      for (int i = 1; i < pts.length - 1; i++) {
        final dPrev = _dist(pts[i - 1].x, pts[i - 1].y, cx, cy);
        final dCurr = _dist(pts[i].x, pts[i].y, cx, cy);
        final dNext = _dist(pts[i + 1].x, pts[i + 1].y, cx, cy);
        if (dCurr < dPrev && dCurr <= dNext && dCurr < 20) {
          crossings.add(path.cum[i]);
        }
      }
      if (crossings.length >= 2) {
        path.meta!.s1 = crossings[0];
        path.meta!.s2 = crossings[1];
      } else {
        path.meta!.s1 = path.len * 0.25;
        path.meta!.s2 = path.len * 0.75;
      }
    }

    double topAnchorX = cx;
    double topAnchorY = cy - hh;
    if (shape == CTRoadShape.figure8_90) {
      topAnchorX = cx + hw * 0.707;
      topAnchorY = cy - hh;
    }

    path.anchorBottom = 0;
    path.anchorRight = nearestS(cx + hw, cy);
    path.anchorTop = nearestS(topAnchorX, topAnchorY);
    path.anchorLeft = nearestS(cx - hw, cy);

    return path;
  }

  static double _dist(double x1, double y1, double x2, double y2) {
    final dx = x1 - x2, dy = y1 - y2;
    return sqrt(dx * dx + dy * dy);
  }

  static List<CTPoint2> _bezPts(
    CTPoint2 p0,
    CTPoint2 p1,
    CTPoint2 p2,
    CTPoint2 p3,
    int n,
  ) {
    final pts = <CTPoint2>[];
    for (int i = 0; i <= n; i++) {
      final t = i / n;
      final u = 1 - t;
      pts.add(CTPoint2(
        u * u * u * p0.x +
            3 * u * u * t * p1.x +
            3 * u * t * t * p2.x +
            t * t * t * p3.x,
        u * u * u * p0.y +
            3 * u * u * t * p1.y +
            3 * u * t * t * p2.y +
            t * t * t * p3.y,
      ));
    }
    return pts;
  }

  static CTGamePath buildEntrance(
    CTGamePath loop,
    double queueOffset,
    double launchDistance,
  ) {
    final isCw = loop.meta?.clockwise ?? false;
    double qX = isCw ? CTDimensions.loopCx + 30 : CTDimensions.loopCx - 30;
    if (loop.meta?.shape == 'figure8_90') {
      qX = loop.pts[0].x - 35;
    }
    final bottomY =
        (loop.meta?.cy ?? CTDimensions.loopCy) + (loop.meta?.hh ?? 252);
    final startY = bottomY + queueOffset;
    final straightEnd = bottomY + launchDistance;

    final pts = <CTPoint2>[];
    for (double y = startY; y >= straightEnd; y -= 6) {
      pts.add(CTPoint2(qX, y));
    }

    loop.pointAtInto(CTDimensions.mergeS, _mp);
    final p0 = CTPoint2(qX, straightEnd);
    final p1 = CTPoint2(qX, straightEnd - launchDistance * 0.67);
    final p3 = CTPoint2(_mp.x, _mp.y);
    final p2 = CTPoint2(
      p3.x - cos(_mp.ang) * launchDistance * 0.67,
      p3.y - sin(_mp.ang) * launchDistance * 0.67,
    );

    final bz = _bezPts(p0, p1, p2, p3, 26);
    for (int i = 1; i < bz.length; i++) {
      pts.add(bz[i]);
    }

    final path = _makePath(pts, false);
    path.startY = startY;
    path.bottomY = bottomY;
    path.queueX = qX;
    return path;
  }

  static CTGamePath buildExit(CTGamePath loop, String side) {
    String actualSide = side;
    if (loop.meta?.shape == 'figure8_90') {
      actualSide = 'top';
    }

    double sExit;
    switch (actualSide) {
      case 'right':
        sExit = loop.anchorRight;
      case 'left':
        sExit = loop.anchorLeft;
      default:
        sExit = loop.anchorTop;
    }

    loop.pointAtInto(sExit, _mp);

    CTPoint2 dir;
    switch (actualSide) {
      case 'right':
        dir = CTPoint2(1, 0);
      case 'left':
        dir = CTPoint2(-1, 0);
      default:
        dir = CTPoint2(0, -1);
    }

    final p0 = CTPoint2(_mp.x, _mp.y);
    final p1 = CTPoint2(p0.x + cos(_mp.ang) * 40, p0.y + sin(_mp.ang) * 40);

    double shiftX = 0, shiftY = 0;
    if (actualSide == 'top') {
      final magX = (loop.meta?.shape == 'figure8_90') ? 55.0 : 30.0;
      shiftX = (cos(_mp.ang) >= 0 ? 1 : -1) * magX;
    } else {
      shiftY = (sin(_mp.ang) >= 0 ? 1 : -1) * 30;
    }

    final p3 =
        CTPoint2(p0.x + dir.x * 92 + shiftX, p0.y + dir.y * 92 + shiftY);
    final p2 = CTPoint2(p3.x - dir.x * 40, p3.y - dir.y * 40);

    final pts = _bezPts(p0, p1, p2, p3, 22);
    const runout = 560.0;
    final n = (runout / 8).round();
    for (int i = 1; i <= n; i++) {
      pts.add(CTPoint2(
        p3.x + dir.x * runout * i / n,
        p3.y + dir.y * runout * i / n,
      ));
    }

    final path = _makePath(pts, false);
    path.sExit = sExit;
    path.dir = dir;
    path.side = actualSide;
    return path;
  }

  static double getCarZ(double s, CTGamePath loop) {
    if (loop.meta == null) return 0;
    if (loop.meta!.shape != 'figure8' && loop.meta!.shape != 'figure8_90') {
      return 0;
    }
    final s1 = loop.meta!.s1;
    final l = loop.len;
    final d1 = ctWrapDelta(s - s1, l).abs();
    const rampHalfLen = 160.0;
    if (d1 < rampHalfLen) {
      return 0.5 + 0.5 * cos((d1 / rampHalfLen) * pi);
    }
    return 0;
  }

  static double loopDistAt(
    CTStageDefinition stage,
    double speedScale,
    double simT,
  ) {
    final speed = stage.speed * speedScale;
    if (stage.pulse != null && stage.pulse!.amp > 0) {
      final amp = stage.pulse!.amp;
      final period = stage.pulse!.period;
      return speed * simT +
          speed * amp * period / ctTau * (1 - cos(ctTau * simT / period));
    }
    return speed * simT;
  }
}
