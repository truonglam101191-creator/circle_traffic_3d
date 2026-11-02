import 'dart:math' as math;

/// Art Direction & Theme constants matching original Circle Traffic 3D
class GameTheme {
  static const String road = '#443b48';
  static const String line = '#ffcc32';
  static const String wall = '#2d2336';
  static const String edge = '#ffe2c6';
  static const String lawn = '#a6c96c';

  static const List<String> accentColors = [
    '#ff702e',
    '#20bce3',
    '#fff4df',
    '#66dcb7',
    '#c179e3',
    '#ffc735',
    '#729bed',
    '#f58ab2',
  ];

  static const List<int> accentHexColors = [
    0xFFFF702E,
    0xFF20BCE3,
    0xFFFFF4DF,
    0xFF66DCB7,
    0xFFC179E3,
    0xFFFFC735,
    0xFF729BED,
    0xFFF58AB2,
  ];

  static const List<String> treeColors = [
    '#66dcb7',
    '#c179e3',
    '#ffc735',
    '#20bce3',
    '#ff702e',
  ];

  static const List<int> treeHexColors = [
    0xFF66DCB7,
    0xFFC179E3,
    0xFFFFC735,
    0xFF20BCE3,
    0xFFFF702E,
  ];
}

class CameraConfig {
  static const double height = 12.8;
  static const double depth = 17.8;
  static const double targetZ = 2.9;
  static const double halfWidth = 5.68;

  static const double near = 0.1;
  static const double far = 80.0;
}

class TreeSpec {
  final double x;
  final double z;
  final double scale;
  final int color;
  final bool island;
  const TreeSpec({
    required this.x,
    required this.z,
    required this.scale,
    required this.color,
    required this.island,
  });
}

class SceneryLayout {
  static const List<TreeSpec> treeLayout = [
    TreeSpec(x: -1.55, z: -0.85, scale: 1.05, color: 0, island: true),
    TreeSpec(x: -0.05, z: -1.50, scale: 0.85, color: 1, island: true),
    TreeSpec(x: 1.45, z: -0.50, scale: 0.95, color: 2, island: true),
    TreeSpec(x: -0.75, z: 1.03, scale: 0.76, color: 3, island: true),
    TreeSpec(x: 1.12, z: 1.18, scale: 0.72, color: 4, island: true),
    TreeSpec(x: -3.13, z: 8.45, scale: 1.05, color: 0, island: false),
    TreeSpec(x: -4.05, z: 6.65, scale: 0.78, color: 1, island: false),
    TreeSpec(x: 4.10, z: 8.45, scale: 0.85, color: 2, island: false),
  ];

  static const List<({double y, double radius, double height})> pineTiers = [
    (y: 1.24, radius: 0.48, height: 0.74),
    (y: 1.60, radius: 0.37, height: 0.69),
    (y: 1.94, radius: 0.27, height: 0.72),
  ];

  static const double trunkHeight = 1.1;

  static const List<({double x, double z, double angle})> parkBenches = [
    (x: -0.70, z: 2.02, angle: 0.10),
    (x: 1.85, z: 0.45, angle: -1.05),
  ];

  static const List<({double x, double z, double scale})> parkGrass = [
    (x: -2.14, z: 0.20, scale: 0.90),
    (x: -2.10, z: -1.02, scale: 1.00),
    (x: -1.80, z: 1.22, scale: 0.92),
    (x: -1.25, z: 1.62, scale: 0.80),
    (x: 0.10, z: 1.73, scale: 0.92),
    (x: 0.28, z: 0.52, scale: 1.00),
    (x: 0.42, z: -0.53, scale: 0.86),
    (x: 0.76, z: -1.75, scale: 0.92),
    (x: -0.82, z: -1.42, scale: 0.95),
    (x: 1.96, z: -0.93, scale: 0.92),
    (x: 2.18, z: -0.17, scale: 0.82),
    (x: 1.66, z: 1.32, scale: 1.00),
    (x: 1.13, z: 1.94, scale: 0.85),
    (x: -0.43, z: -2.16, scale: 0.80),
    (x: 0.48, z: -2.20, scale: 0.90),
    (x: -1.83, z: -1.50, scale: 0.80),
    (x: -0.20, z: -0.34, scale: 0.80),
    (x: -1.27, z: 0.30, scale: 0.85),
  ];
}

class DrivingState {
  double lastTravel;
  double speed;
  double curve;
  double roll;
  double pitch;
  List<double> steer;
  List<double> wheels;

  DrivingState({
    required this.lastTravel,
    this.speed = 0.0,
    this.curve = 0.0,
    this.roll = 0.0,
    this.pitch = 0.0,
    List<double>? steer,
    List<double>? wheels,
  })  : steer = steer ?? [0.0, 0.0],
        wheels = wheels ?? [0.0, 0.0, 0.0, 0.0];
}

class TrafficMath {
  static const double tau = math.pi * 2;
  static const double baseTrafficSpeed = 0.95;
  static const double maxPaceMultiplier = 1.22;
  static const double fullPaceMerges = 10.0;

  static const double radius = 4.3;
  static const double innerRadius = 3.48;
  static const double outerRadius = 5.12;
  static const double roadDepth = 0.85;
  static const double surfaceY = 0.04;
  static const double entryHalfWidth = 0.68;

  static const double queueX = 1.8;
  static const double queueZ = 6.8;
  static const double queueTail = 18.0;
  static const double speed = 5.7;
  static const double mergeAngle = 0.45;

  static const double carLength = 1.46;
  static const double carWidth = 0.9;
  static const double queueSpacing = 1.82;
  static const double releaseCooldown = 0.68;
  static const double wheelRadius = 0.157;
  static const double halfWheelbase = 0.43;
  static const double wheelbase = halfWheelbase * 2;
  static const double halfTrack = 0.388;

  static const double anticipation = 0.045;
  static const double acceleration = 0.15;

  static const int queueCount = 3;
  static const double queueFadeDuration = 0.34;
  static const double queueSpawnDelay = 0.07;

  static const double failReveal = 0.88;
  static const double rewardLife = 1.45;

  static const int dashCount = 48;
  static const double dashLength = 0.34;
  static const double dashWidth = 0.17;
  static const double dashPitch = 2 * math.pi * radius / dashCount;

  static const List<double> initialAngles = [0.9, 2.9, 4.9];

  // Quintic polynomial spline coefficients
  static late final List<double> cx;
  static late final List<double> cz;
  static late final List<({double t, double d})> lookup;
  static late final double rampLength;

  // Markings table
  static late final double paintJoinAngle;
  static late final List<({double d, double s})> _paintTable;
  static late final double _paintLength;

  static bool _initialized = false;

  static double hypot(double a, double b) => math.sqrt(a * a + b * b);

  static void initialize() {
    if (_initialized) return;
    _initialized = true;

    final endX = math.cos(mergeAngle) * radius;
    final endZ = math.sin(mergeAngle) * radius;

    cx = _coefficients(
      queueX,
      endX,
      0,
      math.sin(mergeAngle) * speed,
      -math.cos(mergeAngle) * speed * speed / radius,
    );

    cz = _coefficients(
      queueZ,
      endZ,
      -speed,
      -math.cos(mergeAngle) * speed,
      -math.sin(mergeAngle) * speed * speed / radius,
    );

    lookup = [(t: 0.0, d: 0.0)];
    var previous = curvePose(0);
    double length = 0;
    for (int i = 1; i <= 640; i++) {
      final p = curvePose(i / 640.0);
      length += hypot(p.x - previous.x, p.z - previous.z);
      lookup.add((t: i / 640.0, d: length));
      previous = p;
    }
    rampLength = length;

    // Initialize markings lookup table
    final joinDist = rampLength * 0.68;
    final joinOriginal = approachPose(joinDist);
    paintJoinAngle = math.atan2(joinOriginal.z, joinOriginal.x);

    const startDist = -5.95;
    _paintTable = [(d: startDist, s: 0.0)];
    var prevPaint = _paintPoint(startDist, joinDist);
    double pLen = 0.0;
    for (int i = 1; i <= 480; i++) {
      final d = startDist + (joinDist - startDist) * i / 480.0;
      final p = _paintPoint(d, joinDist);
      pLen += hypot(p.x - prevPaint.x, p.z - prevPaint.z);
      _paintTable.add((d: d, s: pLen));
      prevPaint = p;
    }
    _paintLength = pLen;
  }

  static List<double> _coefficients(
    double p0,
    double p1,
    double v0,
    double v1,
    double a1,
  ) {
    final d = p1 - p0 - v0;
    final v = v1 - v0;
    return [
      p0,
      v0,
      0,
      10 * d - 4 * v + a1 / 2,
      -15 * d + 7 * v - a1,
      6 * d - 3 * v + a1 / 2,
    ];
  }

  static double evaluate(List<double> c, double t) {
    return c[0] + t * (c[1] + t * (c[2] + t * (c[3] + t * (c[4] + t * c[5]))));
  }

  static double derivative(List<double> c, double t) {
    return c[1] + t * (2 * c[2] + t * (3 * c[3] + t * (4 * c[4] + 5 * t * c[5])));
  }

  static ({double x, double z, double fx, double fz}) curvePose(double t) {
    final dx = derivative(cx, t);
    final dz = derivative(cz, t);
    final n = hypot(dx, dz);
    return (
      x: evaluate(cx, t),
      z: evaluate(cz, t),
      fx: dx / n,
      fz: dz / n,
    );
  }

  static ({double x, double z, double fx, double fz}) ringPose(double angle) {
    return (
      x: math.cos(angle) * radius,
      z: math.sin(angle) * radius,
      fx: math.sin(angle),
      fz: -math.cos(angle),
    );
  }

  static ({double x, double z, double fx, double fz}) approachPose(double distance) {
    initialize();
    if (distance <= 0) {
      return (x: queueX, z: queueZ - distance, fx: 0.0, fz: -1.0);
    }
    if (distance >= rampLength) {
      return ringPose(mergeAngle - (distance - rampLength) / radius);
    }

    int lo = 0;
    int hi = lookup.length - 1;
    while (hi - lo > 1) {
      final mid = (lo + hi) >> 1;
      if (lookup[mid].d < distance) {
        lo = mid;
      } else {
        hi = mid;
      }
    }
    final a = lookup[lo];
    final b = lookup[hi];
    final t = a.t + (b.t - a.t) * (distance - a.d) / (b.d - a.d);
    return curvePose(t);
  }

  static ({double x, double z}) offset(
    ({double x, double z, double fx, double fz}) p,
    double side,
  ) {
    return (
      x: p.x - p.fz * side * entryHalfWidth,
      z: p.z + p.fx * side * entryHalfWidth,
    );
  }

  /// Exact road footprint from track.mjs
  static ({
    List<({double x, double z})> outer,
    List<({double x, double z})> inner,
  }) roadFootprint() {
    initialize();
    ({List<({double x, double z})> points, double angle}) exposedSide(double side) {
      final points = <({double x, double z})>[];
      double previousDistance = -queueTail;
      var previousPoint = offset(approachPose(previousDistance), side);
      points.add(previousPoint);
      const steps = 500;
      for (int i = 1; i <= steps; i++) {
        final distance = -queueTail + (rampLength + queueTail) * i / steps;
        final point = offset(approachPose(distance), side);
        if (hypot(point.x, point.z) <= outerRadius) {
          double lo = previousDistance;
          double hi = distance;
          for (int j = 0; j < 40; j++) {
            final mid = (lo + hi) / 2.0;
            final p = offset(approachPose(mid), side);
            if (hypot(p.x, p.z) > outerRadius) {
              lo = mid;
            } else {
              hi = mid;
            }
          }
          final join = offset(approachPose((lo + hi) / 2.0), side);
          points.add(join);
          return (points: points, angle: math.atan2(join.z, join.x));
        }
        points.add(point);
        previousDistance = distance;
        previousPoint = point;
      }
      return (points: points, angle: 0.0);
    }

    final left = exposedSide(-1.0);
    final right = exposedSide(1.0);
    final outer = <({double x, double z})>[];
    double endAngle = right.angle;
    while (endAngle <= left.angle) {
      endAngle += math.pi * 2;
    }
    final count = ((endAngle - left.angle) * 52).ceil();
    for (int i = 0; i <= count; i++) {
      final a = left.angle + (endAngle - left.angle) * i / count;
      outer.add((x: math.cos(a) * outerRadius, z: math.sin(a) * outerRadius));
    }
    outer.addAll(right.points.sublist(0, right.points.length - 1).reversed);
    for (int i = 1; i < 24; i++) {
      final a = i / 24.0 * math.pi;
      outer.add((
        x: queueX + math.cos(a) * entryHalfWidth,
        z: queueZ + queueTail + math.sin(a) * entryHalfWidth,
      ));
    }
    outer.addAll(left.points.sublist(0, left.points.length - 1));
    final inner = List.generate(
      256,
      (i) => (
        x: math.cos(i / 256.0 * math.pi * 2) * innerRadius,
        z: math.sin(i / 256.0 * math.pi * 2) * innerRadius,
      ),
    );
    return (outer: outer, inner: inner);
  }

  static ({double x, double z}) _paintPoint(double d, double joinDist) {
    const blendStart = 2.4;
    final p = approachPose(d);
    if (d <= blendStart) {
      return (x: p.x, z: p.z);
    }
    final t = ((d - blendStart) / (joinDist - blendStart)).clamp(0.0, 1.0);
    final r = hypot(p.x, p.z);
    final target = radius + (r - radius) * (1.0 - smoother(t));
    return (x: p.x * target / r, z: p.z * target / r);
  }

  static ({double x, double z, double fx, double fz}) _paintPose(double d) {
    final joinDist = rampLength * 0.68;
    if (d >= joinDist) {
      return ringPose(paintJoinAngle);
    }
    final p = _paintPoint(d, joinDist);
    final a = _paintPoint(d - 1e-4, joinDist);
    final b = _paintPoint(math.min(joinDist, d + 1e-4), joinDist);
    final len = hypot(b.x - a.x, b.z - a.z);
    return (
      x: p.x,
      z: p.z,
      fx: (b.x - a.x) / len,
      fz: (b.z - a.z) / len,
    );
  }

  static ({double x, double z, double fx, double fz}) paintApproachPose(double s) {
    initialize();
    if (s >= _paintLength) {
      return ringPose(paintJoinAngle - (s - _paintLength) / radius);
    }
    if (s <= 0) {
      return _paintPose(-5.95);
    }
    int lo = 0;
    int hi = _paintTable.length - 1;
    while (hi - lo > 1) {
      final mid = (lo + hi) >> 1;
      if (_paintTable[mid].s < s) {
        lo = mid;
      } else {
        hi = mid;
      }
    }
    final a = _paintTable[lo];
    final b = _paintTable[hi];
    return _paintPose(a.d + (b.d - a.d) * (s - a.s) / (b.s - a.s));
  }

  static ({
    List<({double x, double z, double fx, double fz})> ring,
    List<({double x, double z, double fx, double fz})> entry,
  }) createMarkingLayout() {
    initialize();
    final ring = List.generate(
      dashCount,
      (i) => ringPose(paintJoinAngle + i * math.pi * 2 / dashCount),
    );
    final entry = <({double x, double z, double fx, double fz})>[];
    for (double s = _paintLength - dashPitch; s >= 0; s -= dashPitch) {
      final p = paintApproachPose(s);
      if (ring.every((q) => hypot(p.x - q.x, p.z - q.z) >= dashLength + 0.035)) {
        entry.add(p);
      }
    }
    return (ring: ring, entry: entry);
  }

  static double wrapAngle(double a) {
    return (a % tau + tau) % tau;
  }

  static double clamp01(double x) => x.clamp(0.0, 1.0);

  static double smoother(double x) {
    final t = clamp01(x);
    return t * t * t * (10 + t * (-15 + 6 * t));
  }

  static double smooth2(double x) {
    final t = clamp01(x);
    return t * t * (3 - 2 * t);
  }

  static double damp(double a, double b, double rate, double dt) {
    return a + (b - a) * (1.0 - math.exp(-rate * dt));
  }

  static double launchDistance(double age, double currentLinearSpeed) {
    final t = math.max(0.0, age - anticipation);
    if (t >= acceleration) {
      return currentLinearSpeed * (t - acceleration / 2.0);
    }
    final u = t / acceleration;
    return currentLinearSpeed * acceleration * (u * u * u - 0.5 * u * u * u * u);
  }

  static double launchCooldown(double linearSpeed) {
    return math.max(
      releaseCooldown,
      anticipation +
          acceleration / 2.0 +
          (carLength + 0.35) / math.max(0.1, linearSpeed),
    );
  }

  static double queueOffset(double cooldown, [double duration = releaseCooldown]) {
    if (cooldown <= 0) return 0.0;
    final age = duration - cooldown;
    return queueSpacing * (1.0 - smoother((age - 0.27) / (duration - 0.27)));
  }

  static double launchBayPulse(double cooldown, [double duration = releaseCooldown]) {
    if (cooldown <= 0) return 0.0;
    final age = math.max(0.0, duration - cooldown);
    final t = clamp01(age / 0.42);
    return math.sin(t * math.pi);
  }

  static List<({int id, double distance, double travel})> queueLayout(
    int nextId,
    double cooldown,
    double duration,
  ) {
    final shift = queueOffset(cooldown, duration);
    final travel = nextId * queueSpacing - shift;
    return List.generate(
      queueCount,
      (index) => (
        id: nextId + index,
        distance: -index * queueSpacing - shift,
        travel: travel,
      ),
    );
  }

  static double paceForMerges(double baseSpeed, int cleanMerges) {
    final base = (baseSpeed.isFinite && baseSpeed > 0) ? baseSpeed : baseTrafficSpeed;
    final progress = clamp01(cleanMerges / fullPaceMerges);
    return base * (1.0 + (maxPaceMultiplier - 1.0) * progress);
  }

  /// Separating Axis Theorem (SAT) oriented bounding box overlap
  static bool carsOverlap(
    ({double x, double z, double fx, double fz}) pa,
    ({double x, double z, double fx, double fz}) pb,
  ) {
    final dx = pb.x - pa.x;
    final dz = pb.z - pa.z;
    if (dx * dx + dz * dz >
        (carLength * carLength + carWidth * carWidth) * 0.92 * 0.92) {
      return false;
    }

    final axes = [
      [pa.fx, pa.fz],
      [-pa.fz, pa.fx],
      [pb.fx, pb.fz],
      [-pb.fz, pb.fx],
    ];
    final hl = carLength * 0.46;
    final hw = carWidth * 0.46;

    for (final axis in axes) {
      final ax = axis[0];
      final az = axis[1];
      final ra = hl * (ax * pa.fx + az * pa.fz).abs() +
          hw * (ax * -pa.fz + az * pa.fx).abs();
      final rb = hl * (ax * pb.fx + az * pb.fz).abs() +
          hw * (ax * -pb.fz + az * pb.fx).abs();
      if ((dx * ax + dz * az).abs() >= ra + rb) {
        return false;
      }
    }
    return true;
  }

  static ({
    double push,
    double lift,
    double yaw,
    double pitch,
    double roll,
    double sx,
    double sy,
  }) crashMotion(double time, double side) {
    final t = math.max(0.0, time);
    final out = smooth2(t / 0.22);
    final settle = smooth2((t - 0.22) / 0.45);
    final squeeze = math.sin(clamp01(t / 0.32) * math.pi);
    return (
      push: 0.23 * out - 0.065 * settle,
      lift: 0.15 * math.sin(clamp01(t / 0.4) * math.pi),
      yaw: side * (0.3 * out - 0.13 * settle),
      pitch: -0.07 * squeeze,
      roll: side * 0.1 * squeeze,
      sx: 1.0 + 0.035 * squeeze,
      sy: 1.0 - 0.17 * squeeze,
    );
  }

  static ({double x, double z}) crashJolt(double time) {
    if (time < 0 || time > 0.55) {
      return (x: 0.0, z: 0.0);
    }
    final fade = math.exp(-time * 9.0);
    return (
      x: math.sin(time * 73.0) * 0.045 * fade,
      z: math.sin(time * 57.0) * 0.028 * fade,
    );
  }

  static ({
    bool visible,
    double opacity,
    double height,
    double scale,
  }) rewardMotion(double age) {
    final t = math.max(0.0, age);
    final fadeIn = smooth2(t / 0.13);
    final fadeOut = 1.0 - smooth2((t - 1.07) / 0.38);
    return (
      visible: t < rewardLife,
      opacity: fadeIn * fadeOut,
      height: 1.48 + smooth2(t / rewardLife) * 0.78,
      scale: 0.76 +
          0.24 * smooth2(t / 0.16) +
          math.sin(clamp01(t / 0.32) * math.pi) * 0.085,
    );
  }

  static ({double x, double z, double fx, double fz}) poseAtTravel({
    required String path,
    required double angle,
    required double currentTravel,
    required double distance,
    bool hasLaunchAge = false,
  }) {
    if (path == 'ramp' || hasLaunchAge) {
      return approachPose(distance);
    }
    return ringPose(angle + (currentTravel - distance) / radius);
  }

  static double pathCurvature({
    required String path,
    required double angle,
    required double currentTravel,
    bool hasLaunchAge = false,
  }) {
    if (path == 'waiting') return 0.0;
    const epsilon = 0.025;
    final a = poseAtTravel(
      path: path,
      angle: angle,
      currentTravel: currentTravel,
      distance: currentTravel - epsilon,
      hasLaunchAge: hasLaunchAge,
    );
    final b = poseAtTravel(
      path: path,
      angle: angle,
      currentTravel: currentTravel,
      distance: currentTravel + epsilon,
      hasLaunchAge: hasLaunchAge,
    );
    final ha = math.atan2(a.fx, a.fz);
    final hb = math.atan2(b.fx, b.fz);
    return math.atan2(math.sin(hb - ha), math.cos(hb - ha)) / (epsilon * 2.0);
  }

  static DrivingState advanceDriving(
    DrivingState? previous, {
    required String path,
    required double angle,
    required double travel,
    required double dt,
    bool hasLaunchAge = false,
    bool crashed = false,
    bool waiting = false,
  }) {
    final step = dt.isFinite ? dt.clamp(0.0, 0.11) : 0.0;
    final distance = travel;
    var prev = previous;
    if (prev == null || distance < prev.lastTravel - 1e-6) {
      prev = DrivingState(
        lastTravel: distance,
        curve: (path == 'ring' || path == 'ramp')
            ? pathCurvature(
                path: path,
                angle: angle,
                currentTravel: distance,
                hasLaunchAge: hasLaunchAge,
              )
            : 0.0,
      );
    }
    final moved = math.max(0.0, distance - prev.lastTravel);
    final measured = step > 1e-8 ? moved / step : 0.0;
    final curve = waiting
        ? 0.0
        : pathCurvature(
            path: path,
            angle: angle,
            currentTravel: distance,
            hasLaunchAge: hasLaunchAge,
          );
    final spd = crashed ? 0.0 : damp(prev.speed, measured, 16.0, step);
    final accel = step > 1e-8 ? (spd - prev.speed) / step : 0.0;
    final targetRoll = (waiting || crashed)
        ? 0.0
        : (curve * spd * spd * 0.012).clamp(-0.105, 0.105);
    final targetPitch = crashed
        ? 0.0
        : (-accel * (waiting ? 0.0025 : 0.003)).clamp(-0.045, 0.035);

    final steer = [0, 1].map((i) {
      final x = i == 0 ? -halfTrack : halfTrack;
      final target = (waiting || crashed)
          ? 0.0
          : math.atan(wheelbase * curve / (1.0 - x * curve)).clamp(-0.48, 0.48);
      return damp(prev!.steer[i], target, 20.0, step);
    }).toList();

    final averageCurve = (prev.curve + curve) / 2.0;
    final wheels = List<double>.generate(4, (i) {
      final prevAngle = prev!.wheels[i];
      if (crashed) return prevAngle;
      final x = i < 2 ? -halfTrack : halfTrack;
      final lateral = 1.0 - x * averageCurve;
      final turnRatio = waiting
          ? 1.0
          : (i % 2 == 1
              ? hypot(lateral, averageCurve * wheelbase)
              : lateral.abs());
      return prevAngle + moved * turnRatio / wheelRadius;
    });

    return DrivingState(
      lastTravel: distance,
      speed: spd,
      curve: curve,
      roll: damp(prev.roll, targetRoll, 12.0, step),
      pitch: damp(prev.pitch, targetPitch, 13.0, step),
      steer: steer,
      wheels: wheels,
    );
  }

  static ({
    double lift,
    double pitch,
    double roll,
    double sx,
    double sy,
    double sz,
    double wheelRoll,
  }) sampleCarMotion({
    required int id,
    required String path,
    required double travel,
    required double launchAge,
    required double progress,
    double? mergeAge,
    required double time,
    bool crashed = false,
    bool waiting = false,
  }) {
    double lift = 0.0;
    double pitch = 0.0;
    double roll = 0.0;
    double sx = 1.0;
    double sy = 1.0;
    double sz = 1.0;
    double wheelRoll = 0.0;

    if (waiting) {
      if (!crashed) {
        sy = 1.0 + math.sin(time * 2.8 + id) * 0.012;
        pitch = math.sin(time * 2.0 + id) * 0.008;
      }
      return (
        lift: lift,
        pitch: pitch,
        roll: roll,
        sx: sx,
        sy: sy,
        sz: sz,
        wheelRoll: wheelRoll,
      );
    }

    wheelRoll = travel / wheelRadius;
    if (crashed) {
      return (
        lift: lift,
        pitch: pitch,
        roll: roll,
        sx: sx,
        sy: sy,
        sz: sz,
        wheelRoll: wheelRoll,
      );
    }

    final distance = travel;
    final phase = distance * 3.5 + id * 1.7;
    final moving = path == 'ramp'
        ? smoother((launchAge - anticipation) / acceleration)
        : 1.0;

    lift = (0.006 + 0.005 * math.sin(phase)) * moving;
    roll = math.sin(distance * 2.4 + id * 1.3) * 0.004 * moving;
    pitch = math.sin(phase * 0.61) * 0.006 * moving;

    if (path == 'ramp') {
      final age = launchAge;
      final squash = age < anticipation
          ? math.sin(age / anticipation * math.pi) * 0.1
          : 0.0;
      final t = math.max(0.0, age - anticipation);
      final spring = math.sin(t * 13.0) * math.exp(-t * 5.0);
      sy = 1.0 - squash + spring * 0.07;
      sx = 1.0 + squash * 0.2;
      sz = 1.0 + squash * 0.15;
      pitch = -math.sin(clamp01(t / 0.45) * math.pi) * 0.065;
      roll += 0.004 * smoother(progress / 3.8);
    }

    if (mergeAge != null && mergeAge < 0.8) {
      final t = mergeAge;
      final pulse = math.sin(t * 13.0) * math.exp(-t * 5.0);
      lift += math.max(0.0, pulse) * 0.055;
      sy += pulse * 0.09;
      sx -= pulse * 0.012;
      pitch += pulse * 0.03;
    }

    return (
      lift: lift,
      pitch: pitch,
      roll: roll,
      sx: sx,
      sy: sy,
      sz: sz,
      wheelRoll: wheelRoll,
    );
  }
}
