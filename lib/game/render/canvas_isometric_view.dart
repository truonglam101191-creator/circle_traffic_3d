import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../math/traffic_math.dart';
import '../model/game_state.dart';

class CanvasIsometricView extends StatelessWidget {
  final GameTrafficState state;
  final double time;

  const CanvasIsometricView({
    super.key,
    required this.state,
    required this.time,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _TrafficPainter(state: state, time: time),
      size: Size.infinite,
    );
  }
}

class _TrafficPainter extends CustomPainter {
  final GameTrafficState state;
  final double time;

  _TrafficPainter({required this.state, required this.time});

  // Project 3D World (X, Y, Z) to 2D Screen with the game's orthographic angle
  // Height: 12.8, Depth: 17.8, TargetZ: 2.9
  Offset _project(double x, double y, double z, Size size) {
    final cx = size.width / 2.0;
    final cy = size.height * 0.42;
    const scale = 28.0;

    // Angle of inclination matching Camera (height: 12.8, depth: 17.8)
    const cosAngle = 0.81; // cos(inclination)
    const sinAngle = 0.58; // sin(inclination)

    final sx = cx + x * scale;
    final sy = cy + (z - CameraConfig.targetZ) * cosAngle * scale - y * sinAngle * scale;
    return Offset(sx, sy);
  }

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Draw Ground / Lawn
    final lawnPaint = Paint()..color = const Color(0xFFA6C96C);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), lawnPaint);

    // 2. Draw Roundabout Road
    final roadPaint = Paint()
      ..color = const Color(0xFF443B48)
      ..style = PaintingStyle.stroke
      ..strokeWidth = (TrafficMath.outerRadius - TrafficMath.innerRadius) * 28.0;

    final roadCenter = _project(0, 0, 0, size);
    final roadRadius = TrafficMath.radius * 28.0;
    final rect = Rect.fromCircle(center: roadCenter, radius: roadRadius);

    // Squashed circle (isometric projection)
    canvas.save();
    canvas.translate(roadCenter.dx, roadCenter.dy);
    canvas.scale(1.0, 0.81);
    canvas.translate(-roadCenter.dx, -roadCenter.dy);
    canvas.drawCircle(roadCenter, roadRadius, roadPaint);

    // Edge borders
    final edgePaint = Paint()
      ..color = const Color(0xFFFFE2C6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawCircle(roadCenter, TrafficMath.outerRadius * 28.0, edgePaint);
    canvas.drawCircle(roadCenter, TrafficMath.innerRadius * 28.0, edgePaint);

    // Ring road dashed markings
    final dashPaint = Paint()
      ..color = const Color(0xFFFFCC32)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    const ringDashes = 24;
    for (int i = 0; i < ringDashes; i += 2) {
      final a0 = (i / ringDashes) * TrafficMath.tau;
      final a1 = ((i + 0.8) / ringDashes) * TrafficMath.tau;
      canvas.drawArc(rect, a0, a1 - a0, false, dashPaint);
    }
    canvas.restore();

    // 3. Draw Feeder Ramp Road
    final rampPath = Path();
    final pStart = _project(TrafficMath.queueX, 0, TrafficMath.queueZ, size);
    rampPath.moveTo(pStart.dx, pStart.dy);

    for (int i = 0; i <= 60; i++) {
      final d = (TrafficMath.rampLength) * (i / 60.0);
      final p = TrafficMath.approachPose(d);
      final sp = _project(p.x, 0, p.z, size);
      rampPath.lineTo(sp.dx, sp.dy);
    }

    final rampRoadPaint = Paint()
      ..color = const Color(0xFF443B48)
      ..style = PaintingStyle.stroke
      ..strokeWidth = TrafficMath.entryHalfWidth * 2.0 * 28.0
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(rampPath, rampRoadPaint);

    // 4. Center Park Trees
    _drawTree(canvas, size, 0.0, 0.0, 1.1, const Color(0xFF66DCB7));
    _drawTree(canvas, size, -1.2, 0.8, 0.9, const Color(0xFFC179E3));
    _drawTree(canvas, size, 1.1, -0.9, 0.85, const Color(0xFFFFC735));
    _drawTree(canvas, size, -0.7, -1.3, 0.95, const Color(0xFF20BCE3));
    _drawTree(canvas, size, 1.4, 0.7, 0.9, const Color(0xFFFF702E));

    // 5. Draw Active Cars
    for (final car in state.cars) {
      _drawCar(canvas, size, car);
    }

    // 6. Draw Waiting Car at queue if not crashed
    if (!state.crashed) {
      final queuePose = TrafficMath.approachPose(0.0);
      _drawCarAt(
        canvas,
        size,
        queuePose.x,
        queuePose.z,
        queuePose.fx,
        queuePose.fz,
        state.nextId % GameTheme.accentColors.length,
        isWaiting: true,
      );
    }
  }

  void _drawTree(Canvas canvas, Size size, double x, double z, double s, Color color) {
    final pt = _project(x, 0, z, size);
    final trunkPaint = Paint()..color = const Color(0xFF5D4037);
    canvas.drawRect(
      Rect.fromCenter(center: pt - Offset(0, 6 * s), width: 6 * s, height: 14 * s),
      trunkPaint,
    );

    // Foliage tiers
    final leavesPaint = Paint()..color = color;
    canvas.drawCircle(pt - Offset(0, 18 * s), 16 * s, leavesPaint);
    canvas.drawCircle(pt - Offset(0, 28 * s), 12 * s, leavesPaint);
    canvas.drawCircle(pt - Offset(0, 36 * s), 8 * s, leavesPaint);
  }

  void _drawCar(Canvas canvas, Size size, CarModel car) {
    final pose = car.pose;
    final motion = TrafficMath.sampleCarMotion(
      id: car.id,
      path: car.path,
      travel: car.travel,
      launchAge: car.launchAge,
      progress: car.progress,
      mergeAge: car.mergeAge,
      time: time,
    );

    double px = pose.x;
    double pz = pose.z;
    double py = motion.lift;
    double fx = pose.fx;
    double fz = pose.fz;

    if (state.crashed &&
        state.impact != null &&
        state.impact!.ids.contains(car.id)) {
      final side = state.impact!.ids[0] == car.id ? -1.0 : 1.0;
      final crash = TrafficMath.crashMotion(state.crashTime, side);
      px += -pose.fz * side * crash.push;
      pz += pose.fx * side * crash.push;
      py += crash.lift;
      final yaw = math.atan2(fx, fz) + crash.yaw;
      fx = math.sin(yaw);
      fz = math.cos(yaw);
    }

    _drawCarAt(
      canvas,
      size,
      px,
      pz,
      fx,
      fz,
      car.colorIndex,
      lift: py,
      scaleX: motion.sx,
      scaleY: motion.sy,
    );
  }

  void _drawCarAt(
    Canvas canvas,
    Size size,
    double x,
    double z,
    double fx,
    double fz,
    int colorIdx, {
    double lift = 0.0,
    double scaleX = 1.0,
    double scaleY = 1.0,
    bool isWaiting = false,
  }) {
    final pt = _project(x, lift, z, size);
    final colorHex = GameTheme.accentColors[colorIdx % GameTheme.accentColors.length];
    final colorVal = int.parse(colorHex.replaceAll('#', ''), radix: 16);
    final paintColor = Color(colorVal | 0xFF000000);

    final angle = math.atan2(fx, fz * 0.81);

    canvas.save();
    canvas.translate(pt.dx, pt.dy);
    canvas.rotate(-angle + math.pi / 2.0);
    canvas.scale(scaleX, scaleY);

    // Car Shadow
    final shadowPaint = Paint()..color = const Color(0x33000000);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: const Offset(2, 3), width: 42, height: 26),
        const Radius.circular(8),
      ),
      shadowPaint,
    );

    // Car Wheels
    final wheelPaint = Paint()..color = const Color(0xFF212124);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: const Offset(-12, -14), width: 10, height: 6),
        const Radius.circular(2),
      ),
      wheelPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: const Offset(12, -14), width: 10, height: 6),
        const Radius.circular(2),
      ),
      wheelPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: const Offset(-12, 14), width: 10, height: 6),
        const Radius.circular(2),
      ),
      wheelPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: const Offset(12, 14), width: 10, height: 6),
        const Radius.circular(2),
      ),
      wheelPaint,
    );

    // Car Chassis Body
    final bodyPaint = Paint()..color = paintColor;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset.zero, width: 40, height: 24),
        const Radius.circular(7),
      ),
      bodyPaint,
    );

    // Car Cabin / Windows
    final cabinPaint = Paint()..color = const Color(0xFF1E2638);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: const Offset(-2, 0), width: 22, height: 18),
        const Radius.circular(5),
      ),
      cabinPaint,
    );

    // Car Roof
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: const Offset(-2, 0), width: 14, height: 14),
        const Radius.circular(4),
      ),
      bodyPaint,
    );

    // Headlights
    final lightPaint = Paint()..color = const Color(0xFFFFEE55);
    canvas.drawCircle(const Offset(19, -7), 2.5, lightPaint);
    canvas.drawCircle(const Offset(19, 7), 2.5, lightPaint);

    // Taillights
    final tailPaint = Paint()..color = const Color(0xFFFF2222);
    canvas.drawCircle(const Offset(-19, -7), 2.2, tailPaint);
    canvas.drawCircle(const Offset(-19, 7), 2.2, tailPaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _TrafficPainter oldDelegate) => true;
}
