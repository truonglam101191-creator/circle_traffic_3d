import 'dart:math' as math;
import 'package:flutter/material.dart' show Offset, Size;
import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart';
import '../../domain/services/traffic_math_service.dart';
import '../../domain/entities/circle_traffic_models.dart';
import '../../domain/entities/game_traffic_state.dart';
import 'mesh_builder.dart';

class _CarCacheKey {
  final int kind;
  final int colorIndex;
  const _CarCacheKey(this.kind, this.colorIndex);

  @override
  bool operator ==(Object other) =>
      other is _CarCacheKey &&
      other.kind == kind &&
      other.colorIndex == colorIndex;

  @override
  int get hashCode => Object.hash(kind, colorIndex);
}

class _CarTemplate {
  final Mesh combinedMesh; // [outlinePrimitive, chassisWithWheelsPrimitive]
  const _CarTemplate({required this.combinedMesh});
}

class _CarInstance {
  final int id;
  final Node root;
  int currentKind;
  int currentColorIdx;
  DrivingState? driving;
  bool waiting = false;
  double animLift = 0.0;
  double animPitch = 0.0;
  double animRoll = 0.0;
  double animSx = 1.0;
  double animSy = 1.0;
  double animSz = 1.0;

  _CarInstance({
    required this.id,
    required this.root,
    required this.currentKind,
    required this.currentColorIdx,
  });
}

class _QueueEntry {
  final int id;
  final double born;
  const _QueueEntry({required this.id, required this.born});
}

class _EffectParticle {
  final Node node;
  final bool isStar;
  double born = -100.0;
  double x = 0.0;
  double z = 0.0;
  double vx = 0.0;
  double vz = 0.0;
  int seed = 0;

  _EffectParticle({required this.node, required this.isStar});
}

/// Manages the 3D `flutter_scene` Scene Graph, Camera, Road, Park Island,
/// Launch Cradle, Toy Cars, Waiting Queue, and Effects.
class Scene3DWorld {
  final Scene scene = Scene();
  late final Node _worldRoot;

  // Classic track & park groups
  Node? _classicRoadGroup;
  Node? _classicParkGroup;
  Node? _cradleGroup;

  // Dynamic stage track & park groups (for 100 stages & 6 game modes)
  Node? _stageRoadGroup;
  Node? _stageParkGroup;
  String _currentTrackKey = 'classic';
  final Map<String, ({Node group, double queueX, double queueZ})>
      _stageRoadCache = {};
  Node? _cachedFigure8Park;
  Node? _cachedFigure890Park;

  final Map<_CarCacheKey, _CarTemplate> _carTemplates = {};
  final Map<int, MeshPrimitive> _carOutlineCache = {};
  final Map<int, _CarInstance> _carNodes = {};
  final List<Node> _freeCarNodes = [];
  final Set<int> _aliveIdsScratch = <int>{};
  final List<int> _toRemoveScratch = <int>[];
  List<_QueueEntry> _queueEntries = [];

  // Launch cradle dynamic nodes
  Node? _cradlePodNode;
  final List<Node> _cradleRails = [];
  final List<Node> _cradleArrows = [];
  double _activeQueueX = TrafficMath.queueX;
  double _activeQueueZ = TrafficMath.queueZ;
  double _lastCradlePulse = -1.0;

  // Batched pine foliage node (single draw call instead of 48 nodes)
  Node? _pineFoliageNode;
  int _lastMergeSerial = 0;
  double _celebrationTime = -100.0;

  // Effects
  final List<_EffectParticle> _particles = [];
  final List<_EffectParticle> _starParticles = [];
  final List<_EffectParticle> _puffParticles = [];
  final List<({Node node, double born})> _effectRings = [];
  int? _lastNextId;
  int _lastCleanMerges = 0;
  int _lastQueueLen = 0;
  int? _lastConvertedCarId;

  // Cached static camera when not crashing
  Size? _cachedCameraScreenSize;
  Camera? _cachedStaticCamera;

  // Crash effects
  Node? _crashGroup;
  Node? _crashBurst;
  final List<Node> _crashSmoke = [];
  final List<Node> _crashSparks = [];
  final List<Node> _crashSkids = [];

  double? _lastDrawTime;
  bool _initialized = false;
  bool get isInitialized => _initialized;

  Mesh _m(MeshPrimitive p) => Mesh.primitives(primitives: [p]);

  Future<void> _yieldFrame() =>
      Future<void>.delayed(const Duration(milliseconds: 16));

  Future<void> initialize({
    GameTrafficState? initialState,
    void Function()? onProgress,
  }) async {
    if (_initialized) return;
    await Scene.initializeStaticResources();
    TrafficMath.initialize();

    // Transparent background so backdrop.webp shows through behind the 3D scene
    scene.skybox = null;
    scene.toneMapping = ToneMappingMode.linear;
    scene.exposure = 1.0;
    scene.antiAliasingMode = AntiAliasingMode.none;
    scene.ambientOcclusion.enabled = false;
    scene.screenSpaceReflections.enabled = false;
    scene.debugCheckCoplanarOverlaps = false;

    // Root node reflects Z so child nodes use exact Three.js (x, y, z) coordinates
    // while flutter_scene's camera at -Z views +X right, +Y up, +Z toward viewer.
    _worldRoot = Node(
      name: 'threejs-world-root',
      localTransform: Matrix4.diagonal3Values(1.0, 1.0, -1.0),
    );
    scene.root.add(_worldRoot);

    _buildLaunchCradle();
    _buildCarTemplates();
    onProgress?.call();
    await _yieldFrame();

    await _buildParkAndTrees(onProgress: onProgress);

    if (initialState != null) {
      _currentTrackKey =
          initialState.useStagePaths ? initialState.trackKey : 'classic';
      _rebuildStageTrack(initialState);
      onProgress?.call();
      await _yieldFrame();

      await _prewarmInitialCarTemplates(
        initialState,
        onProgress: onProgress,
      );
    }

    _buildEffects();
    onProgress?.call();
    await _yieldFrame();

    _buildCrashEffects();

    _initialized = true;
  }

  Future<void> _prewarmInitialCarTemplates(
    GameTrafficState state, {
    void Function()? onProgress,
  }) async {
    final keysToWarm = <_CarCacheKey>{
      // Pre-warm all 6 standard car colors so releasing any player car is a 100% cache hit
      for (int cIdx = 0; cIdx < GameTheme.accentHexColors.length; cIdx++)
        _CarCacheKey(cIdx % 3, cIdx),
    };
    if (state.useStagePaths) {
      for (final car in state.cars) {
        final cIdx = car.colorIndex % GameTheme.accentHexColors.length;
        final kind = _resolveTemplateKind(
          car.vehicleType,
          car.role,
          car.id,
          colorIdx: cIdx,
        );
        final normColor = (kind == 7 || kind == 8) ? 0 : cIdx;
        keysToWarm.add(_CarCacheKey(kind, normColor));
      }
      for (final q in state.queue) {
        final cIdx = q.colorIndex % GameTheme.accentHexColors.length;
        final kind = _resolveTemplateKind(
          q.vehicleType,
          q.role,
          q.id,
          colorIdx: cIdx,
        );
        final normColor = (kind == 7 || kind == 8) ? 0 : cIdx;
        keysToWarm.add(_CarCacheKey(kind, normColor));
      }
    }

    for (final key in keysToWarm) {
      if (!_carTemplates.containsKey(key)) {
        _getCarTemplate(key.kind, key.colorIndex);
        onProgress?.call();
        await _yieldFrame();
      }
    }
  }

  /// Builds the elevated 3D road deck, deep side walls, perimeter curbs/seams,
  /// and 48 ring + entry capsule dashes (matching road-model.js & markings.mjs).
  void _buildRoad() {
    final roadGroup = Node(name: 'road-group');
    final footprint = TrafficMath.roadFootprint();
    final outer = footprint.outer;
    final inner = footprint.inner;

    final deckBuilder = CartoonMeshBuilder();
    const surfaceY = TrafficMath.surfaceY;
    const bottomY = surfaceY - TrafficMath.roadDepth;
    const roadHex = 0x443B48;
    const wallHex = 0x2D2336;

    final topColor = CartoonMeshBuilder.shadeColor(roadHex, 0, 1, 0);

    // 1A. Circular ring asphalt top surface (innerRadius to outerRadius)
    const ringSegments = 128;
    final innerRingStart = deckBuilder.vertexCount;
    for (int i = 0; i <= ringSegments; i++) {
      final a = (i / ringSegments) * math.pi * 2.0;
      final ca = math.cos(a), sa = math.sin(a);
      deckBuilder.addVertex(
        ca * TrafficMath.innerRadius,
        surfaceY,
        sa * TrafficMath.innerRadius,
        0,
        1,
        0,
        topColor,
      );
      deckBuilder.addVertex(
        ca * TrafficMath.outerRadius,
        surfaceY,
        sa * TrafficMath.outerRadius,
        0,
        1,
        0,
        topColor,
      );
    }
    for (int i = 0; i < ringSegments; i++) {
      final b = innerRingStart + i * 2;
      deckBuilder.addQuad(b, b + 1, b + 3, b + 2);
    }

    // 1B. Approach ramp asphalt top surface (from -queueTail into ring)
    const rampSteps = 84;
    const dStart = -TrafficMath.queueTail;
    const dEnd = 4.35;
    final rampStartIdx = deckBuilder.vertexCount;
    for (int i = 0; i <= rampSteps; i++) {
      final d = dStart + (dEnd - dStart) * (i / rampSteps);
      final pose = TrafficMath.approachPose(d);
      final leftPt = TrafficMath.offset(pose, -1.0);
      final rightPt = TrafficMath.offset(pose, 1.0);
      deckBuilder.addVertex(leftPt.x, surfaceY, leftPt.z, 0, 1, 0, topColor);
      deckBuilder.addVertex(rightPt.x, surfaceY, rightPt.z, 0, 1, 0, topColor);
    }
    for (int i = 0; i < rampSteps; i++) {
      final b = rampStartIdx + i * 2;
      deckBuilder.addQuad(b, b + 2, b + 3, b + 1);
    }

    // 1C. Rounded tail cap at (queueX, queueZ + queueTail)
    final tailCenterIdx = deckBuilder.addVertex(
      TrafficMath.queueX,
      surfaceY,
      TrafficMath.queueZ + TrafficMath.queueTail,
      0,
      1,
      0,
      topColor,
    );
    final tailStart = deckBuilder.vertexCount;
    const tailSegs = 24;
    for (int i = 0; i <= tailSegs; i++) {
      final a = (i / tailSegs) * math.pi;
      deckBuilder.addVertex(
        TrafficMath.queueX + math.cos(a) * TrafficMath.entryHalfWidth,
        surfaceY,
        TrafficMath.queueZ +
            TrafficMath.queueTail +
            math.sin(a) * TrafficMath.entryHalfWidth,
        0,
        1,
        0,
        topColor,
      );
    }
    for (int i = 0; i < tailSegs; i++) {
      deckBuilder.addTriangle(tailCenterIdx, tailStart + i + 1, tailStart + i);
    }

    // 2. Extruded side walls along outer and inner boundary loops
    void addSideWall(List<({double x, double z})> loop, {required bool isInner}) {
      final m = loop.length;
      for (int i = 0; i < m; i++) {
        final p0 = loop[i];
        final p1 = loop[(i + 1) % m];
        final dx = p1.x - p0.x;
        final dz = p1.z - p0.z;
        final len = TrafficMath.hypot(dx, dz);
        if (len < 1e-6) continue;
        final nx = (isInner ? -1.0 : 1.0) * (-dz / len);
        final nz = (isInner ? -1.0 : 1.0) * (dx / len);
        final cTop = CartoonMeshBuilder.shadeColor(wallHex, nx, 0.15, nz);
        final cBot =
            CartoonMeshBuilder.shadeColor(wallHex, nx, -0.25, nz, scalar: 0.88);
        final i0 = deckBuilder.addVertex(p0.x, surfaceY, p0.z, nx, 0, nz, cTop);
        final i1 = deckBuilder.addVertex(p1.x, surfaceY, p1.z, nx, 0, nz, cTop);
        final i2 = deckBuilder.addVertex(p1.x, bottomY, p1.z, nx, 0, nz, cBot);
        final i3 = deckBuilder.addVertex(p0.x, bottomY, p0.z, nx, 0, nz, cBot);
        deckBuilder.addQuad(i0, i1, i2, i3);
      }
    }

    addSideWall(outer, isInner: false);
    addSideWall(inner, isInner: true);

    // 3. Perimeter tubes (curb edge, two purple wall seams, dark bottom trim)
    for (final loop in [outer, inner]) {
      deckBuilder.addPerimeterTube(
        loop: loop,
        y: surfaceY,
        radius: 0.034,
        hexColor: 0xFFE2C6,
        tubeSegments: 6,
        stepStride: 2,
      );
      deckBuilder.addPerimeterTube(
        loop: loop,
        y: -0.23,
        radius: 0.016,
        hexColor: 0x9468BC,
        tubeSegments: 5,
        stepStride: 2,
      );
      deckBuilder.addPerimeterTube(
        loop: loop,
        y: -0.61,
        radius: 0.018,
        hexColor: 0x9468BC,
        tubeSegments: 5,
        stepStride: 2,
      );
      deckBuilder.addPerimeterTube(
        loop: loop,
        y: -TrafficMath.roadDepth + 0.01,
        radius: 0.028,
        hexColor: 0x38243E,
        tubeSegments: 5,
        stepStride: 2,
      );
    }

    roadGroup.add(
      Node(
        name: 'road-deck',
        mesh: _m(deckBuilder.build(doubleSided: true)),
      ),
    );

    // 4. Center yellow capsule dashes (48 ring + entry ramp)
    final dashBuilder = CartoonMeshBuilder();
    final markings = TrafficMath.createMarkingLayout();
    final allDashes = [...markings.ring, ...markings.entry];
    final dashContour = CartoonMeshBuilder.roundedRectContour(
      TrafficMath.dashWidth,
      TrafficMath.dashLength,
      TrafficMath.dashWidth / 2.0,
      cornerSegments: 5,
    );
    final dashColor =
        CartoonMeshBuilder.shadeColor(0xFFCC32, 0, 1, 0, unlit: true);
    const dashY = surfaceY + 0.010;

    for (final d in allDashes) {
      final yaw = math.atan2(d.fx, d.fz);
      final cy = math.cos(yaw), sy = math.sin(yaw);
      final cIdx = dashBuilder.addVertex(d.x, dashY, d.z, 0, 1, 0, dashColor);
      final start = dashBuilder.vertexCount;
      for (final p in dashContour) {
        final rx = p.x * cy + p.z * sy;
        final rz = -p.x * sy + p.z * cy;
        dashBuilder.addVertex(
          d.x + rx,
          dashY,
          d.z + rz,
          0,
          1,
          0,
          dashColor,
        );
      }
      final n = dashContour.length;
      for (int i = 0; i < n; i++) {
        dashBuilder.addTriangle(cIdx, start + i, start + (i + 1) % n);
      }
    }

    roadGroup.add(
      Node(
        name: 'road-markings',
        mesh: _m(dashBuilder.build(doubleSided: true, depthLayer: 1)),
      ),
    );

    _classicRoadGroup = roadGroup;
    _worldRoot.add(roadGroup);
  }

  /// Dynamically builds (or reuses cached) 3D Stage Track for any of the 7 loop shapes,
  /// figure-8 elevated overpass bridge, entrance ramp, and glowing green exit road.
  void _rebuildStageTrack(GameTrafficState state) {
    if (_stageRoadGroup != null) {
      _worldRoot.remove(_stageRoadGroup!);
      _stageRoadGroup = null;
    }
    if (_stageParkGroup != null) {
      _worldRoot.remove(_stageParkGroup!);
      _stageParkGroup = null;
    }

    if (!state.useStagePaths || state.loop == null || state.entrance == null) {
      if (_classicRoadGroup == null) {
        _buildRoad();
      }
      _classicRoadGroup?.visible = true;
      _classicParkGroup?.visible = true;
      _activeQueueX = TrafficMath.queueX;
      _activeQueueZ = TrafficMath.queueZ;
      _cradleGroup?.position = Vector3.zero();
      return;
    }

    _classicRoadGroup?.visible = false;
    final loop = state.loop!;
    final entrance = state.entrance!;
    final exit = state.exit;
    final trackKey = state.trackKey;

    final cachedRoad = _stageRoadCache[trackKey];
    if (cachedRoad != null) {
      _stageRoadGroup = cachedRoad.group;
      _worldRoot.add(cachedRoad.group);
      _activeQueueX = cachedRoad.queueX;
      _activeQueueZ = cachedRoad.queueZ;
      _cradleGroup?.position = Vector3(
        _activeQueueX - TrafficMath.queueX,
        0.0,
        _activeQueueZ - TrafficMath.queueZ,
      );
      _lastCradlePulse = -1.0;
      if (loop.meta != null) {
        _adaptParkForShape(loop.meta!);
      }
      return;
    }

    final stageGroup = Node(name: 'stage-road-group-$trackKey');
    final deckBuilder = CartoonMeshBuilder();
    final dashBuilder = CartoonMeshBuilder();

    const surfaceY = TrafficMath.surfaceY;
    const bottomY = surfaceY - TrafficMath.roadDepth;
    const roadHex = 0x443B48;
    const bridgeRoadHex = 0x524658;
    const wallHex = 0x2D2336;
    const curbHex = 0xFFE2C6;
    const seamHex = 0x9468BC;

    final topColor = CartoonMeshBuilder.shadeColor(roadHex, 0, 1, 0);
    final bridgeTopColor = CartoonMeshBuilder.shadeColor(bridgeRoadHex, 0, 1, 0);
    final curbColor = CartoonMeshBuilder.shadeColor(curbHex, 0, 1, 0);
    final seamColor = CartoonMeshBuilder.shadeColor(seamHex, 0, 1, 0, unlit: true);
    final dashColor =
        CartoonMeshBuilder.shadeColor(0xFFCC32, 0, 1, 0, unlit: true);

    final dashContour = CartoonMeshBuilder.roundedRectContour(
      TrafficMath.dashWidth,
      TrafficMath.dashLength,
      TrafficMath.dashWidth / 2.0,
      cornerSegments: 3,
    );

    void addDashAt(double x, double y, double z, double fx, double fz, Vector4 col) {
      final yaw = math.atan2(fx, fz);
      final cy = math.cos(yaw), sy = math.sin(yaw);
      final cIdx = dashBuilder.addVertex(x, y, z, 0, 1, 0, col);
      final start = dashBuilder.vertexCount;
      for (final p in dashContour) {
        final rx = p.x * cy + p.z * sy;
        final rz = -p.x * sy + p.z * cy;
        dashBuilder.addVertex(x + rx, y, z + rz, 0, 1, 0, col);
      }
      final n = dashContour.length;
      for (int i = 0; i < n; i++) {
        dashBuilder.addTriangle(cIdx, start + i, start + (i + 1) % n);
      }
    }

    // Helper to extrude a 3D road ribbon with side walls, curbs, wall seams, and dashes
    final scratch = CTPose();
    const loopSteps = 96;
    const roadHalfW = 0.62;
    const curbW = 0.056;

    final centerPts = <({double x, double y, double z})>[];
    final leftPts = <({double x, double y, double z, double yBot, double nx, double nz})>[];
    final rightPts = <({double x, double y, double z, double yBot, double nx, double nz})>[];

    for (int i = 0; i <= loopSteps; i++) {
      final s = (i / loopSteps) * loop.len;
      loop.pointAtInto(s, scratch);
      final cx = CTDimensions.to3DX(scratch.x);
      final cz = CTDimensions.to3DZ(scratch.y);
      final ang = scratch.ang;
      final fx = math.cos(ang);
      final fz = math.sin(ang);
      // Outward right normal in XZ
      final rx = -fz;
      final rz = fx;

      final zElev = CTPathBuilder.getCarZ(s, loop);
      final yTop = surfaceY + zElev * 0.92;
      final yBot = zElev > 0.03 ? (yTop - 0.24) : bottomY;

      centerPts.add((x: cx, y: yTop, z: cz));
      leftPts.add((
        x: cx - rx * roadHalfW,
        y: yTop,
        z: cz - rz * roadHalfW,
        yBot: yBot,
        nx: -rx,
        nz: -rz,
      ));
      rightPts.add((
        x: cx + rx * roadHalfW,
        y: yTop,
        z: cz + rz * roadHalfW,
        yBot: yBot,
        nx: rx,
        nz: rz,
      ));
    }

    // Exact distance in XZ from (px, pz) to the loop centerline polyline
    double distToLoopXZ(double px, double pz) {
      double minD2 = 1e18;
      for (int j = 0; j < loopSteps; j++) {
        final a = centerPts[j];
        final b = centerPts[j + 1];
        if ((a.x - px).abs() > 1.35 && (b.x - px).abs() > 1.35) continue;
        if ((a.z - pz).abs() > 1.35 && (b.z - pz).abs() > 1.35) continue;
        final abx = b.x - a.x;
        final abz = b.z - a.z;
        final len2 = abx * abx + abz * abz;
        double t = len2 > 1e-10
            ? ((px - a.x) * abx + (pz - a.z) * abz) / len2
            : 0.0;
        if (t < 0.0) {
          t = 0.0;
        } else if (t > 1.0) {
          t = 1.0;
        }
        final dx = px - (a.x + abx * t);
        final dz = pz - (a.z + abz * t);
        final d2 = dx * dx + dz * dz;
        if (d2 < minD2) minD2 = d2;
      }
      return math.sqrt(minD2);
    }

    // Compute exact Entrance Ramp join coordinates with the outer edge of the loop road
    const entTailPx = 165.0;
    const entHalfW = 0.60;
    final entCx = CTDimensions.to3DX(entrance.queueX);
    final entXL = entCx - entHalfW;
    final entXR = entCx + entHalfW;
    final entZTail = CTDimensions.to3DZ(entrance.startY + entTailPx);

    double zLoopBottomAtX(double x) {
      double bestZ = CTDimensions.to3DZ(entrance.bottomY);
      double bestDx = 1e18;
      for (int j = 0; j <= loopSteps; j++) {
        final c = centerPts[j];
        if (c.z > 0.3) {
          final dx = (c.x - x).abs();
          if (dx < bestDx) {
            bestDx = dx;
            bestZ = c.z;
          }
        }
      }
      return bestZ;
    }

    double zOuterLoopAtX(double x) {
      double lo = zLoopBottomAtX(x);
      double hi = entZTail;
      for (int iter = 0; iter < 12; iter++) {
        final mid = (lo + hi) * 0.5;
        if (distToLoopXZ(x, mid) < roadHalfW) {
          lo = mid;
        } else {
          hi = mid;
        }
      }
      return (lo + hi) * 0.5;
    }

    final zOuterLeft = zOuterLoopAtX(entXL);
    final zOuterCenter = zOuterLoopAtX(entCx);
    final zOuterRight = zOuterLoopAtX(entXR);
    final zCenterLeft = zLoopBottomAtX(entXL);
    final zCenterRight = zLoopBottomAtX(entXR);

    // Pre-sample Exit Road centerline (if present) so we can clip the loop's outer curb at the exit mouth
    const exitSteps = 32;
    const exitLenPx = 220.0;
    const exitHalfW = 0.54;
    final exitCenterPts = <({double x, double z, double ang})>[];
    double exDirX = 0.0, exDirZ = -1.0;
    if (exit != null) {
      exDirX = exit.dir?.x ?? 0.0;
      exDirZ = exit.dir?.y ?? -1.0;
      for (int i = 0; i <= exitSteps; i++) {
        final s = (i / exitSteps) * exitLenPx;
        exit.pointAtInto(s, scratch);
        exitCenterPts.add((
          x: CTDimensions.to3DX(scratch.x),
          z: CTDimensions.to3DZ(scratch.y),
          ang: scratch.ang,
        ));
      }
    }

    double distToExitXZ(double px, double pz) {
      if (exitCenterPts.isEmpty) return 1e18;
      double minD2 = 1e18;
      for (int j = 0; j < exitSteps; j++) {
        final a = exitCenterPts[j];
        final b = exitCenterPts[j + 1];
        final abx = b.x - a.x;
        final abz = b.z - a.z;
        final len2 = abx * abx + abz * abz;
        double t = len2 > 1e-10
            ? ((px - a.x) * abx + (pz - a.z) * abz) / len2
            : 0.0;
        if (t < 0.0) {
          t = 0.0;
        } else if (t > 1.0) {
          t = 1.0;
        }
        final dx = px - (a.x + abx * t);
        final dz = pz - (a.z + abz * t);
        final d2 = dx * dx + dz * dz;
        if (d2 < minD2) minD2 = d2;
      }
      return math.sqrt(minD2);
    }

    ({double x, double y, double z, double yBot, double nx, double nz}) lerpEdgePt(
      ({double x, double y, double z, double yBot, double nx, double nz}) a,
      ({double x, double y, double z, double yBot, double nx, double nz}) b,
      double t,
    ) {
      return (
        x: a.x + (b.x - a.x) * t,
        y: a.y + (b.y - a.y) * t,
        z: a.z + (b.z - a.z) * t,
        yBot: a.yBot + (b.yBot - a.yBot) * t,
        nx: a.nx,
        nz: a.nz,
      );
    }

    void emitLoopCurbAndWall(
      ({double x, double y, double z, double yBot, double nx, double nz}) p0,
      ({double x, double y, double z, double yBot, double nx, double nz}) p1,
      bool isBridge,
    ) {
      final cy0 = p0.y + 0.012;
      final cy1 = p1.y + 0.012;
      final c0 = deckBuilder.addVertex(
        p0.x - p0.nx * curbW,
        cy0,
        p0.z - p0.nz * curbW,
        0,
        1,
        0,
        curbColor,
      );
      final c1 = deckBuilder.addVertex(
        p0.x + p0.nx * 0.015,
        cy0,
        p0.z + p0.nz * 0.015,
        0,
        1,
        0,
        curbColor,
      );
      final c2 = deckBuilder.addVertex(
        p1.x + p1.nx * 0.015,
        cy1,
        p1.z + p1.nz * 0.015,
        0,
        1,
        0,
        curbColor,
      );
      final c3 = deckBuilder.addVertex(
        p1.x - p1.nx * curbW,
        cy1,
        p1.z - p1.nz * curbW,
        0,
        1,
        0,
        curbColor,
      );
      deckBuilder.addQuad(c0, c1, c2, c3);

      final wTop = CartoonMeshBuilder.shadeColor(wallHex, p0.nx, 0.15, p0.nz);
      final wBot = CartoonMeshBuilder.shadeColor(
        wallHex,
        p0.nx,
        -0.25,
        p0.nz,
        scalar: 0.88,
      );
      final w0 = deckBuilder.addVertex(p0.x, p0.y, p0.z, p0.nx, 0, p0.nz, wTop);
      final w1 = deckBuilder.addVertex(p1.x, p1.y, p1.z, p1.nx, 0, p1.nz, wTop);
      final w2 =
          deckBuilder.addVertex(p1.x, p1.yBot, p1.z, p1.nx, 0, p1.nz, wBot);
      final w3 =
          deckBuilder.addVertex(p0.x, p0.yBot, p0.z, p0.nx, 0, p0.nz, wBot);
      deckBuilder.addQuad(w0, w1, w2, w3);

      if (!isBridge) {
        for (final sy in [-0.23, -0.61]) {
          final sm0 = deckBuilder.addVertex(
            p0.x + p0.nx * 0.008,
            sy + 0.014,
            p0.z + p0.nz * 0.008,
            p0.nx,
            0,
            p0.nz,
            seamColor,
          );
          final sm1 = deckBuilder.addVertex(
            p1.x + p1.nx * 0.008,
            sy + 0.014,
            p1.z + p1.nz * 0.008,
            p1.nx,
            0,
            p1.nz,
            seamColor,
          );
          final sm2 = deckBuilder.addVertex(
            p1.x + p1.nx * 0.008,
            sy - 0.014,
            p1.z + p1.nz * 0.008,
            p1.nx,
            0,
            p1.nz,
            seamColor,
          );
          final sm3 = deckBuilder.addVertex(
            p0.x + p0.nx * 0.008,
            sy - 0.014,
            p0.z + p0.nz * 0.008,
            p0.nx,
            0,
            p0.nz,
            seamColor,
          );
          deckBuilder.addQuad(sm0, sm1, sm2, sm3);
        }
      }
    }

    // 1. Loop Deck + Curbs + Walls (with clean openings at Entrance & Exit mouths)
    for (int i = 0; i < loopSteps; i++) {
      final l0 = leftPts[i], l1 = leftPts[i + 1];
      final r0 = rightPts[i], r1 = rightPts[i + 1];
      final isBridge = l0.y > surfaceY + 0.04 || l1.y > surfaceY + 0.04;
      final dc = isBridge ? bridgeTopColor : topColor;

      final b0 = deckBuilder.addVertex(l0.x, l0.y, l0.z, 0, 1, 0, dc);
      final b1 = deckBuilder.addVertex(r0.x, r0.y, r0.z, 0, 1, 0, dc);
      final b2 = deckBuilder.addVertex(r1.x, r1.y, r1.z, 0, 1, 0, dc);
      final b3 = deckBuilder.addVertex(l1.x, l1.y, l1.z, 0, 1, 0, dc);
      deckBuilder.addQuad(b0, b1, b2, b3);

      // Left & right raised cream curb strips + walls
      for (final side in [-1.0, 1.0]) {
        final p0 = side < 0 ? l0 : r0;
        final p1 = side < 0 ? l1 : r1;

        // Check if this outer curb segment faces the Entrance Ramp mouth
        final nearEntranceZ =
            p0.nz > 0.2 && p0.z > 0.3 && (p0.z - zOuterCenter).abs() < 0.55;
        if (nearEntranceZ) {
          final minX = math.min(p0.x, p1.x);
          final maxX = math.max(p0.x, p1.x);
          if (maxX > entXL && minX < entXR) {
            final dx = p1.x - p0.x;
            if (dx.abs() > 1e-6) {
              if (minX < entXL) {
                final tCut = ((entXL - p0.x) / dx).clamp(0.0, 1.0);
                final pCut = lerpEdgePt(p0, p1, tCut);
                if (p0.x < entXL) {
                  emitLoopCurbAndWall(p0, pCut, isBridge);
                } else {
                  emitLoopCurbAndWall(pCut, p1, isBridge);
                }
              }
              if (maxX > entXR) {
                final tCut = ((entXR - p0.x) / dx).clamp(0.0, 1.0);
                final pCut = lerpEdgePt(p0, p1, tCut);
                if (p0.x > entXR) {
                  emitLoopCurbAndWall(p0, pCut, isBridge);
                } else {
                  emitLoopCurbAndWall(pCut, p1, isBridge);
                }
              }
            }
            continue;
          }
        }

        // Check if this outer curb segment faces the Exit Road mouth
        if (exit != null) {
          final facesExit = (p0.nx * exDirX + p0.nz * exDirZ) > 0.2;
          if (facesExit) {
            final mx = (p0.x + p1.x) * 0.5;
            final mz = (p0.z + p1.z) * 0.5;
            if (distToExitXZ(mx, mz) <= exitHalfW + 0.015) {
              continue;
            }
          }
        }

        emitLoopCurbAndWall(p0, p1, isBridge);
      }
    }

    // Center dashes around the loop
    final loopDashCount = (loop.len / 34.0).round().clamp(28, 72);
    for (int i = 0; i < loopDashCount; i++) {
      final s = ((i + 0.5) / loopDashCount) * loop.len;
      loop.pointAtInto(s, scratch);
      final cx = CTDimensions.to3DX(scratch.x);
      final cz = CTDimensions.to3DZ(scratch.y);
      final ang = scratch.ang;
      final zElev = CTPathBuilder.getCarZ(s, loop);
      addDashAt(
        cx,
        surfaceY + zElev * 0.92 + 0.012,
        cz,
        math.cos(ang),
        math.sin(ang),
        dashColor,
      );
    }

    // For figure-8 shapes, add 4 architectural support columns under the overpass
    if (loop.meta != null &&
        (loop.meta!.shape == 'figure8' || loop.meta!.shape == 'figure8_90')) {
      final sCross = loop.meta!.s1;
      for (final offsetS in [-68.0, 68.0]) {
        final sPillar = (sCross + offsetS + loop.len) % loop.len;
        loop.pointAtInto(sPillar, scratch);
        final px = CTDimensions.to3DX(scratch.x);
        final pz = CTDimensions.to3DZ(scratch.y);
        final ang = scratch.ang;
        final rx = -math.sin(ang);
        final rz = math.cos(ang);
        final zElev = CTPathBuilder.getCarZ(sPillar, loop);
        final topY = surfaceY + zElev * 0.92 - 0.22;
        final colH = topY - bottomY;
        if (colH > 0.2) {
          for (final side in [-0.46, 0.46]) {
            deckBuilder.addCylinder(
              radiusTop: 0.09,
              radiusBottom: 0.11,
              height: colH,
              radialSegments: 10,
              x: px + rx * side,
              y: bottomY + colH / 2.0,
              z: pz + rz * side,
              hexColor: 0x6A5478,
            );
          }
        }
      }
    }

    // 2. Straight Entrance Ramp Deck + Curbs + Walls + Seams + Dashes
    // Joins the loop road's outer edge at (entXL, zOuterLeft) and (entXR, zOuterRight)
    // without ever drawing curbs or walls inside the loop road.
    const entY = surfaceY - 0.001;
    {
      // Main straight ramp deck from zTail up to the loop outer edge (zOuterLeft / zOuterRight)
      final b0 = deckBuilder.addVertex(entXL, entY, entZTail, 0, 1, 0, topColor);
      final b1 = deckBuilder.addVertex(entXR, entY, entZTail, 0, 1, 0, topColor);
      final b2 = deckBuilder.addVertex(entXR, entY, zOuterRight, 0, 1, 0, topColor);
      final b3 = deckBuilder.addVertex(entXL, entY, zOuterLeft, 0, 1, 0, topColor);
      deckBuilder.addQuad(b0, b1, b2, b3);

      // Seamless inner join quad from outer edge into loop centerline (1mm under loop surface)
      final j0 = deckBuilder.addVertex(entXL, entY, zOuterLeft, 0, 1, 0, topColor);
      final j1 = deckBuilder.addVertex(entXR, entY, zOuterRight, 0, 1, 0, topColor);
      final j2 = deckBuilder.addVertex(entXR, entY, zCenterRight, 0, 1, 0, topColor);
      final j3 = deckBuilder.addVertex(entXL, entY, zCenterLeft, 0, 1, 0, topColor);
      deckBuilder.addQuad(j0, j1, j2, j3);

      // Left (-1.0) and Right (+1.0) curbs, side walls, and purple wall seams stopping at zOuterLeft/zOuterRight
      for (final side in [-1.0, 1.0]) {
        final xEdge = side < 0 ? entXL : entXR;
        final zJoin = side < 0 ? zOuterLeft : zOuterRight;
        final nx = side;
        const cy = surfaceY + 0.012;

        final c0 = deckBuilder.addVertex(xEdge - nx * curbW, cy, entZTail, 0, 1, 0, curbColor);
        final c1 = deckBuilder.addVertex(xEdge + nx * 0.015, cy, entZTail, 0, 1, 0, curbColor);
        final c2 = deckBuilder.addVertex(xEdge + nx * 0.015, cy, zJoin, 0, 1, 0, curbColor);
        final c3 = deckBuilder.addVertex(xEdge - nx * curbW, cy, zJoin, 0, 1, 0, curbColor);
        deckBuilder.addQuad(c0, c1, c2, c3);

        final wTop = CartoonMeshBuilder.shadeColor(wallHex, nx, 0.15, 0.0);
        final wBot =
            CartoonMeshBuilder.shadeColor(wallHex, nx, -0.25, 0.0, scalar: 0.88);
        final w0 = deckBuilder.addVertex(xEdge, surfaceY, entZTail, nx, 0, 0, wTop);
        final w1 = deckBuilder.addVertex(xEdge, surfaceY, zJoin, nx, 0, 0, wTop);
        final w2 = deckBuilder.addVertex(xEdge, bottomY, zJoin, nx, 0, 0, wBot);
        final w3 = deckBuilder.addVertex(xEdge, bottomY, entZTail, nx, 0, 0, wBot);
        deckBuilder.addQuad(w0, w1, w2, w3);

        for (final sy in [-0.23, -0.61]) {
          final sm0 = deckBuilder.addVertex(
            xEdge + nx * 0.008,
            sy + 0.014,
            entZTail,
            nx,
            0,
            0,
            seamColor,
          );
          final sm1 = deckBuilder.addVertex(
            xEdge + nx * 0.008,
            sy + 0.014,
            zJoin,
            nx,
            0,
            0,
            seamColor,
          );
          final sm2 = deckBuilder.addVertex(
            xEdge + nx * 0.008,
            sy - 0.014,
            zJoin,
            nx,
            0,
            0,
            seamColor,
          );
          final sm3 = deckBuilder.addVertex(
            xEdge + nx * 0.008,
            sy - 0.014,
            entZTail,
            nx,
            0,
            0,
            seamColor,
          );
          deckBuilder.addQuad(sm0, sm1, sm2, sm3);
        }
      }

      // Straight entrance center yellow dashes (stopping cleanly outside the loop road)
      const dashStepZ = 34.0 * CTDimensions.to3DScale;
      for (double z = zOuterCenter + 0.36; z < entZTail - 0.35; z += dashStepZ) {
        addDashAt(entCx, surfaceY + 0.010, z, 0.0, -1.0, dashColor);
      }
    }

    // 3. Glowing Green Exit Road (if present)
    if (exit != null) {
      final exitTopColor = CartoonMeshBuilder.shadeColor(0x1D4D3C, 0, 1, 0);
      final exitCurbColor =
          CartoonMeshBuilder.shadeColor(0x4FFFA6, 0, 1, 0, unlit: true);
      final exitDashColor =
          CartoonMeshBuilder.shadeColor(0x80FFBF, 0, 1, 0, unlit: true);

      final exLeft = <({double x, double z, double nx, double nz, double dLoop})>[];
      final exRight = <({double x, double z, double nx, double nz, double dLoop})>[];
      final exCenterD = <double>[];

      for (int i = 0; i <= exitSteps; i++) {
        final c = exitCenterPts[i];
        final rx = -math.sin(c.ang);
        final rz = math.cos(c.ang);
        final lx = c.x - rx * exitHalfW;
        final lz = c.z - rz * exitHalfW;
        final rpx = c.x + rx * exitHalfW;
        final rpz = c.z + rz * exitHalfW;
        exCenterD.add(distToLoopXZ(c.x, c.z));
        exLeft.add((
          x: lx,
          z: lz,
          nx: -rx,
          nz: -rz,
          dLoop: distToLoopXZ(lx, lz),
        ));
        exRight.add((
          x: rpx,
          z: rpz,
          nx: rx,
          nz: rz,
          dLoop: distToLoopXZ(rpx, rpz),
        ));
      }

      const exY = surfaceY - 0.002;
      for (int i = 0; i < exitSteps; i++) {
        final l0 = exLeft[i], l1 = exLeft[i + 1];
        final r0 = exRight[i], r1 = exRight[i + 1];
        if (exCenterD[i + 1] < roadHalfW * 0.70) continue;

        final b0 = deckBuilder.addVertex(l0.x, exY, l0.z, 0, 1, 0, exitTopColor);
        final b1 = deckBuilder.addVertex(r0.x, exY, r0.z, 0, 1, 0, exitTopColor);
        final b2 = deckBuilder.addVertex(r1.x, exY, r1.z, 0, 1, 0, exitTopColor);
        final b3 = deckBuilder.addVertex(l1.x, exY, l1.z, 0, 1, 0, exitTopColor);
        deckBuilder.addQuad(b0, b1, b2, b3);

        for (final side in [-1.0, 1.0]) {
          var p0 = side < 0 ? l0 : r0;
          final p1 = side < 0 ? l1 : r1;
          if (p1.dLoop < roadHalfW) continue;
          if (p0.dLoop < roadHalfW) {
            final t = ((roadHalfW - p0.dLoop) /
                    math.max(1e-5, p1.dLoop - p0.dLoop))
                .clamp(0.0, 1.0);
            p0 = (
              x: p0.x + (p1.x - p0.x) * t,
              z: p0.z + (p1.z - p0.z) * t,
              nx: p0.nx,
              nz: p0.nz,
              dLoop: roadHalfW,
            );
          }

          final c0 = deckBuilder.addVertex(
            p0.x - p0.nx * curbW,
            surfaceY + 0.012,
            p0.z - p0.nz * curbW,
            0,
            1,
            0,
            exitCurbColor,
          );
          final c1 = deckBuilder.addVertex(
            p0.x + p0.nx * 0.016,
            surfaceY + 0.012,
            p0.z + p0.nz * 0.016,
            0,
            1,
            0,
            exitCurbColor,
          );
          final c2 = deckBuilder.addVertex(
            p1.x + p1.nx * 0.016,
            surfaceY + 0.012,
            p1.z + p1.nz * 0.016,
            0,
            1,
            0,
            exitCurbColor,
          );
          final c3 = deckBuilder.addVertex(
            p1.x - p1.nx * curbW,
            surfaceY + 0.012,
            p1.z - p1.nz * curbW,
            0,
            1,
            0,
            exitCurbColor,
          );
          deckBuilder.addQuad(c0, c1, c2, c3);

          final wTop =
              CartoonMeshBuilder.shadeColor(0x16382C, p0.nx, 0.15, p0.nz);
          final wBot = CartoonMeshBuilder.shadeColor(
            0x112B22,
            p0.nx,
            -0.25,
            p0.nz,
            scalar: 0.88,
          );
          final w0 =
              deckBuilder.addVertex(p0.x, exY, p0.z, p0.nx, 0, p0.nz, wTop);
          final w1 =
              deckBuilder.addVertex(p1.x, exY, p1.z, p1.nx, 0, p1.nz, wTop);
          final w2 =
              deckBuilder.addVertex(p1.x, bottomY, p1.z, p1.nx, 0, p1.nz, wBot);
          final w3 =
              deckBuilder.addVertex(p0.x, bottomY, p0.z, p0.nx, 0, p0.nz, wBot);
          deckBuilder.addQuad(w0, w1, w2, w3);
        }
      }

      for (double s = 26.0; s < exitLenPx - 20.0; s += 34.0) {
        exit.pointAtInto(s, scratch);
        final cx = CTDimensions.to3DX(scratch.x);
        final cz = CTDimensions.to3DZ(scratch.y);
        if (distToLoopXZ(cx, cz) < roadHalfW + 0.30) continue;
        final ang = scratch.ang;
        addDashAt(
          cx,
          surfaceY + 0.011,
          cz,
          math.cos(ang),
          math.sin(ang),
          exitDashColor,
        );
      }
    }

    stageGroup.add(
      Node(
        name: 'stage-road-deck',
        mesh: Mesh.primitives(
          primitives: [
            deckBuilder.build(doubleSided: true),
            dashBuilder.build(doubleSided: true, depthLayer: 1),
          ],
        ),
      ),
    );

    // 4. Reposition Launch Cradle cleanly below the loop road's outer curb
    _activeQueueX = entCx;
    _activeQueueZ = zOuterCenter + curbW + 1.06;
    _cradleGroup?.position = Vector3(
      _activeQueueX - TrafficMath.queueX,
      0.0,
      _activeQueueZ - TrafficMath.queueZ,
    );
    _lastCradlePulse = -1.0;

    _stageRoadCache[trackKey] = (
      group: stageGroup,
      queueX: _activeQueueX,
      queueZ: _activeQueueZ,
    );
    _stageRoadGroup = stageGroup;
    _worldRoot.add(stageGroup);

    // 5. Adapt Park Island & Trees to the current track shape
    if (loop.meta != null) {
      _adaptParkForShape(loop.meta!);
    }
  }

  void _adaptParkForShape(CTPathMeta meta) {
    final shape = meta.shape;
    if (shape == 'circle') {
      _classicParkGroup?.visible = true;
      _classicParkGroup?.scale = Vector3.all(1.0);
      return;
    }

    if (shape == 'oval' ||
        shape == 'roundedSquare' ||
        shape == 'compactLoop' ||
        shape == 'wideLoop') {
      _classicParkGroup?.visible = true;
      final sx = ((meta.hw * CTDimensions.to3DScale - 0.85) / 2.75).clamp(0.55, 1.05);
      final sz = ((meta.hh * CTDimensions.to3DScale - 0.85) / 2.75).clamp(0.55, 1.05);
      _classicParkGroup?.scale = Vector3(sx, 1.0, sz);
      return;
    }

    // For figure8 and figure8_90, the road crosses (0, 0), so hide the center island
    // and reuse cached twin lobe mini-islands so the intersection is completely clear.
    _classicParkGroup?.visible = false;
    final cachedFg = shape == 'figure8' ? _cachedFigure8Park : _cachedFigure890Park;
    if (cachedFg != null) {
      _stageParkGroup = cachedFg;
      _worldRoot.add(cachedFg);
      return;
    }

    final fgPark = Node(name: 'figure8-park-$shape');
    final solidBuilder = CartoonMeshBuilder();
    final outlineBuilder = CartoonMeshBuilder();
    const inkHex = 0x32303A;
    const clayHex = 0xFFEFDC;
    const landHex = 0xB8D87E;
    const woodHex = 0xB77E48;

    final lobeCenters = shape == 'figure8'
        ? const [(x: -2.18, z: 0.0), (x: 2.18, z: 0.0)]
        : const [(x: 0.0, z: -2.18), (x: 0.0, z: 2.18)];

    for (final c in lobeCenters) {
      outlineBuilder.addCylinder(
        radiusTop: 0.92,
        radiusBottom: 0.89,
        height: 0.18,
        radialSegments: 24,
        x: c.x,
        y: -0.71,
        z: c.z,
        scaleX: 1.02,
        scaleY: 1.10,
        scaleZ: 1.02,
        hexColor: inkHex,
        unlit: true,
        flipWinding: true,
      );
      solidBuilder.addCylinder(
        radiusTop: 0.92,
        radiusBottom: 0.89,
        height: 0.18,
        radialSegments: 24,
        x: c.x,
        y: -0.71,
        z: c.z,
        hexColor: clayHex,
      );
      solidBuilder.addCylinder(
        radiusTop: 0.84,
        radiusBottom: 0.82,
        height: 0.09,
        radialSegments: 24,
        x: c.x,
        y: -0.58,
        z: c.z,
        hexColor: landHex,
      );
      // Mini pine tree in each lobe center
      solidBuilder.addCylinder(
        radiusTop: 0.06,
        radiusBottom: 0.08,
        height: 0.42,
        radialSegments: 8,
        x: c.x,
        y: -0.35,
        z: c.z,
        hexColor: woodHex,
      );
      for (int j = 0; j < 3; j++) {
        final r = (0.48 - j * 0.11);
        final h = (0.45 - j * 0.06);
        final ty = -0.05 + j * 0.24;
        outlineBuilder.addCylinder(
          radiusTop: 0.0,
          radiusBottom: r * 1.08,
          height: h * 1.06,
          radialSegments: 8,
          x: c.x,
          y: ty,
          z: c.z,
          hexColor: inkHex,
          unlit: true,
          flipWinding: true,
        );
        solidBuilder.addCylinder(
          radiusTop: 0.0,
          radiusBottom: r,
          height: h,
          radialSegments: 8,
          x: c.x,
          y: ty,
          z: c.z,
          hexColor: 0x6FB157,
          flatShading: true,
        );
      }
    }

    fgPark.add(
      Node(
        name: 'fg8-park-combined',
        mesh: Mesh.primitives(
          primitives: [
            outlineBuilder.build(doubleSided: false, depthLayer: 0),
            solidBuilder.build(doubleSided: true, depthLayer: 1),
          ],
        ),
      ),
    );

    if (shape == 'figure8') {
      _cachedFigure8Park = fgPark;
    } else {
      _cachedFigure890Park = fgPark;
    }
    _stageParkGroup = fgPark;
    _worldRoot.add(fgPark);
  }

  /// Builds the Cartoon Launch Cradle at (QUEUE_X, SURFACE_Y, QUEUE_Z)
  /// matching presentation.js.
  void _buildLaunchCradle() {
    final group = Node(name: 'cartoon-launch-cradle');
    const surfaceY = TrafficMath.surfaceY;
    const qx = TrafficMath.queueX;
    const qz = TrafficMath.queueZ;

    // Layered base pads
    final basePadsBuilder = CartoonMeshBuilder();
    basePadsBuilder.addFlatRoundedRect(
      w: 1.19,
      l: 2.0,
      r: 0.34,
      x: qx,
      y: surfaceY + 0.003,
      z: qz,
      hexColor: 0x34333B,
      unlit: true,
    );
    basePadsBuilder.addFlatRoundedRect(
      w: 1.15,
      l: 1.96,
      r: 0.33,
      x: qx,
      y: surfaceY + 0.0045,
      z: qz,
      hexColor: 0x514454,
    );
    group.add(
      Node(
        name: 'cradle-base-pads',
        mesh: _m(basePadsBuilder.build(doubleSided: true, depthLayer: 1)),
      ),
    );

    // Center pod pad (scales slightly on launch pulse)
    final podBuilder = CartoonMeshBuilder();
    podBuilder.addFlatRoundedRect(
      w: 1.105,
      l: 1.91,
      r: 0.30,
      x: 0,
      y: 0,
      z: 0,
      hexColor: 0x4C3F4D,
    );
    _cradlePodNode = Node(
      name: 'cradle-pod',
      mesh: _m(podBuilder.build(doubleSided: true, depthLayer: 2)),
    )..position = Vector3(qx, surfaceY + 0.006, qz);
    group.add(_cradlePodNode!);

    // Left and right cream rails + ink outlines + indicator lamps
    _cradleRails.clear();
    for (final side in [-1.0, 1.0]) {
      final railBuilder = CartoonMeshBuilder();
      railBuilder.addSoftBox(
        w: 0.068,
        l: 1.90,
        h: 0.038,
        r: 0.03,
        x: 0,
        y: 0,
        z: 0,
        bevel: 0.009,
        hexColor: 0x34333B,
        unlit: true,
      );
      railBuilder.addSoftBox(
        w: 0.055,
        l: 1.86,
        h: 0.033,
        r: 0.025,
        x: 0,
        y: 0.006,
        z: 0,
        bevel: 0.008,
        hexColor: 0xFFDD99,
      );
      railBuilder.addEllipsoid(
        x: 0,
        y: 0.048,
        z: -0.75,
        sx: 0.036,
        sy: 0.023,
        sz: 0.083,
        hexColor: 0xFFE590,
        unlit: true,
      );
      final railNode = Node(
        name: 'cradle-rail-$side',
        mesh: _m(railBuilder.build(doubleSided: true, depthLayer: 2)),
      )..position = Vector3(qx + side * 0.615, surfaceY + 0.018, qz);
      group.add(railNode);
      _cradleRails.add(railNode);
    }

    // Left and right chevron arrows ahead of the launch bay
    _cradleArrows.clear();
    final arrowBuilder = CartoonMeshBuilder();
    final arrowColor =
        CartoonMeshBuilder.shadeColor(0xFFEEAA, 0, 1, 0, unlit: true);
    final a0 = arrowBuilder.addVertex(-0.055, 0, 0.065, 0, 1, 0, arrowColor);
    final a1 = arrowBuilder.addVertex(0.0, 0, -0.09, 0, 1, 0, arrowColor);
    final a2 = arrowBuilder.addVertex(0.055, 0, 0.065, 0, 1, 0, arrowColor);
    final a3 = arrowBuilder.addVertex(0.0, 0, 0.014, 0, 1, 0, arrowColor);
    arrowBuilder.addTriangle(a0, a1, a3);
    arrowBuilder.addTriangle(a3, a1, a2);
    final arrowMesh = _m(arrowBuilder.build(doubleSided: true, depthLayer: 2));

    for (final side in [-1.0, 1.0]) {
      final arrowNode = Node(name: 'cradle-arrow-$side', mesh: arrowMesh)
        ..position = Vector3(
          qx + side * 0.25,
          surfaceY + 0.012,
          qz - 0.78,
        )
        ..rotation = Quaternion.axisAngle(Vector3(0, 1, 0), 0.0);
      group.add(arrowNode);
      _cradleArrows.add(arrowNode);
    }

    _cradleGroup = group;
    _worldRoot.add(group);
  }

  /// Builds the Central Park Island, 3 Outer Planters, Soft Shadows,
  /// 8 Outlined Low-Poly Pine Trees, 2 Park Benches, and 21 Grass Clumps
  /// (matching trees.js & scenery.mjs).
  Future<void> _buildParkAndTrees({void Function()? onProgress}) async {
    final parkGroup = Node(name: 'outlined-pine-park');
    _classicParkGroup = parkGroup;
    _worldRoot.add(parkGroup);
    const inkHex = 0x32303A;
    const clayHex = 0xFFEFDC;
    const landHex = 0xB8D87E;
    const woodHex = 0xB77E48;
    const seatWoodHex = 0xE99B54;
    const barkHex = 0x775437;
    const grassHex = 0x629C45;

    // 1. Soft drop shadows under the central island and 3 outer planters
    final shadowBuilder = CartoonMeshBuilder();
    shadowBuilder.addSoftDiscShadow(
      x: 0,
      y: -0.86,
      z: 0,
      radiusX: 3.18,
      radiusZ: 3.18,
      hexColor: 0x4B2E2E,
      centerAlpha: 0.26,
    );
    for (final t in SceneryLayout.treeLayout) {
      if (!t.island) {
        final r = 0.925 * t.scale;
        shadowBuilder.addSoftDiscShadow(
          x: t.x,
          y: -1.04,
          z: t.z,
          radiusX: r,
          radiusZ: r,
          hexColor: 0x4B2E2E,
          centerAlpha: 0.26,
        );
      }
    }
    parkGroup.add(
      Node(
        name: 'park-shadows',
        mesh: _m(
          shadowBuilder.build(
            doubleSided: true,
            alphaMode: AlphaMode.blend,
          ),
        ),
      ),
    );

    // 2. Island & Planter Pads + Outlines + Static Trunks + Benches + Grass
    final solidBuilder = CartoonMeshBuilder();
    final outlineBuilder = CartoonMeshBuilder();

    void addPad(double x, double z, double r, double top, double height, int hex) {
      final yCenter = top - height / 2.0;
      outlineBuilder.addCylinder(
        radiusTop: r,
        radiusBottom: r * 0.97,
        height: height,
        radialSegments: 28,
        x: x,
        y: yCenter,
        z: z,
        scaleX: 1.014,
        scaleY: 1.10,
        scaleZ: 1.014,
        hexColor: inkHex,
        unlit: true,
        flipWinding: true,
      );
      solidBuilder.addCylinder(
        radiusTop: r,
        radiusBottom: r * 0.97,
        height: height,
        radialSegments: 28,
        x: x,
        y: yCenter,
        z: z,
        hexColor: hex,
      );
    }

    // Central park island
    addPad(0, 0, 2.72, -0.62, 0.18, clayHex);
    addPad(0, 0, 2.64, -0.54, 0.09, landHex);

    // 3 Outer mini-planters
    for (final t in SceneryLayout.treeLayout) {
      if (!t.island) {
        addPad(t.x, t.z, 0.70 * t.scale, -0.82, 0.18, clayHex);
        addPad(t.x, t.z, 0.61 * t.scale, -0.78, 0.07, landHex);
      }
    }

    // Tree wooden trunks + bark lines + trunk outlines
    for (int i = 0; i < SceneryLayout.treeLayout.length; i++) {
      final t = SceneryLayout.treeLayout[i];
      final yBase = t.island ? -0.53 : -0.77;
      final s = t.scale;
      final trunkH = SceneryLayout.trunkHeight * s;
      final trunkY = yBase + trunkH / 2.0;

      outlineBuilder.addCylinder(
        radiusTop: 0.7 * 0.116 * s,
        radiusBottom: 1.0 * 0.116 * s,
        height: trunkH * 1.025,
        radialSegments: 8,
        x: t.x,
        y: trunkY,
        z: t.z,
        hexColor: inkHex,
        unlit: true,
        flipWinding: true,
      );
      solidBuilder.addCylinder(
        radiusTop: 0.7 * 0.095 * s,
        radiusBottom: 1.0 * 0.095 * s,
        height: trunkH,
        radialSegments: 8,
        x: t.x,
        y: trunkY,
        z: t.z,
        hexColor: woodHex,
      );
      solidBuilder.addCylinder(
        radiusTop: 0.007 * s,
        radiusBottom: 0.007 * s,
        height: 0.43 * s,
        radialSegments: 5,
        x: t.x + 0.018 * s,
        y: yBase + 0.34 * s,
        z: t.z + 0.084 * s,
        hexColor: barkHex,
      );
    }

    // 2 Park benches with outlines
    final benchParts = <({
      double w,
      double h,
      double d,
      double x,
      double y,
      double z,
      int hex,
    })>[
      for (final bx in [-0.27, 0.27]) ...[
        (w: 0.055, h: 0.22, d: 0.26, x: bx, y: 0.11, z: 0.0, hex: woodHex),
        (w: 0.046, h: 0.36, d: 0.046, x: bx, y: 0.25, z: -0.13, hex: woodHex),
      ],
      (w: 0.78, h: 0.055, d: 0.105, x: 0.0, y: 0.25, z: -0.055, hex: seatWoodHex),
      (w: 0.78, h: 0.055, d: 0.105, x: 0.0, y: 0.25, z: 0.065, hex: seatWoodHex),
      (w: 0.78, h: 0.13, d: 0.05, x: 0.0, y: 0.415, z: -0.14, hex: seatWoodHex),
    ];

    for (final b in SceneryLayout.parkBenches) {
      final ca = math.cos(b.angle), sa = math.sin(b.angle);
      for (final p in benchParts) {
        final wx = b.x + p.x * ca + p.z * sa;
        final wy = -0.49 + p.y;
        final wz = b.z - p.x * sa + p.z * ca;
        outlineBuilder.addBox(
          w: p.w * 1.055,
          h: p.h * 1.10,
          l: p.d * 1.12,
          tx: wx,
          ty: wy,
          tz: wz,
          ry: b.angle,
          hexColor: inkHex,
          unlit: true,
          flipWinding: true,
        );
        solidBuilder.addBox(
          w: p.w,
          h: p.h,
          l: p.d,
          tx: wx,
          ty: wy,
          tz: wz,
          ry: b.angle,
          hexColor: p.hex,
        );
      }
    }

    // 21 Grass clumps (each with 3 4-sided blades)
    final allGrass = <({double x, double y, double z, double scale})>[
      ...SceneryLayout.parkGrass
          .map((g) => (x: g.x, y: -0.535, z: g.z, scale: g.scale)),
      for (final t in SceneryLayout.treeLayout.where((t) => !t.island))
        (
          x: t.x - 0.34 * t.scale,
          y: -0.775,
          z: t.z + 0.28 * t.scale,
          scale: t.scale,
        ),
    ];

    for (final g in allGrass) {
      for (int j = 0; j < 3; j++) {
        final gx = g.x + (j - 1) * 0.055 * g.scale;
        final gz = g.z + (j % 2) * 0.025 * g.scale;
        final gh = (0.18 + (j == 1 ? 0.075 : 0.0)) * g.scale;
        final lean = (j - 1) * 0.34;
        solidBuilder.addCylinder(
          radiusTop: 0.0,
          radiusBottom: 0.032 * g.scale,
          height: gh,
          radialSegments: 4,
          x: gx,
          y: g.y + gh / 2.0,
          z: gz,
          ry: 0.35,
          rz: lean,
          hexColor: grassHex,
          flatShading: true,
        );
      }
    }

    parkGroup.add(
      Node(
        name: 'park-combined',
        mesh: Mesh.primitives(
          primitives: [
            outlineBuilder.build(doubleSided: false, depthLayer: 0),
            solidBuilder.build(doubleSided: true, depthLayer: 1),
          ],
        ),
      ),
    );
    onProgress?.call();
    await _yieldFrame();

    // 3. 24 Pointed Pine Cone Tiers (8 trees x 3 tiers) batched into a single Node
    // (2 primitives instead of 48 separate Nodes!)
    final pineOutlineBuilder = CartoonMeshBuilder();
    final pineLeafBuilder = CartoonMeshBuilder();

    for (int i = 0; i < SceneryLayout.treeLayout.length; i++) {
      final t = SceneryLayout.treeLayout[i];
      final yBase = t.island ? -0.53 : -0.77;
      final s = t.scale;
      final baseHex = GameTheme.treeHexColors[t.color];

      for (int j = 0; j < SceneryLayout.pineTiers.length; j++) {
        final tier = SceneryLayout.pineTiers[j];
        final scalar = 0.86 + j * 0.08;
        final tx = t.x;
        final ty = yBase + tier.y * s;
        final tz = t.z;
        final tr = tier.radius * s;
        final th = tier.height * s;
        final phase = j * 0.16;

        pineOutlineBuilder.addCylinder(
          radiusTop: 0.0,
          radiusBottom: tr * 1.075,
          height: th * 1.045,
          radialSegments: 8,
          x: tx,
          y: ty,
          z: tz,
          ry: phase,
          hexColor: inkHex,
          unlit: true,
          flipWinding: true,
        );
        pineLeafBuilder.addCylinder(
          radiusTop: 0.0,
          radiusBottom: tr,
          height: th,
          radialSegments: 8,
          x: tx,
          y: ty,
          z: tz,
          ry: phase,
          hexColor: baseHex,
          scalar: scalar,
          flatShading: true,
        );
      }
    }

    _pineFoliageNode = Node(
      name: 'pine-foliage-batched',
      mesh: Mesh.primitives(
        primitives: [
          pineOutlineBuilder.build(doubleSided: false, depthLayer: 0),
          pineLeafBuilder.build(doubleSided: true, depthLayer: 1),
        ],
      ),
    );
    parkGroup.add(_pineFoliageNode!);
    onProgress?.call();
    await _yieldFrame();
  }

  /// Pre-allocates the reusable car `Node` pool on [_worldRoot] so adding or
  /// removing cars during gameplay never allocates `Node`s or mutates the
  /// scene graph's children list.
  void _buildCarTemplates() {
    _carTemplates.clear();
    _carOutlineCache.clear();
    _freeCarNodes.clear();

    for (int i = 0; i < 16; i++) {
      final pooledNode = Node(name: 'pooled-car-$i')..visible = false;
      _worldRoot.add(pooledNode);
      _freeCarNodes.add(pooledNode);
    }
  }

  _CarTemplate _getCarTemplate(int desiredKind, int desiredColor) {
    final normalizedColor =
        (desiredKind == 7 || desiredKind == 8) ? 0 : desiredColor;
    final key = _CarCacheKey(desiredKind, normalizedColor);
    return _carTemplates.putIfAbsent(key, () {
      if (desiredKind == 7) {
        return _createSingleCarTemplate(
          1,
          0x26DE81,
          role: CTCarRole.green,
        );
      }
      if (desiredKind == 8) {
        return _createSingleCarTemplate(
          1,
          0x1E293B,
          role: CTCarRole.police,
        );
      }
      final paintHex = GameTheme.accentHexColors[
          normalizedColor % GameTheme.accentHexColors.length];
      return _createSingleCarTemplate(desiredKind, paintHex);
    });
  }

  MeshPrimitive _getOrCreateCarOutline(int kind) {
    return _carOutlineCache.putIfAbsent(kind, () {
      const outlineHex = 0x30313B;
      final outlineBuilder = CartoonMeshBuilder();
      // Baked opaque ground shadow oval (avoids a separate Node + AlphaMode.blend draw call per car!)
      outlineBuilder.addFlatRoundedRect(
        w: 0.90,
        l: 1.48,
        r: 0.38,
        x: 0,
        y: 0.012,
        z: 0,
        hexColor: 0x241B2B,
        unlit: true,
        cornerSegments: 2,
      );
      outlineBuilder.addSoftBox(
        w: 0.72,
        l: 1.32,
        h: 0.235,
        r: 0.16,
        x: 0,
        y: 0.18,
        z: 0,
        bevel: 0.045,
        hexColor: outlineHex,
        unlit: true,
        inflate: 0.016,
        flipWinding: true,
      );
      outlineBuilder.addCabin(
        kind: kind,
        hexColor: outlineHex,
        unlit: true,
        inflate: 0.016,
        flipWinding: true,
      );
      for (final side in [-1.0, 1.0]) {
        outlineBuilder.addEllipsoid(
          x: side * 0.433,
          y: 0.478,
          z: 0.221,
          sx: 0.064,
          sy: 0.043,
          sz: 0.065,
          hexColor: outlineHex,
          unlit: true,
          inflate: 0.013,
          flipWinding: true,
        );
      }
      if (kind == 0) {
        outlineBuilder.addBox(
          w: 0.568,
          h: 0.060,
          l: 0.123,
          tx: 0,
          ty: 0.476,
          tz: -0.515,
          hexColor: outlineHex,
          unlit: true,
          flipWinding: true,
        );
      }
      return outlineBuilder.build(doubleSided: false, depthLayer: 0);
    });
  }

  _CarTemplate _createSingleCarTemplate(
    int kind,
    int paintHex, {
    CTCarRole role = CTCarRole.normal,
  }) {
    const glassHex = 0x247790;
    const shineHex = 0xC7ED90;
    const trimHex = 0x293442;
    const creamHex = 0xFFF2DE;
    const lampHex = 0xFFF2D9;
    const redHex = 0xEB70AC;

    final chassisBuilder = CartoonMeshBuilder();

    final height = [0.65, 0.70, 0.72][kind];
    final roofBack = [-0.19, -0.28, -0.30][kind];
    final roofFront = [0.12, 0.13, 0.14][kind];
    const frontBase = 0.35;
    final backBase = kind == 0 ? -0.39 : -0.47;

    final cabinHex = role == CTCarRole.police
        ? 0xF8FAFC
        : role == CTCarRole.green
            ? 0x52FFA8
            : paintHex;

    // 1. Main lower body + sloped cabin
    chassisBuilder.addSoftBox(
      w: 0.72,
      l: 1.32,
      h: 0.235,
      r: 0.16,
      x: 0,
      y: 0.18,
      z: 0,
      bevel: 0.045,
      hexColor: paintHex,
      specular: 0.22,
    );

    chassisBuilder.addCabin(
      kind: kind,
      hexColor: cabinHex,
      specular: 0.25,
    );

    // Police Red & Blue Roof Lightbar or Green Exit Beacon
    if (role == CTCarRole.police) {
      // Center chrome mount
      chassisBuilder.addBox(
        w: 0.42,
        h: 0.045,
        l: 0.11,
        tx: 0,
        ty: height + 0.032,
        tz: -0.05,
        hexColor: 0xE2E8F0,
      );
      // Left Red Siren Dome
      chassisBuilder.addBox(
        w: 0.17,
        h: 0.058,
        l: 0.12,
        tx: -0.12,
        ty: height + 0.064,
        tz: -0.05,
        hexColor: 0xFF2E4C,
        unlit: true,
      );
      // Right Blue Siren Dome
      chassisBuilder.addBox(
        w: 0.17,
        h: 0.058,
        l: 0.12,
        tx: 0.12,
        ty: height + 0.064,
        tz: -0.05,
        hexColor: 0x38BDF8,
        unlit: true,
      );
      // White police door stripes
      for (final side in [-1.0, 1.0]) {
        chassisBuilder.addBox(
          w: 0.018,
          h: 0.12,
          l: 0.56,
          tx: side * 0.365,
          ty: 0.29,
          tz: 0.0,
          hexColor: 0xF8FAFC,
        );
      }
    } else if (role == CTCarRole.green) {
      // Glowing emerald roof beacon
      chassisBuilder.addBox(
        w: 0.28,
        h: 0.055,
        l: 0.22,
        tx: 0,
        ty: height + 0.058,
        tz: -0.05,
        hexColor: 0x7BFFB8,
        unlit: true,
      );
    }

    // 2. Framed Front, Rear, and Side Windows + Windshield Shine
    Vector3 screenPoint(double y, double halfWidth, {bool back = false}) {
      final z0 = back ? backBase : frontBase;
      final z1 = back ? roofBack - 0.05 : roofFront + 0.055;
      final y1 = back ? height - 0.06 : height - 0.07;
      final dz = z1 - z0;
      final dy = y1 - 0.37;
      final n = TrafficMath.hypot(dz, dy);
      final z =
          z0 + dz * (y - 0.37) / dy + (back ? -1.0 : 1.0) * dy / n * 0.041;
      return Vector3(halfWidth, y + dz.abs() / n * 0.041, z);
    }

    void addGlazed(List<Vector3> pts, Vector3 normal) {
      chassisBuilder.addPolygon(
        pts,
        trimHex,
        explicitNormal: normal,
      );
      var cx = 0.0, cy = 0.0, cz = 0.0;
      for (final p in pts) {
        cx += p.x / pts.length;
        cy += p.y / pts.length;
        cz += p.z / pts.length;
      }
      final inset = pts
          .map((p) => Vector3(
                cx + (p.x - cx) * 0.83 + normal.x * 0.004,
                cy + (p.y - cy) * 0.83 + normal.y * 0.004,
                cz + (p.z - cz) * 0.83 + normal.z * 0.004,
              ))
          .toList();
      chassisBuilder.addPolygon(
        inset,
        glassHex,
        explicitNormal: normal,
        specular: 0.35,
      );
    }

    final frontWin = [
      screenPoint(0.405, -0.247),
      screenPoint(0.405, 0.247),
      screenPoint(height - 0.075, 0.222),
      screenPoint(height - 0.075, -0.222),
    ];
    addGlazed(frontWin, Vector3(0, 0.4, 0.8).normalized());

    final backWin = [
      screenPoint(0.405, 0.245, back: true),
      screenPoint(0.405, -0.245, back: true),
      screenPoint(height - 0.073, -0.22, back: true),
      screenPoint(height - 0.073, 0.22, back: true),
    ];
    addGlazed(backWin, Vector3(0, 0.4, -0.8).normalized());

    // Windshield diagonal shine glint
    Vector3 interp(Vector3 a, Vector3 b, double t) => a + (b - a) * t;
    final glint = [
      interp(frontWin[0], frontWin[1], 0.22),
      interp(frontWin[0], frontWin[1], 0.38),
      interp(frontWin[3], frontWin[2], 0.57),
      interp(frontWin[3], frontWin[2], 0.41),
    ].map((p) => Vector3(p.x, p.y + 0.008, p.z + 0.010)).toList();
    chassisBuilder.addPolygon(
      glint,
      shineHex,
      explicitNormal: Vector3(0, 0.4, 0.8).normalized(),
      unlit: true,
    );

    // Side windows, B-pillars, door handles, side mirrors
    for (final side in [-1.0, 1.0]) {
      final sidePts = [
        Vector3(side * 0.283, 0.402, backBase + 0.055),
        Vector3(side * 0.283, 0.402, frontBase - 0.06),
        Vector3(side * 0.283, height - 0.062, roofFront + 0.018),
        Vector3(side * 0.283, height - 0.062, roofBack - 0.01),
      ];
      addGlazed(
        side < 0 ? sidePts.reversed.toList() : sidePts,
        Vector3(side, 0, 0),
      );
      // B-pillar
      chassisBuilder.addBox(
        w: 0.019,
        h: height - 0.46,
        l: 0.037,
        tx: side * 0.292,
        ty: (height + 0.34) / 2.0,
        tz: -0.065,
        hexColor: cabinHex,
      );
      // Door handle
      chassisBuilder.addBox(
        w: 0.018,
        h: 0.018,
        l: 0.092,
        tx: side * 0.387,
        ty: 0.369,
        tz: -0.20,
        hexColor: creamHex,
      );
      // Side mirror
      chassisBuilder.addEllipsoid(
        x: side * 0.427,
        y: 0.465,
        z: 0.22,
        sx: 0.067,
        sy: 0.047,
        sz: 0.070,
        hexColor: trimHex,
      );
      chassisBuilder.addEllipsoid(
        x: side * 0.433,
        y: 0.478,
        z: 0.221,
        sx: 0.064,
        sy: 0.043,
        sz: 0.065,
        hexColor: paintHex,
      );
    }

    // 3. Front & Rear Bumpers, Headlights, Taillights, Grille
    chassisBuilder.addBox(
      w: 0.60,
      h: 0.070,
      l: 0.045,
      tx: 0,
      ty: 0.270,
      tz: 0.69,
      hexColor: trimHex,
    );
    chassisBuilder.addBox(
      w: 0.54,
      h: 0.045,
      l: 0.046,
      tx: 0,
      ty: 0.275,
      tz: 0.704,
      hexColor: creamHex,
    );
    chassisBuilder.addBox(
      w: 0.57,
      h: 0.055,
      l: 0.043,
      tx: 0,
      ty: 0.248,
      tz: -0.69,
      hexColor: trimHex,
    );
    chassisBuilder.addBox(
      w: 0.49,
      h: 0.035,
      l: 0.046,
      tx: 0,
      ty: 0.255,
      tz: -0.702,
      hexColor: creamHex,
    );

    for (final side in [-1.0, 1.0]) {
      // Headlight
      chassisBuilder.addEllipsoid(
        x: side * 0.234,
        y: 0.343,
        z: 0.658,
        sx: 0.105,
        sy: 0.072,
        sz: 0.055,
        hexColor: trimHex,
      );
      chassisBuilder.addEllipsoid(
        x: side * 0.234,
        y: 0.349,
        z: 0.692,
        sx: 0.078,
        sy: 0.048,
        sz: 0.034,
        hexColor: lampHex,
        unlit: true,
      );
      // Taillight
      chassisBuilder.addEllipsoid(
        x: side * 0.247,
        y: 0.34,
        z: -0.656,
        sx: 0.093,
        sy: 0.057,
        sz: 0.045,
        hexColor: trimHex,
      );
      chassisBuilder.addEllipsoid(
        x: side * 0.247,
        y: 0.345,
        z: -0.685,
        sx: 0.070,
        sy: 0.035,
        sz: 0.025,
        hexColor: redHex,
        unlit: true,
      );
    }

    // Grille & rear plate
    chassisBuilder.addBox(
      w: 0.23,
      h: 0.064,
      l: 0.028,
      tx: 0,
      ty: 0.337,
      tz: 0.715,
      hexColor: trimHex,
    );
    chassisBuilder.addBox(
      w: 0.15,
      h: 0.012,
      l: 0.008,
      tx: 0,
      ty: 0.308,
      tz: 0.735,
      hexColor: creamHex,
    );
    chassisBuilder.addBox(
      w: 0.13,
      h: 0.026,
      l: 0.017,
      tx: 0,
      ty: 0.314,
      tz: -0.713,
      hexColor: creamHex,
    );

    // Spoiler (kind == 0) or Roof Rails (kind == 2)
    if (kind == 0 && role == CTCarRole.normal) {
      chassisBuilder.addBox(
        w: 0.035,
        h: 0.048,
        l: 0.025,
        tx: -0.17,
        ty: 0.435,
        tz: -0.515,
        hexColor: trimHex,
      );
      chassisBuilder.addBox(
        w: 0.035,
        h: 0.048,
        l: 0.025,
        tx: 0.17,
        ty: 0.435,
        tz: -0.515,
        hexColor: trimHex,
      );
      chassisBuilder.addBox(
        w: 0.54,
        h: 0.032,
        l: 0.095,
        tx: 0,
        ty: 0.476,
        tz: -0.515,
        hexColor: paintHex,
      );
    } else if (kind == 2 && role == CTCarRole.normal) {
      for (final side in [-1.0, 1.0]) {
        chassisBuilder.addBox(
          w: 0.024,
          h: 0.018,
          l: 0.34,
          tx: side * 0.18,
          ty: height + 0.046,
          tz: -0.08,
          hexColor: creamHex,
        );
      }
    }

    // 4. Bake the 4 low-poly wheels directly into chassisBuilder so each car
    // requires only 1 chassis node instead of 5 separate nodes!
    for (int wIdx = 0; wIdx < 4; wIdx++) {
      final side = wIdx < 2 ? -1.0 : 1.0;
      final wx = side * TrafficMath.halfTrack;
      const wy = TrafficMath.wheelRadius;
      final wz =
          wIdx.isEven ? -TrafficMath.halfWheelbase : TrafficMath.halfWheelbase;
      final sxCap = wx + side * (0.476 - TrafficMath.halfTrack);

      // Tire
      chassisBuilder.addCylinder(
        radiusTop: TrafficMath.wheelRadius,
        radiusBottom: TrafficMath.wheelRadius,
        height: 0.13,
        radialSegments: 6,
        x: wx,
        y: wy,
        z: wz,
        rz: math.pi / 2,
        hexColor: 0x20242C,
      );
      // Cream hubcap disc
      chassisBuilder.addCylinder(
        radiusTop: 0.088,
        radiusBottom: 0.088,
        height: 0.018,
        radialSegments: 5,
        x: sxCap,
        y: wy,
        z: wz,
        rz: math.pi / 2,
        hexColor: 0xFFF2DE,
      );
    }

    return _CarTemplate(
      combinedMesh: Mesh.primitives(
        primitives: [
          _getOrCreateCarOutline(kind),
          chassisBuilder.build(doubleSided: true, depthLayer: 1),
        ],
      ),
    );
  }

  /// Builds merge celebration star particles, launch dust puffs, and rings
  /// matching effects.js.
  void _buildEffects() {
    _particles.clear();
    _starParticles.clear();
    _puffParticles.clear();
    _effectRings.clear();

    // 5-pointed star mesh
    Mesh makeStarMesh(int hexColor) {
      final b = CartoonMeshBuilder();
      final pts = <Vector3>[];
      for (int i = 0; i < 10; i++) {
        final a = i * math.pi / 5.0 + math.pi / 2.0;
        final r = i.isOdd ? 0.46 : 1.0;
        pts.add(Vector3(math.cos(a) * r, math.sin(a) * r, 0));
      }
      b.addPolygon(pts, hexColor, explicitNormal: Vector3(0, 0, 1), unlit: true);
      return _m(b.build(doubleSided: true));
    }

    final starYellow = makeStarMesh(0xFFD34A);
    final starGreen = makeStarMesh(0x82C86D);

    final puffBuilder = CartoonMeshBuilder()
      ..addEllipsoid(
        x: 0,
        y: 0,
        z: 0,
        sx: 1,
        sy: 1,
        sz: 1,
        hexColor: 0xFFF2E0,
        unlit: true,
      );
    final puffMesh = _m(puffBuilder.build(doubleSided: true));

    for (int i = 0; i < 8; i++) {
      final isStar = i < 5;
      final mesh = isStar ? (i.isOdd ? starYellow : starGreen) : puffMesh;
      final node = Node(name: 'fx-particle-$i', mesh: mesh)..visible = false;
      _worldRoot.add(node);
      final p = _EffectParticle(node: node, isStar: isStar);
      _particles.add(p);
      if (isStar) {
        _starParticles.add(p);
      } else {
        _puffParticles.add(p);
      }
    }

    // 2 expanding ground rings
    for (int rIdx = 0; rIdx < 2; rIdx++) {
      final hex = rIdx == 0 ? 0xFFE797 : 0x82C86D;
      final rb = CartoonMeshBuilder();
      final col = CartoonMeshBuilder.shadeColor(hex, 0, 1, 0, unlit: true);
      const segs = 40;
      for (int i = 0; i <= segs; i++) {
        final a = (i / segs) * math.pi * 2.0;
        final ca = math.cos(a), sa = math.sin(a);
        rb.addVertex(ca * 0.52, 0, sa * 0.52, 0, 1, 0, col);
        rb.addVertex(ca * 0.58, 0, sa * 0.58, 0, 1, 0, col);
      }
      for (int i = 0; i < segs; i++) {
        final k = i * 2;
        rb.addQuad(k, k + 1, k + 3, k + 2);
      }
      final rNode = Node(
        name: 'fx-ring-$rIdx',
        mesh: _m(rb.build(doubleSided: true, depthLayer: 3)),
      )..visible = false;
      _worldRoot.add(rNode);
      _effectRings.add((node: rNode, born: -100.0));
    }
  }

  /// Builds cartoon crash star burst, smoke puffs, sparks, and skid marks
  /// matching crash-effects.js.
  void _buildCrashEffects() {
    _crashGroup = Node(name: 'cartoon-crash-fx')..visible = false;

    // 10-pointed jagged comic burst + dark ink border
    final burstBuilder = CartoonMeshBuilder();
    List<Vector3> burstPoints(double scale, double zOffset) {
      final pts = <Vector3>[];
      for (int i = 0; i < 20; i++) {
        final a = i * math.pi / 10.0;
        final r = (i.isOdd ? 0.32 : 0.61) * scale;
        pts.add(Vector3(math.cos(a) * r, math.sin(a) * r, zOffset));
      }
      return pts;
    }

    burstBuilder.addPolygon(
      burstPoints(1.12, -0.015),
      0x3B3239,
      explicitNormal: Vector3(0, 0, 1),
      unlit: true,
    );
    burstBuilder.addPolygon(
      burstPoints(1.0, 0.0),
      0xFFE068,
      explicitNormal: Vector3(0, 0, 1),
      unlit: true,
    );
    _crashBurst = Node(
      name: 'crash-burst',
      mesh: _m(burstBuilder.build(doubleSided: true, depthLayer: 4)),
    );
    _crashGroup!.add(_crashBurst!);

    // 8 Smoke puffs sharing 2 pre-built ellipsoid meshes (odd & even colors)
    _crashSmoke.clear();
    final smokeOddBuilder = CartoonMeshBuilder()
      ..addEllipsoid(
        x: 0,
        y: 0,
        z: 0,
        sx: 1,
        sy: 1,
        sz: 1,
        hexColor: 0xF4E5CA,
      );
    final smokeEvenBuilder = CartoonMeshBuilder()
      ..addEllipsoid(
        x: 0,
        y: 0,
        z: 0,
        sx: 1,
        sy: 1,
        sz: 1,
        hexColor: 0xD7CBBD,
      );
    final smokeMeshOdd = _m(smokeOddBuilder.build(doubleSided: true));
    final smokeMeshEven = _m(smokeEvenBuilder.build(doubleSided: true));
    for (int i = 0; i < 8; i++) {
      final sNode = Node(
        name: 'crash-smoke-$i',
        mesh: i.isOdd ? smokeMeshOdd : smokeMeshEven,
      );
      _crashGroup!.add(sNode);
      _crashSmoke.add(sNode);
    }

    // 6 Sparks
    _crashSparks.clear();
    final sparkBuilder = CartoonMeshBuilder()
      ..addBox(
        w: 0.035,
        h: 0.035,
        l: 0.19,
        hexColor: 0xFFD34A,
        unlit: true,
      );
    final sparkMesh = _m(sparkBuilder.build(doubleSided: true));
    for (int i = 0; i < 6; i++) {
      final spNode = Node(name: 'crash-spark-$i', mesh: sparkMesh);
      _crashGroup!.add(spNode);
      _crashSparks.add(spNode);
    }

    // 4 Tire skid marks
    _crashSkids.clear();
    final skidBuilder = CartoonMeshBuilder()
      ..addFlatRoundedRect(
        w: 0.048,
        l: 0.49,
        r: 0.015,
        x: 0,
        y: 0,
        z: 0,
        hexColor: 0x3B2F3D,
        unlit: true,
      );
    final skidMesh =
        _m(skidBuilder.build(doubleSided: true, depthLayer: 2));
    for (int i = 0; i < 4; i++) {
      final skNode = Node(name: 'crash-skid-$i', mesh: skidMesh);
      _crashGroup!.add(skNode);
      _crashSkids.add(skNode);
    }

    _worldRoot.add(_crashGroup!);
  }

  int _resolveTemplateKind(
    CTVehicleType type,
    CTCarRole role,
    int fallbackId, {
    int? colorIdx,
  }) {
    if (role == CTCarRole.police) return 8;
    if (role == CTCarRole.green) return 7;
    switch (type) {
      case CTVehicleType.mini:
        return 0;
      case CTVehicleType.car:
        return (colorIdx ?? fallbackId.abs()) % 3;
      case CTVehicleType.van:
      case CTVehicleType.truck:
      case CTVehicleType.bus:
        return 2;
    }
  }

  _CarInstance _getOrCreateCar(
    int id, {
    CTVehicleType type = CTVehicleType.car,
    CTCarRole role = CTCarRole.normal,
    int? colorIdxOverride,
  }) {
    final desiredColor =
        (colorIdxOverride ?? id.abs()) % GameTheme.accentHexColors.length;
    final desiredKind =
        _resolveTemplateKind(type, role, id, colorIdx: desiredColor);

    final existing = _carNodes[id];
    if (existing != null) {
      if (existing.currentKind != desiredKind ||
          existing.currentColorIdx != desiredColor) {
        final tpl = _getCarTemplate(desiredKind, desiredColor);
        existing.root.mesh = tpl.combinedMesh;
        existing.currentKind = desiredKind;
        existing.currentColorIdx = desiredColor;
      }
      return existing;
    }

    final template = _getCarTemplate(desiredKind, desiredColor);

    final Node root;
    if (_freeCarNodes.isNotEmpty) {
      root = _freeCarNodes.removeLast()
        ..mesh = template.combinedMesh
        ..visible = true;
    } else {
      root = Node(name: 'toy-car-$id', mesh: template.combinedMesh);
      _worldRoot.add(root);
    }

    final instance = _CarInstance(
      id: id,
      root: root,
      currentKind: desiredKind,
      currentColorIdx: desiredColor,
    );
    _carNodes[id] = instance;
    return instance;
  }

  void _releaseCarInstance(_CarInstance inst) {
    inst.root.visible = false;
    _freeCarNodes.add(inst.root);
  }

  void _animateCarInstance(
    _CarInstance inst, {
    required String path,
    required double angle,
    required double travel,
    required double launchAge,
    required double progress,
    double? mergeAge,
    required double time,
    required double dt,
    required bool crashed,
    required bool waiting,
  }) {
    if (waiting && !crashed) {
      inst.animLift = math.sin(time * 3.0 + inst.id) * 0.008;
      inst.animPitch = 0.0;
      inst.animRoll = 0.0;
      inst.animSx = 1.0;
      inst.animSy = 1.0;
      inst.animSz = 1.0;
      return;
    }

    final motion = TrafficMath.sampleCarMotion(
      id: inst.id.abs(),
      path: path,
      travel: travel,
      launchAge: launchAge,
      progress: progress,
      mergeAge: mergeAge,
      time: time,
      crashed: crashed,
      waiting: waiting,
    );
    final driving = TrafficMath.advanceDriving(
      inst.driving,
      path: path,
      angle: angle,
      travel: travel,
      dt: dt,
      hasLaunchAge: path == 'ramp',
      crashed: crashed,
      waiting: waiting,
    );
    inst.driving = driving;

    inst.animLift = motion.lift;
    inst.animPitch = motion.pitch + driving.pitch;
    inst.animRoll = motion.roll + driving.roll;
    inst.animSx = motion.sx;
    inst.animSy = motion.sy;
    inst.animSz = motion.sz;
  }

  void _applyCarTransform(
    _CarInstance inst, {
    required double posX,
    required double posY,
    required double posZ,
    required double yaw,
    required double sx,
    required double sy,
    required double sz,
  }) {
    inst.root.position = Vector3(posX, posY + inst.animLift * sy, posZ);
    if (inst.animPitch == 0.0 && inst.animRoll == 0.0) {
      inst.root.rotation = Quaternion.axisAngle(Vector3(0, 1, 0), yaw);
    } else {
      inst.root.rotation = Quaternion.axisAngle(Vector3(0, 1, 0), yaw) *
          Quaternion.euler(0.0, inst.animPitch, inst.animRoll);
    }
    inst.root.scale = Vector3(
      sx * inst.animSx,
      sy * inst.animSy,
      sz * inst.animSz,
    );
  }

  void resetMotion() {
    for (final inst in _carNodes.values) {
      _releaseCarInstance(inst);
    }
    _carNodes.clear();
    _queueEntries = [];
    _lastDrawTime = null;
    _lastNextId = null;
    _lastCleanMerges = 0;
    _lastQueueLen = 0;
    _lastConvertedCarId = null;
  }

  /// Synchronizes the 3D scene graph with the current game state and elapsed time.
  void updateScene(GameTrafficState state, double elapsed) {
    if (!_initialized) return;

    // Rebuild 3D stage track if the stage or road shape changed
    final desiredKey = state.useStagePaths ? state.trackKey : 'classic';
    if (desiredKey != _currentTrackKey) {
      _currentTrackKey = desiredKey;
      resetMotion();
      _rebuildStageTrack(state);
    }

    final dt = _lastDrawTime == null
        ? 0.0
        : (elapsed - _lastDrawTime!).clamp(0.0, 0.11);
    _lastDrawTime = elapsed;

    if (state.useStagePaths) {
      _updateStageScene(state, elapsed, dt);
      return;
    }

    // 1. Reconcile waiting queue (3 cars waiting on the entry ramp in classic mode)
    final byId = {for (final e in _queueEntries) e.id: e};
    final isInitial = _queueEntries.isEmpty;
    _queueEntries = List.generate(TrafficMath.queueCount, (index) {
      final id = state.nextId + index;
      return byId[id] ??
          _QueueEntry(
            id: id,
            born: isInitial
                ? (index == 0
                    ? elapsed - TrafficMath.queueFadeDuration
                    : elapsed + 0.025 + (index - 1) * 0.055)
                : elapsed + TrafficMath.queueSpawnDelay,
          );
    });

    final aliveIds = <int>{
      ...state.cars.map((c) => c.id),
      ..._queueEntries.map((e) => e.id),
    };

    final toRemove =
        _carNodes.keys.where((id) => !aliveIds.contains(id)).toList();
    for (final id in toRemove) {
      final inst = _carNodes.remove(id);
      if (inst != null) {
        _releaseCarInstance(inst);
      }
    }

    // 2. Update active traffic cars (ring + launching ramp cars)
    for (final car in state.cars) {
      final inst = _getOrCreateCar(car.id);
      if (inst.waiting) {
        if (inst.driving != null) {
          inst.driving!
            ..lastTravel = car.travel
            ..speed = 0.0;
        }
        inst.waiting = false;
      }
      inst.root.visible = true;

      final pose = car.pose;
      var posX = pose.x;
      var posY = TrafficMath.surfaceY;
      var posZ = pose.z;
      var yaw = math.atan2(pose.fx, pose.fz);

      _animateCarInstance(
        inst,
        path: car.path,
        angle: car.angle,
        travel: car.travel,
        launchAge: car.launchAge,
        progress: car.progress,
        mergeAge: car.mergeAge,
        time: elapsed,
        dt: dt,
        crashed: state.crashed,
        waiting: false,
      );

      if (state.crashed &&
          state.impact != null &&
          state.impact!.ids.contains(car.id)) {
        final side = state.impact!.ids.first == car.id ? -1.0 : 1.0;
        final m = TrafficMath.crashMotion(state.crashTime, side);
        final dx = pose.x - state.impact!.x;
        final dz = pose.z - state.impact!.z;
        final len = TrafficMath.hypot(dx, dz);
        posX += (len > 1e-6 ? dx / len : side) * m.push;
        posZ += (len > 1e-6 ? dz / len : 0.0) * m.push;
        posY += m.lift;
        yaw += m.yaw;

        inst.animPitch = m.pitch;
        inst.animRoll = m.roll;
        inst.animSx = m.sx;
        inst.animSy = m.sy;
        inst.animSz = 1.0;
      }

      _applyCarTransform(
        inst,
        posX: posX,
        posY: posY,
        posZ: posZ,
        yaw: yaw,
        sx: 1.0,
        sy: 1.0,
        sz: 1.0,
      );
    }

    // 3. Update the 3 waiting queue cars on the approach ramp
    final slots = TrafficMath.queueLayout(
      state.nextId,
      state.cooldown,
      state.releaseDuration,
    );
    for (int index = 0; index < _queueEntries.length; index++) {
      final entry = _queueEntries[index];
      final slot = slots[index];
      final inst = _getOrCreateCar(entry.id);
      inst.waiting = true;

      final p = TrafficMath.approachPose(slot.distance);
      final fade = TrafficMath.smoother(
        (elapsed - entry.born) / TrafficMath.queueFadeDuration,
      );
      inst.root.visible = fade > 0.01;
      final qScale = 0.85 + 0.15 * fade;

      _animateCarInstance(
        inst,
        path: 'waiting',
        angle: 0.0,
        travel: slot.travel,
        launchAge: 0.0,
        progress: 0.0,
        time: elapsed,
        dt: dt,
        crashed: state.crashed,
        waiting: true,
      );
      _applyCarTransform(
        inst,
        posX: p.x,
        posY: TrafficMath.surfaceY,
        posZ: p.z,
        yaw: math.atan2(p.fx, p.fz),
        sx: qScale,
        sy: qScale,
        sz: qScale,
      );
    }

    // 4. Update Launch Cradle animation
    _updateCradleAndTrees(state, elapsed);

    // 5. Update Launch & Merge Particles / Rings
    _updateEffects(state, elapsed);

    // 6. Update Crash Effects
    _updateCrashEffects(state);
  }

  /// Updates the 3D scene when running any of the 100 Stages or 6 Game Modes.
  void _updateStageScene(GameTrafficState state, double elapsed, double dt) {
    final visibleQueueCount = math.min(3, state.queue.length);

    _aliveIdsScratch.clear();
    for (int i = 0; i < state.cars.length; i++) {
      _aliveIdsScratch.add(state.cars[i].id);
    }
    for (int i = 0; i < visibleQueueCount; i++) {
      _aliveIdsScratch.add(state.queue[i].id);
    }

    if (_carNodes.length != _aliveIdsScratch.length ||
        !_carNodes.keys.every(_aliveIdsScratch.contains)) {
      _toRemoveScratch.clear();
      for (final id in _carNodes.keys) {
        if (!_aliveIdsScratch.contains(id)) {
          _toRemoveScratch.add(id);
        }
      }
      for (int i = 0; i < _toRemoveScratch.length; i++) {
        final inst = _carNodes.remove(_toRemoveScratch[i]);
        if (inst != null) {
          _releaseCarInstance(inst);
        }
      }
    }

    // 1. Active cars on loop, entrance ramp, overpass bridge, or green exit road
    const baseScale = 0.68;
    for (final car in state.cars) {
      final inst = _getOrCreateCar(
        car.id,
        type: car.vehicleType,
        role: car.role,
        colorIdxOverride: car.colorIndex,
      );
      inst.waiting = false;
      inst.root.visible = car.alpha > 0.02;

      final sx = car.widthScale * baseScale * car.alpha;
      final sy = (car.vehicleType == CTVehicleType.bus ||
              car.vehicleType == CTVehicleType.truck
          ? 0.78
          : car.vehicleType == CTVehicleType.van
              ? 0.74
              : baseScale) *
          car.alpha;
      final sz = car.lengthScale * baseScale * car.alpha;

      final pose = car.pose;
      var posX = pose.x;
      var posY = car.elevationY;
      var posZ = pose.z;
      var yaw = math.atan2(pose.fx, pose.fz);

      _animateCarInstance(
        inst,
        path: car.path,
        angle: car.angle,
        travel: car.travel,
        launchAge: car.launchAge,
        progress: car.progress,
        mergeAge: car.mergeAge,
        time: elapsed,
        dt: dt,
        crashed: state.crashed,
        waiting: false,
      );

      if (state.crashed &&
          state.impact != null &&
          state.impact!.ids.contains(car.id)) {
        final side = state.impact!.ids.first == car.id ? -1.0 : 1.0;
        final m = TrafficMath.crashMotion(state.crashTime, side);
        final dx = pose.x - state.impact!.x;
        final dz = pose.z - state.impact!.z;
        final len = TrafficMath.hypot(dx, dz);
        posX += (len > 1e-6 ? dx / len : side) * m.push;
        posZ += (len > 1e-6 ? dz / len : 0.0) * m.push;
        posY += m.lift;
        yaw += m.yaw;

        inst.animPitch = m.pitch;
        inst.animRoll = m.roll;
        inst.animSx = m.sx;
        inst.animSy = m.sy;
        inst.animSz = 1.0;
      }

      _applyCarTransform(
        inst,
        posX: posX,
        posY: posY,
        posZ: posZ,
        yaw: yaw,
        sx: sx,
        sy: sy,
        sz: sz,
      );
    }

    // 2. Waiting queue cars on the stage entrance ramp (showing their true role & type!)
    for (int i = 0; i < visibleQueueCount; i++) {
      final qCar = state.queue[i];
      final inst = _getOrCreateCar(
        qCar.id,
        type: qCar.vehicleType,
        role: qCar.role,
        colorIdxOverride: qCar.colorIndex,
      );
      inst.waiting = true;
      inst.root.visible = true;

      final p = qCar.pose;
      _animateCarInstance(
        inst,
        path: 'waiting',
        angle: 0.0,
        travel: 0.0,
        launchAge: 0.0,
        progress: 0.0,
        time: elapsed,
        dt: dt,
        crashed: state.crashed,
        waiting: true,
      );
      _applyCarTransform(
        inst,
        posX: p.x,
        posY: TrafficMath.surfaceY,
        posZ: p.z,
        yaw: math.atan2(p.fx, p.fz),
        sx: qCar.widthScale * baseScale,
        sy: baseScale,
        sz: qCar.lengthScale * baseScale,
      );
    }

    // 3. Police conversion star burst effect
    if (state.lastConversion != null &&
        state.lastConversion!.id != _lastConvertedCarId) {
      final conv = state.lastConversion!;
      _lastConvertedCarId = conv.id;
      _effectRings[1] = (node: _effectRings[1].node, born: elapsed);
      _effectRings[1].node.position =
          Vector3(conv.x, TrafficMath.surfaceY + 0.03, conv.z);
      for (int i = 0; i < _starParticles.length; i++) {
        final a = i * 2.399;
        _starParticles[i]
          ..born = elapsed
          ..x = conv.x
          ..z = conv.z
          ..vx = math.cos(a) * (1.1 + (i % 3) * 0.22)
          ..vz = math.sin(a) * (0.85 + (i % 3) * 0.18)
          ..seed = i;
      }
    }

    _updateCradleAndTrees(state, elapsed);
    _updateEffects(state, elapsed);
    _updateCrashEffects(state);
  }

  void _updateCradleAndTrees(GameTrafficState state, double elapsed) {
    final pulse =
        TrafficMath.launchBayPulse(state.cooldown, state.releaseDuration);
    if ((pulse - _lastCradlePulse).abs() > 1e-4) {
      _lastCradlePulse = pulse;
      if (_cradlePodNode != null) {
        _cradlePodNode!.scale =
            Vector3(1.0 + pulse * 0.012, 1.0, 1.0 - pulse * 0.016);
      }
      for (int i = 0; i < _cradleArrows.length; i++) {
        final side = i == 0 ? -1.0 : 1.0;
        if (state.useStagePaths) {
          _cradleArrows[i].position = Vector3(
            TrafficMath.queueX + side * 0.25,
            TrafficMath.surfaceY + 0.012,
            TrafficMath.queueZ - 0.78 - pulse * 0.14,
          );
          _cradleArrows[i].rotation =
              Quaternion.axisAngle(Vector3(0, 1, 0), 0.0);
        } else {
          final p = TrafficMath.approachPose(1.08 + pulse * 0.17);
          _cradleArrows[i].position = Vector3(
            p.x - p.fz * side * 0.25,
            TrafficMath.surfaceY + 0.012,
            p.z + p.fx * side * 0.25,
          );
          _cradleArrows[i].rotation =
              Quaternion.axisAngle(Vector3(0, 1, 0), math.atan2(-p.fx, -p.fz));
        }
      }
      for (final rail in _cradleRails) {
        rail.scale = Vector3(1.0, 1.0 + pulse * 0.2, 1.0);
      }
    }

    if (state.cleanMerges > _lastMergeSerial) {
      _celebrationTime = elapsed;
    }
    _lastMergeSerial = state.cleanMerges;
    if (_pineFoliageNode != null) {
      final wave = elapsed - _celebrationTime;
      if (wave >= 0 && wave < 0.85) {
        final cheer = math.sin(wave * 12.0) * math.exp(-wave * 4.0) * 0.025;
        _pineFoliageNode!.scale = Vector3(1.0 + cheer, 1.0 - cheer * 0.5, 1.0 + cheer);
      } else {
        _pineFoliageNode!.scale = Vector3.all(1.0);
      }
    }
  }

  void _updateEffects(GameTrafficState state, double time) {
    final launched = (_lastNextId != null && state.nextId > _lastNextId!) ||
        (state.useStagePaths &&
            _lastQueueLen > 0 &&
            state.queue.length < _lastQueueLen);
    if (launched) {
      _effectRings[0] = (node: _effectRings[0].node, born: time);
      _effectRings[0].node.position = Vector3(
        _activeQueueX,
        TrafficMath.surfaceY + 0.018,
        _activeQueueZ,
      );
      for (int i = 0; i < _puffParticles.length; i++) {
        _puffParticles[i]
          ..born = time + 0.08 + i * 0.02
          ..x = _activeQueueX + (i.isOdd ? 1.0 : -1.0) * 0.57
          ..z = _activeQueueZ + 0.68 + (i % 3) * 0.10
          ..vx = (i.isOdd ? 1.0 : -1.0) * 0.50
          ..vz = 0.25
          ..seed = i;
      }
    }

    if (state.cleanMerges > _lastCleanMerges && state.lastMerge != null) {
      final m = state.lastMerge!;
      _effectRings[1] = (node: _effectRings[1].node, born: time);
      _effectRings[1].node.position =
          Vector3(m.x, TrafficMath.surfaceY + 0.022, m.z);
      for (int i = 0; i < _starParticles.length; i++) {
        final a = i * 2.399;
        _starParticles[i]
          ..born = time
          ..x = m.x
          ..z = m.z
          ..vx = math.cos(a) * (0.95 + (i % 3) * 0.20)
          ..vz = math.sin(a) * (0.70 + (i % 3) * 0.17)
          ..seed = i;
      }
    }

    if (_lastNextId != null && state.nextId < _lastNextId!) {
      for (final p in _particles) {
        p.born = -100.0;
      }
      for (int i = 0; i < _effectRings.length; i++) {
        _effectRings[i] = (node: _effectRings[i].node, born: -100.0);
      }
    }

    if (state.crashed) {
      for (final p in _starParticles) {
        p.born = -100.0;
      }
      for (int i = 0; i < _effectRings.length; i++) {
        _effectRings[i] = (node: _effectRings[i].node, born: -100.0);
      }
    }

    _lastNextId = state.nextId;
    _lastCleanMerges = state.cleanMerges;
    _lastQueueLen = state.queue.length;

    for (final p in _particles) {
      final age = time - p.born;
      final life = p.isStar ? 0.72 : 0.52;
      final visible = age >= 0 && age < life;
      p.node.visible = visible;
      if (!visible) continue;
      final u = age / life;
      final py = TrafficMath.surfaceY +
          (p.isStar
              ? 0.82 + math.sin(u * math.pi * 0.8) * 0.8
              : 0.08 + u * 0.26);
      p.node.position = Vector3(p.x + p.vx * age, py, p.z + p.vz * age);
      final size = (p.isStar
              ? 0.13 * (1.0 - u * 0.45)
              : 0.13 * (1.0 + u * 1.7)) *
          (1.0 - u * 0.5);
      p.node.scale = Vector3.all(math.max(0.01, size));
      p.node.rotation = Quaternion.euler(age * 2.0 + p.seed, -0.5, age * 2.0);
    }

    for (final r in _effectRings) {
      final u = (time - r.born) / 0.55;
      final visible = u >= 0 && u < 1.0;
      r.node.visible = visible;
      if (visible) {
        r.node.scale = Vector3.all(1.0 + u * 1.3);
      }
    }
  }

  void _updateCrashEffects(GameTrafficState state) {
    if (_crashGroup == null) return;
    _crashGroup!.visible = state.crashed && state.impact != null;
    if (!_crashGroup!.visible) return;

    final impact = state.impact!;
    final t = state.crashTime;

    if (_crashBurst != null) {
      _crashBurst!.visible = t < 0.47;
      _crashBurst!.position =
          Vector3(impact.x, 1.08 + math.min(t, 0.45) * 0.8, impact.z);
      _crashBurst!.rotation =
          Quaternion.euler(0.0, -0.68, math.sin(t * 18.0) * 0.12);
      final s =
          0.6 + math.sin(math.min(1.0, t / 0.47) * math.pi) * 0.52;
      _crashBurst!.scale = Vector3.all(s);
    }

    for (int i = 0; i < _crashSmoke.length; i++) {
      final m = _crashSmoke[i];
      final age = t - 0.035 - i * 0.018;
      final u = age / 1.15;
      m.visible = u >= 0 && u < 1.0;
      if (!m.visible) continue;
      final a = i * 2.399;
      m.position = Vector3(
        impact.x + math.cos(a) * u * 0.62,
        TrafficMath.surfaceY + 0.35 + u * 0.91,
        impact.z + math.sin(a) * u * 0.48,
      );
      final sz = (0.115 + u * 0.21) * (1.0 - u * 0.6);
      m.scale = Vector3.all(math.max(0.01, sz));
    }

    for (int i = 0; i < _crashSparks.length; i++) {
      final m = _crashSparks[i];
      m.visible = t < 0.48;
      if (!m.visible) continue;
      final a = i * math.pi / 3.0;
      m.position = Vector3(
        impact.x + math.cos(a) * t * 1.65,
        TrafficMath.surfaceY +
            0.3 +
            math.sin(math.min(1.0, t / 0.48) * math.pi) * 0.42,
        impact.z + math.sin(a) * t * 1.5,
      );
      m.rotation = Quaternion.euler(t * 9.0, a, a);
      m.scale = Vector3.all(math.max(0.05, 1.0 - t / 0.48));
    }

    for (int i = 0; i < impact.ids.length && i < 2; i++) {
      final id = impact.ids[i];
      final car = state.cars.where((c) => c.id == id).firstOrNull;
      if (car == null) continue;
      final p = car.pose;
      for (int j = 0; j < 2; j++) {
        final m = _crashSkids[i * 2 + j];
        final side = j == 1 ? 1.0 : -1.0;
        m.visible = t > 0.09;
        m.position = Vector3(
          p.x - p.fx * 0.42 - p.fz * side * 0.34,
          TrafficMath.surfaceY + 0.009,
          p.z - p.fz * 0.42 + p.fx * side * 0.34,
        );
        m.rotation =
            Quaternion.axisAngle(Vector3(0, 1, 0), math.atan2(p.fx, p.fz));
      }
    }
  }

  double _computeCameraDZ(Size? screenSize) {
    if (screenSize == null ||
        screenSize.width <= 0 ||
        screenSize.height <= 0) {
      return 0.0;
    }
    const dy = -CameraConfig.height; // -12.8
    const dz = CameraConfig.targetZ - CameraConfig.depth; // -14.9
    final len = TrafficMath.hypot(dy, dz);
    final upZ = dy / len; // -0.6515946
    const camYTopRoad = 5.1258; // Top of circular road at z = -4.92
    const targetNdcY = 0.5076; // Places top of road at 24.62% from top (horizon)
    final halfH =
        CameraConfig.halfWidth * (screenSize.height / screenSize.width);
    return (camYTopRoad - targetNdcY * halfH) / upZ;
  }

  /// Creates the OrthographicCamera matching renderer.js (with crash jolt and aspect alignment)
  Camera buildCamera(GameTrafficState state, [Size? screenSize]) {
    if (!state.crashed &&
        _cachedStaticCamera != null &&
        _cachedCameraScreenSize == screenSize) {
      return _cachedStaticCamera!;
    }
    final jolt = state.crashed
        ? TrafficMath.crashJolt(state.crashTime)
        : (x: 0.0, z: 0.0);
    final dZ = _computeCameraDZ(screenSize);
    final cam = OrthographicCamera(
      position: Vector3(
        jolt.x,
        CameraConfig.height,
        -(CameraConfig.depth + dZ + jolt.z),
      ),
      target: Vector3(
        jolt.x,
        0.0,
        -(CameraConfig.targetZ + dZ + jolt.z),
      ),
      up: Vector3(0.0, 1.0, 0.0),
      projection: OrthographicProjection(
        size: const OrthographicSize.width(CameraConfig.halfWidth * 2.0),
        near: CameraConfig.near,
        far: CameraConfig.far,
      ),
    );
    if (!state.crashed) {
      _cachedCameraScreenSize = screenSize;
      _cachedStaticCamera = cam;
    }
    return cam;
  }

  /// Projects a car's 3D world position + elevation into 2D screen coordinates
  /// (matching renderer.projectCar in renderer.js for "Smooth merge! +1" popups).
  Offset? projectCar(int id, double elevation, Size screenSize) {
    final inst = _carNodes[id];
    if (inst == null || screenSize.width <= 0 || screenSize.height <= 0) {
      return null;
    }
    final pos = inst.root.position;
    final wx = pos.x;
    final wy = pos.y + elevation;
    final wz = pos.z;

    const dy = -CameraConfig.height;
    const dz = CameraConfig.targetZ - CameraConfig.depth;
    final len = TrafficMath.hypot(dy, dz);
    final upY = -dz / len;
    final upZ = dy / len;
    final dZ = _computeCameraDZ(screenSize);

    final relY = wy;
    final relZ = wz - (CameraConfig.targetZ + dZ);

    final camX = wx;
    final camY = relY * upY + relZ * upZ;

    const halfW = CameraConfig.halfWidth;
    final halfH = halfW * screenSize.height / screenSize.width;

    final ndcX = camX / halfW;
    final ndcY = camY / halfH;

    final sx = (ndcX * 0.5 + 0.5) * screenSize.width;
    final sy = (-ndcY * 0.5 + 0.5) * screenSize.height;
    return Offset(sx, sy);
  }
}
