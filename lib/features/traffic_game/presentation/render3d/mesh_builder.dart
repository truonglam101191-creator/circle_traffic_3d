import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart';
import '../../domain/services/traffic_math_service.dart';

/// Builds MeshPrimitives with baked Three.js lighting (Hemisphere + Key + Fill)
/// and inverted-hull cartoon outlines so colors and silhouettes match the
/// original Three.js WebGL renderer 100%.
class CartoonMeshBuilder {
  final List<double> _positions = [];
  final List<double> _normals = [];
  final List<double> _colors = [];
  final List<double> _uvs = [];
  final List<int> _indices = [];

  int get vertexCount => _positions.length ~/ 3;

  static double _srgbToLinear(double c) {
    final v = c.clamp(0.0, 1.0);
    return v <= 0.04045
        ? v / 12.92
        : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  }

  /// Computes the shaded linear RGBA color for a vertex given its base sRGB hex
  /// color and surface normal (nx, ny, nz) in Three.js world/object space.
  static Vector4 shadeColor(
    int hexColor,
    double nx,
    double ny,
    double nz, {
    bool unlit = false,
    double specular = 0.0,
    double alpha = 1.0,
    double scalar = 1.0,
  }) {
    double r = ((hexColor >> 16) & 0xFF) / 255.0 * scalar;
    double g = ((hexColor >> 8) & 0xFF) / 255.0 * scalar;
    double b = (hexColor & 0xFF) / 255.0 * scalar;

    if (!unlit) {
      final len = math.sqrt(nx * nx + ny * ny + nz * nz);
      final ux = len > 1e-6 ? nx / len : 0.0;
      final uy = len > 1e-6 ? ny / len : 1.0;
      final uz = len > 1e-6 ? nz / len : 0.0;

      // Key light at (-5, 12, 5) normalized = (-0.360, 0.864, 0.360)
      final keyDot = math.max(0.0, ux * -0.360 + uy * 0.864 + uz * 0.360);
      // Fill light at (6, 6, -8) normalized = (0.514, 0.514, -0.686)
      final fillDot = math.max(0.0, ux * 0.514 + uy * 0.514 + uz * -0.686);
      // Hemisphere sky/ground factor
      final hemi = 0.5 * uy + 0.5;

      // Balanced cartoon shading matching Three.js ACESFilmic + Hemisphere + Key/Fill
      final lr = 0.52 + 0.22 * hemi + 0.36 * keyDot + 0.06 * fillDot;
      final lg = 0.50 + 0.21 * hemi + 0.35 * keyDot + 0.06 * fillDot;
      final lb = 0.51 + 0.19 * hemi + 0.33 * keyDot + 0.09 * fillDot;

      r = r * lr;
      g = g * lg;
      b = b * lb;

      if (specular > 0.0) {
        // Half-vector between Key (-0.36, 0.864, 0.36) and View (0, 0.65, 0.76)
        final hDot = math.max(0.0, ux * -0.19 + uy * 0.81 + uz * 0.56);
        final spec = math.pow(hDot, 16.0).toDouble() * specular;
        r += spec * 1.0;
        g += spec * 0.96;
        b += spec * 0.90;
      }
    }

    return Vector4(
      _srgbToLinear(r),
      _srgbToLinear(g),
      _srgbToLinear(b),
      alpha.clamp(0.0, 1.0),
    );
  }

  int addVertex(
    double x,
    double y,
    double z,
    double nx,
    double ny,
    double nz,
    Vector4 linearColor, [
    double u = 0.0,
    double v = 0.0,
  ]) {
    final idx = vertexCount;
    _positions
      ..add(x)
      ..add(y)
      ..add(z);
    _normals
      ..add(nx)
      ..add(ny)
      ..add(nz);
    _colors
      ..add(linearColor.r)
      ..add(linearColor.g)
      ..add(linearColor.b)
      ..add(linearColor.a);
    _uvs
      ..add(u)
      ..add(v);
    return idx;
  }

  void addTriangle(int i0, int i1, int i2, {bool flipWinding = false}) {
    if (flipWinding) {
      _indices
        ..add(i0)
        ..add(i2)
        ..add(i1);
    } else {
      _indices
        ..add(i0)
        ..add(i1)
        ..add(i2);
    }
  }

  void addQuad(int i0, int i1, int i2, int i3, {bool flipWinding = false}) {
    addTriangle(i0, i1, i2, flipWinding: flipWinding);
    addTriangle(i0, i2, i3, flipWinding: flipWinding);
  }

  /// Adds a flat-shaded polygon fan (CCW in Three.js space)
  void addPolygon(
    List<Vector3> points,
    int hexColor, {
    Vector3? explicitNormal,
    bool unlit = false,
    double specular = 0.0,
    double alpha = 1.0,
    bool flipWinding = false,
    double inflate = 0.0,
  }) {
    if (points.length < 3) return;
    Vector3 n = explicitNormal ??
        (points[1] - points[0]).cross(points[2] - points[0]).normalized();
    if (n.length2 < 1e-9) {
      n = Vector3(0, 1, 0);
    }
    final c = shadeColor(
      hexColor,
      n.x,
      n.y,
      n.z,
      unlit: unlit,
      specular: specular,
      alpha: alpha,
    );
    final baseIdx = vertexCount;
    for (final p in points) {
      addVertex(
        p.x + n.x * inflate,
        p.y + n.y * inflate,
        p.z + n.z * inflate,
        n.x,
        n.y,
        n.z,
        c,
      );
    }
    for (int i = 1; i < points.length - 1; i++) {
      addTriangle(baseIdx, baseIdx + i, baseIdx + i + 1,
          flipWinding: flipWinding);
    }
  }

  /// Adds an oriented 3D box with local rotation (rx, ry, rz) and translation (tx, ty, tz)
  void addBox({
    required double w,
    required double h,
    required double l,
    double tx = 0.0,
    double ty = 0.0,
    double tz = 0.0,
    double rx = 0.0,
    double ry = 0.0,
    double rz = 0.0,
    required int hexColor,
    bool unlit = false,
    double specular = 0.0,
    double alpha = 1.0,
    double inflate = 0.0,
    bool flipWinding = false,
  }) {
    final hw = w / 2.0 + inflate;
    final hh = h / 2.0 + inflate;
    final hl = l / 2.0 + inflate;

    final rot = Matrix3.identity();
    if (rx != 0 || ry != 0 || rz != 0) {
      final q = Quaternion.euler(ry, rx, rz);
      rot.setFrom(q.asRotationMatrix());
    }

    Vector3 xform(double x, double y, double z) {
      final v = rot.transformed(Vector3(x, y, z));
      return Vector3(v.x + tx, v.y + ty, v.z + tz);
    }

    Vector3 xformN(double nx, double ny, double nz) {
      return rot.transformed(Vector3(nx, ny, nz)).normalized();
    }

    // 6 faces (CCW when viewed from outside in right-handed Three.js space)
    final faces = <({List<List<double>> verts, List<double> n})>[
      // Front (+Z)
      (
        verts: [
          [-hw, -hh, hl],
          [hw, -hh, hl],
          [hw, hh, hl],
          [-hw, hh, hl],
        ],
        n: [0, 0, 1],
      ),
      // Back (-Z)
      (
        verts: [
          [hw, -hh, -hl],
          [-hw, -hh, -hl],
          [-hw, hh, -hl],
          [hw, hh, -hl],
        ],
        n: [0, 0, -1],
      ),
      // Top (+Y)
      (
        verts: [
          [-hw, hh, hl],
          [hw, hh, hl],
          [hw, hh, -hl],
          [-hw, hh, -hl],
        ],
        n: [0, 1, 0],
      ),
      // Right (+X)
      (
        verts: [
          [hw, -hh, hl],
          [hw, -hh, -hl],
          [hw, hh, -hl],
          [hw, hh, hl],
        ],
        n: [1, 0, 0],
      ),
      // Left (-X)
      (
        verts: [
          [-hw, -hh, -hl],
          [-hw, -hh, hl],
          [-hw, hh, hl],
          [-hw, hh, -hl],
        ],
        n: [-1, 0, 0],
      ),
    ];

    for (final f in faces) {
      final n = xformN(f.n[0], f.n[1], f.n[2]);
      final pts = f.verts.map((v) => xform(v[0], v[1], v[2])).toList();
      addPolygon(
        pts,
        hexColor,
        explicitNormal: n,
        unlit: unlit,
        specular: specular,
        alpha: alpha,
        flipWinding: flipWinding,
      );
    }
  }

  /// Generates a 2D rounded rectangle contour in XZ (centered at origin)
  static List<({double x, double z, double nx, double nz})> roundedRectContour(
    double w,
    double l,
    double r, {
    int cornerSegments = 3,
  }) {
    final a = w / 2.0;
    final b = l / 2.0;
    final cr = math.min(r, math.min(a, b));
    final result = <({double x, double z, double nx, double nz})>[];

    // 4 corners in CCW order when viewed from +Y (+X/-Z -> -X/-Z -> -X/+Z -> +X/+Z)
    final corners = [
      (cx: a - cr, cz: -b + cr, startAngle: 0.0),
      (cx: -a + cr, cz: -b + cr, startAngle: -math.pi / 2),
      (cx: -a + cr, cz: b - cr, startAngle: -math.pi),
      (cx: a - cr, cz: b - cr, startAngle: -1.5 * math.pi),
    ];

    for (final c in corners) {
      for (int i = 0; i <= cornerSegments; i++) {
        final angle = c.startAngle - (i / cornerSegments) * (math.pi / 2);
        final nx = math.cos(angle);
        final nz = math.sin(angle);
        result.add((
          x: c.cx + nx * cr,
          z: c.cz + nz * cr,
          nx: nx,
          nz: nz,
        ));
      }
    }
    return result;
  }

  /// Adds a flat 2D rounded rectangle pad in XZ at height y
  void addFlatRoundedRect({
    required double w,
    required double l,
    required double r,
    required double x,
    required double y,
    required double z,
    required int hexColor,
    bool unlit = false,
    double alpha = 1.0,
    int cornerSegments = 4,
  }) {
    final contour =
        roundedRectContour(w, l, r, cornerSegments: cornerSegments);
    final c = shadeColor(hexColor, 0, 1, 0, unlit: unlit, alpha: alpha);
    final centerIdx = addVertex(x, y, z, 0, 1, 0, c);
    final ringStart = vertexCount;
    for (final p in contour) {
      addVertex(x + p.x, y, z + p.z, 0, 1, 0, c);
    }
    final n = contour.length;
    for (int i = 0; i < n; i++) {
      addTriangle(centerIdx, ringStart + i, ringStart + (i + 1) % n);
    }
  }

  /// Adds an extruded beveled rounded box (matching Three.js softBox in car-model.js)
  void addSoftBox({
    required double w,
    required double l,
    required double h,
    required double r,
    required double x,
    required double y,
    required double z,
    double bevel = 0.035,
    required int hexColor,
    bool unlit = false,
    double specular = 0.0,
    double inflate = 0.0,
    bool flipWinding = false,
  }) {
    final contour = roundedRectContour(w, l, r, cornerSegments: 1);
    final n = contour.length;

    // 4 height rings from bottom to top with bevel
    final rings = <({double ry, double expand, double ny, double nHoriz})>[
      (ry: y - bevel - inflate, expand: inflate, ny: -0.95, nHoriz: 0.31),
      (
        ry: y - bevel * 0.25 - inflate * 0.4,
        expand: bevel + inflate,
        ny: -0.35,
        nHoriz: 0.94,
      ),
      (
        ry: y + h + bevel * 0.25 + inflate * 0.4,
        expand: bevel + inflate,
        ny: 0.35,
        nHoriz: 0.94,
      ),
      (ry: y + h + bevel + inflate, expand: inflate, ny: 0.95, nHoriz: 0.31),
    ];

    final ringStarts = <int>[];
    for (final layer in rings) {
      final start = vertexCount;
      ringStarts.add(start);
      for (final p in contour) {
        final vx = x + p.x + p.nx * layer.expand;
        final vy = layer.ry;
        final vz = z + p.z + p.nz * layer.expand;
        final nx = p.nx * layer.nHoriz;
        final ny = layer.ny;
        final nz = p.nz * layer.nHoriz;
        final c = shadeColor(
          hexColor,
          nx,
          ny,
          nz,
          unlit: unlit,
          specular: specular,
        );
        addVertex(vx, vy, vz, nx, ny, nz, c);
      }
    }

    // Connect adjacent rings
    for (int rIdx = 0; rIdx < rings.length - 1; rIdx++) {
      final s0 = ringStarts[rIdx];
      final s1 = ringStarts[rIdx + 1];
      for (int i = 0; i < n; i++) {
        final next = (i + 1) % n;
        addQuad(
          s0 + i,
          s0 + next,
          s1 + next,
          s1 + i,
          flipWinding: flipWinding,
        );
      }
    }

    // Top cap
    final topColor =
        shadeColor(hexColor, 0, 1, 0, unlit: unlit, specular: specular);
    final topCenter =
        addVertex(x, rings.last.ry, z, 0, 1, 0, topColor);
    final topRing = ringStarts.last;
    for (int i = 0; i < n; i++) {
      addTriangle(
        topCenter,
        topRing + i,
        topRing + (i + 1) % n,
        flipWinding: flipWinding,
      );
    }
  }

  /// Adds the sloped car cabin matching car-model.js lines 53-65
  void addCabin({
    required int kind,
    required int hexColor,
    double specular = 0.25,
    bool unlit = false,
    double inflate = 0.0,
    bool flipWinding = false,
  }) {
    final height = [0.65, 0.70, 0.72][kind];
    final roofBack = [-0.19, -0.28, -0.30][kind];
    final roofFront = [0.12, 0.13, 0.14][kind];
    const frontBase = 0.35;
    final backBase = kind == 0 ? -0.39 : -0.47;

    // Profile points (y, z) in CCW order on +X side
    final profile = <({double y, double z})>[
      (y: 0.37, z: frontBase),
      (y: height - 0.07, z: roofFront + 0.055),
      (y: height - 0.015, z: roofFront + 0.015),
      (y: height, z: roofFront - 0.035),
      (y: height, z: roofBack + 0.045),
      (y: height - 0.015, z: roofBack - 0.015),
      (y: height - 0.06, z: roofBack - 0.05),
      (y: 0.37, z: backBase),
    ];

    final m = profile.length;
    // Compute 2D outward normals in (y, z)
    final pNormals = List<({double ny, double nz})>.generate(m, (i) {
      if (i == 0) {
        return (ny: 0.0, nz: 1.0);
      }
      if (i == m - 1) {
        return (ny: 0.0, nz: -1.0);
      }
      final prev = profile[i - 1];
      final curr = profile[i];
      final next = profile[i + 1];
      final dy1 = curr.y - prev.y, dz1 = curr.z - prev.z;
      final l1 = math.max(1e-6, TrafficMath.hypot(dy1, dz1));
      final dy2 = next.y - curr.y, dz2 = next.z - curr.z;
      final l2 = math.max(1e-6, TrafficMath.hypot(dy2, dz2));
      var ny = (-dz1 / l1 - dz2 / l2) * 0.5;
      var nz = (dy1 / l1 + dy2 / l2) * 0.5;
      final nl = math.max(1e-6, TrafficMath.hypot(ny, nz));
      ny /= nl;
      nz /= nl;
      return (ny: ny, nz: nz);
    });

    const halfWidth = 0.245;
    const bevelX = 0.035;
    const bevelYZ = 0.030;

    final slices = <({double x, double shrink, double nx, double nYZ})>[
      (
        x: -(halfWidth + bevelX + inflate),
        shrink: inflate,
        nx: -0.92,
        nYZ: 0.39,
      ),
      (
        x: -(halfWidth + inflate * 0.4),
        shrink: bevelYZ + inflate,
        nx: -0.25,
        nYZ: 0.97,
      ),
      (
        x: halfWidth + inflate * 0.4,
        shrink: bevelYZ + inflate,
        nx: 0.25,
        nYZ: 0.97,
      ),
      (
        x: halfWidth + bevelX + inflate,
        shrink: inflate,
        nx: 0.92,
        nYZ: 0.39,
      ),
    ];

    final sliceStarts = <int>[];
    for (final s in slices) {
      final start = vertexCount;
      sliceStarts.add(start);
      for (int i = 0; i < m; i++) {
        final p = profile[i];
        final pn = pNormals[i];
        final vy = p.y + pn.ny * s.shrink;
        final vz = p.z + pn.nz * s.shrink;
        final nx = s.nx;
        final ny = pn.ny * s.nYZ;
        final nz = pn.nz * s.nYZ;
        final c = shadeColor(
          hexColor,
          nx,
          ny,
          nz,
          unlit: unlit,
          specular: specular,
        );
        addVertex(s.x, vy, vz, nx, ny, nz, c);
      }
    }

    for (int sIdx = 0; sIdx < slices.length - 1; sIdx++) {
      final s0 = sliceStarts[sIdx];
      final s1 = sliceStarts[sIdx + 1];
      for (int i = 0; i < m - 1; i++) {
        final next = i + 1;
        addQuad(
          s0 + i,
          s1 + i,
          s1 + next,
          s0 + next,
          flipWinding: flipWinding,
        );
      }
    }

    // Left cap (-X)
    final leftStart = sliceStarts.first;
    for (int i = 1; i < m - 1; i++) {
      addTriangle(
        leftStart,
        leftStart + i,
        leftStart + i + 1,
        flipWinding: flipWinding,
      );
    }

    // Right cap (+X)
    final rightStart = sliceStarts.last;
    for (int i = 1; i < m - 1; i++) {
      addTriangle(
        rightStart,
        rightStart + i + 1,
        rightStart + i,
        flipWinding: flipWinding,
      );
    }
  }

  /// Adds an ellipsoid at (x, y, z) with radii (sx, sy, sz)
  void addEllipsoid({
    required double x,
    required double y,
    required double z,
    required double sx,
    required double sy,
    required double sz,
    required int hexColor,
    bool unlit = false,
    double specular = 0.0,
    double inflate = 0.0,
    bool flipWinding = false,
    int widthSegments = 4,
    int heightSegments = 2,
  }) {
    final rx = sx + inflate;
    final ry = sy + inflate;
    final rz = sz + inflate;
    final grid = <List<int>>[];

    for (int iy = 0; iy <= heightSegments; iy++) {
      final v = iy / heightSegments;
      final phi = v * math.pi;
      final row = <int>[];
      for (int ix = 0; ix <= widthSegments; ix++) {
        final u = ix / widthSegments;
        final theta = u * math.pi * 2.0;
        final ux = -math.cos(theta) * math.sin(phi);
        final uy = math.cos(phi);
        final uz = math.sin(theta) * math.sin(phi);
        final px = x + ux * rx;
        final py = y + uy * ry;
        final pz = z + uz * rz;
        final nx = ux / math.max(1e-4, rx);
        final ny = uy / math.max(1e-4, ry);
        final nz = uz / math.max(1e-4, rz);
        final c = shadeColor(
          hexColor,
          nx,
          ny,
          nz,
          unlit: unlit,
          specular: specular,
        );
        row.add(addVertex(px, py, pz, nx, ny, nz, c, u, v));
      }
      grid.add(row);
    }

    for (int iy = 0; iy < heightSegments; iy++) {
      for (int ix = 0; ix < widthSegments; ix++) {
        final a = grid[iy][ix + 1];
        final b = grid[iy][ix];
        final c = grid[iy + 1][ix];
        final d = grid[iy + 1][ix + 1];
        if (iy != 0) {
          addTriangle(a, b, d, flipWinding: flipWinding);
        }
        if (iy != heightSegments - 1) {
          addTriangle(b, c, d, flipWinding: flipWinding);
        }
      }
    }
  }

  /// Adds a cylinder/cone (along Y axis by default, or rotated along X for wheels)
  void addCylinder({
    required double radiusTop,
    required double radiusBottom,
    required double height,
    int radialSegments = 16,
    double x = 0.0,
    double y = 0.0,
    double z = 0.0,
    double rx = 0.0,
    double ry = 0.0,
    double rz = 0.0,
    double scaleX = 1.0,
    double scaleY = 1.0,
    double scaleZ = 1.0,
    required int hexColor,
    double scalar = 1.0,
    bool flatShading = false,
    bool unlit = false,
    bool flipWinding = false,
  }) {
    final rot = Matrix3.identity();
    if (rx != 0 || ry != 0 || rz != 0) {
      rot.setFrom(Quaternion.euler(ry, rx, rz).asRotationMatrix());
    }

    Vector3 xform(double px, double py, double pz) {
      final v = rot.transformed(Vector3(px * scaleX, py * scaleY, pz * scaleZ));
      return Vector3(v.x + x, v.y + y, v.z + z);
    }

    Vector3 xformN(double nx, double ny, double nz) {
      return rot
          .transformed(Vector3(nx / scaleX, ny / scaleY, nz / scaleZ))
          .normalized();
    }

    final halfH = height / 2.0;
    final slopeY = (radiusBottom - radiusTop) / math.max(1e-5, height);

    if (flatShading) {
      for (int i = 0; i < radialSegments; i++) {
        final a0 = (i / radialSegments) * math.pi * 2.0;
        final a1 = ((i + 1) / radialSegments) * math.pi * 2.0;
        final am = (a0 + a1) * 0.5;

        // Note: in Three.js CylinderGeometry, theta goes sin(theta) on X, cos(theta) on Z
        final s0 = math.sin(a0), c0 = math.cos(a0);
        final s1 = math.sin(a1), c1 = math.cos(a1);
        final sm = math.sin(am), cm = math.cos(am);

        final n = xformN(sm, slopeY, cm);
        final col = shadeColor(
          hexColor,
          n.x,
          n.y,
          n.z,
          unlit: unlit,
          scalar: scalar,
        );

        final pBot0 = xform(s0 * radiusBottom, -halfH, c0 * radiusBottom);
        final pBot1 = xform(s1 * radiusBottom, -halfH, c1 * radiusBottom);
        final pTop1 = xform(s1 * radiusTop, halfH, c1 * radiusTop);
        final pTop0 = xform(s0 * radiusTop, halfH, c0 * radiusTop);

        final i0 = addVertex(pBot0.x, pBot0.y, pBot0.z, n.x, n.y, n.z, col);
        final i1 = addVertex(pBot1.x, pBot1.y, pBot1.z, n.x, n.y, n.z, col);
        final i2 = addVertex(pTop1.x, pTop1.y, pTop1.z, n.x, n.y, n.z, col);
        final i3 = addVertex(pTop0.x, pTop0.y, pTop0.z, n.x, n.y, n.z, col);

        if (radiusTop <= 1e-5) {
          addTriangle(i0, i1, i2, flipWinding: flipWinding);
        } else {
          addQuad(i0, i1, i2, i3, flipWinding: flipWinding);
        }
      }
    } else {
      final topRow = <int>[];
      final botRow = <int>[];
      for (int i = 0; i <= radialSegments; i++) {
        final a = (i / radialSegments) * math.pi * 2.0;
        final s = math.sin(a), c = math.cos(a);
        final n = xformN(s, slopeY, c);
        final col = shadeColor(
          hexColor,
          n.x,
          n.y,
          n.z,
          unlit: unlit,
          scalar: scalar,
        );
        final pTop = xform(s * radiusTop, halfH, c * radiusTop);
        final pBot = xform(s * radiusBottom, -halfH, c * radiusBottom);
        topRow.add(addVertex(pTop.x, pTop.y, pTop.z, n.x, n.y, n.z, col));
        botRow.add(addVertex(pBot.x, pBot.y, pBot.z, n.x, n.y, n.z, col));
      }
      for (int i = 0; i < radialSegments; i++) {
        addQuad(
          botRow[i],
          botRow[i + 1],
          topRow[i + 1],
          topRow[i],
          flipWinding: flipWinding,
        );
      }
    }

    // Top cap
    if (radiusTop > 1e-5) {
      final nTop = xformN(0, 1, 0);
      final cTop = shadeColor(
        hexColor,
        nTop.x,
        nTop.y,
        nTop.z,
        unlit: unlit,
        scalar: scalar,
      );
      final center = xform(0, halfH, 0);
      final cIdx =
          addVertex(center.x, center.y, center.z, nTop.x, nTop.y, nTop.z, cTop);
      final start = vertexCount;
      for (int i = 0; i < radialSegments; i++) {
        final a = (i / radialSegments) * math.pi * 2.0;
        final p = xform(math.sin(a) * radiusTop, halfH, math.cos(a) * radiusTop);
        addVertex(p.x, p.y, p.z, nTop.x, nTop.y, nTop.z, cTop);
      }
      for (int i = 0; i < radialSegments; i++) {
        addTriangle(
          cIdx,
          start + i,
          start + (i + 1) % radialSegments,
          flipWinding: flipWinding,
        );
      }
    }

    // Bottom cap
    if (radiusBottom > 1e-5) {
      final nBot = xformN(0, -1, 0);
      final cBot = shadeColor(
        hexColor,
        nBot.x,
        nBot.y,
        nBot.z,
        unlit: unlit,
        scalar: scalar,
      );
      final center = xform(0, -halfH, 0);
      final cIdx =
          addVertex(center.x, center.y, center.z, nBot.x, nBot.y, nBot.z, cBot);
      final start = vertexCount;
      for (int i = 0; i < radialSegments; i++) {
        final a = (i / radialSegments) * math.pi * 2.0;
        final p = xform(
            math.sin(a) * radiusBottom, -halfH, math.cos(a) * radiusBottom);
        addVertex(p.x, p.y, p.z, nBot.x, nBot.y, nBot.z, cBot);
      }
      for (int i = 0; i < radialSegments; i++) {
        addTriangle(
          cIdx,
          start + (i + 1) % radialSegments,
          start + i,
          flipWinding: flipWinding,
        );
      }
    }
  }

  /// Adds a closed 3D tube along a 2D XZ loop at height y
  void addPerimeterTube({
    required List<({double x, double z})> loop,
    required double y,
    required double radius,
    required int hexColor,
    int tubeSegments = 6,
    int stepStride = 2,
  }) {
    final pts = <({double x, double z})>[];
    for (int i = 0; i < loop.length; i += stepStride) {
      pts.add(loop[i]);
    }
    final m = pts.length;
    if (m < 3) return;

    final ringStarts = <int>[];
    for (int i = 0; i < m; i++) {
      final prev = pts[(i - 1 + m) % m];
      final curr = pts[i];
      final next = pts[(i + 1) % m];
      final tx = next.x - prev.x;
      final tz = next.z - prev.z;
      final tl = math.max(1e-6, TrafficMath.hypot(tx, tz));
      // Outward normal in XZ perpendicular to tangent
      final rx = -tz / tl;
      final rz = tx / tl;

      final start = vertexCount;
      ringStarts.add(start);
      for (int j = 0; j < tubeSegments; j++) {
        final a = (j / tubeSegments) * math.pi * 2.0;
        final ca = math.cos(a);
        final sa = math.sin(a);
        final nx = rx * ca;
        final ny = sa;
        final nz = rz * ca;
        final vx = curr.x + nx * radius;
        final vy = y + ny * radius;
        final vz = curr.z + nz * radius;
        final col = shadeColor(hexColor, nx, ny, nz);
        addVertex(vx, vy, vz, nx, ny, nz, col);
      }
    }

    for (int i = 0; i < m; i++) {
      final s0 = ringStarts[i];
      final s1 = ringStarts[(i + 1) % m];
      for (int j = 0; j < tubeSegments; j++) {
        final nextJ = (j + 1) % tubeSegments;
        addQuad(s0 + j, s1 + j, s1 + nextJ, s0 + nextJ);
      }
    }
  }

  /// Adds a soft radial gradient disc in XZ (for island, planter, and car shadows)
  void addSoftDiscShadow({
    required double x,
    required double y,
    required double z,
    required double radiusX,
    required double radiusZ,
    required int hexColor,
    required double centerAlpha,
    int rings = 2,
    int segments = 12,
  }) {
    final cCenter =
        shadeColor(hexColor, 0, 1, 0, unlit: true, alpha: centerAlpha);
    final centerIdx = addVertex(x, y, z, 0, 1, 0, cCenter);

    final ringStarts = <int>[];
    for (int r = 1; r <= rings; r++) {
      final frac = r / rings;
      final alpha =
          r == rings ? 0.0 : math.pow(1.0 - frac, 1.5).toDouble() * centerAlpha;
      final col = shadeColor(hexColor, 0, 1, 0, unlit: true, alpha: alpha);
      final start = vertexCount;
      ringStarts.add(start);
      for (int s = 0; s < segments; s++) {
        final a = (s / segments) * math.pi * 2.0;
        final px = x + math.sin(a) * radiusX * frac;
        final pz = z + math.cos(a) * radiusZ * frac;
        addVertex(px, y, pz, 0, 1, 0, col);
      }
    }

    // Inner fan
    final firstRing = ringStarts.first;
    for (int s = 0; s < segments; s++) {
      addTriangle(centerIdx, firstRing + s, firstRing + (s + 1) % segments);
    }

    // Outer rings
    for (int r = 0; r < rings - 1; r++) {
      final s0 = ringStarts[r];
      final s1 = ringStarts[r + 1];
      for (int s = 0; s < segments; s++) {
        final nextS = (s + 1) % segments;
        addQuad(s0 + s, s1 + s, s1 + nextS, s0 + nextS);
      }
    }
  }

  MeshPrimitive build({
    bool doubleSided = false,
    AlphaMode alphaMode = AlphaMode.opaque,
    int depthLayer = 0,
    Vector4? baseColorFactor,
  }) {
    final geometry = MeshGeometry.fromArrays(
      positions: Float32List.fromList(_positions),
      normals: Float32List.fromList(_normals),
      colors: Float32List.fromList(_colors),
      texCoords: Float32List.fromList(_uvs),
      indices: Uint32List.fromList(_indices),
    );
    final material = UnlitMaterial()
      ..vertexColorWeight = 1.0
      ..doubleSided = doubleSided
      ..alphaMode = alphaMode
      ..depthLayer = depthLayer;
    if (baseColorFactor != null) {
      material.baseColorFactor = baseColorFactor;
    }
    return MeshPrimitive(geometry, material);
  }
}
