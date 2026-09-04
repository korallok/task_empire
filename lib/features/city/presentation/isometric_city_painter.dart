import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:task_empire/features/city/domain/city_building.dart';
import 'package:task_empire/features/city/presentation/city_building_art.dart';
import 'package:task_empire/features/city/presentation/isometric_projection.dart';

class IsometricCityPainter extends CustomPainter {
  const IsometricCityPainter({
    required this.projection,
    required this.buildings,
    required this.buildingSprites,
    required this.colorScheme,
    this.selectedTile,
  });

  final IsometricProjection projection;
  final List<CityBuilding> buildings;
  final Map<String, ui.Image> buildingSprites;
  final ColorScheme colorScheme;
  final CityTileCoordinate? selectedTile;

  @override
  void paint(Canvas canvas, Size size) {
    _drawTerrain(canvas);

    final orderedBuildings = [...buildings]..sort(_compareDepth);
    for (final building in orderedBuildings) {
      final anchor = projection.tileCenter(building.tile.x, building.tile.y);
      final artSpec = CityBuildingArt.forBuilding(building);
      final sprite = buildingSprites[artSpec.key];
      if (sprite != null) {
        _drawBuildingSprite(canvas, anchor, sprite, artSpec);
        continue;
      }

      _drawBuildingShadow(canvas, anchor, building);
      switch (building.type) {
        case CityBuildingType.townHall:
          _drawTownHall(canvas, anchor, building.level);
        case CityBuildingType.market:
          _drawMarket(canvas, anchor, building.level);
      }
    }
  }

  void _drawBuildingSprite(
    Canvas canvas,
    Offset anchor,
    ui.Image image,
    CityBuildingArtSpec artSpec,
  ) {
    final width = projection.tileWidth * artSpec.renderWidthInTiles;
    final destination = Rect.fromLTWH(
      anchor.dx - width * artSpec.pivot.dx,
      anchor.dy - width * artSpec.pivot.dy,
      width,
      width,
    );
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      destination,
      Paint()
        ..isAntiAlias = true
        ..filterQuality = FilterQuality.high,
    );
  }

  static CityBuilding? buildingAt({
    required Offset position,
    required List<CityBuilding> buildings,
    required IsometricProjection projection,
  }) {
    final ordered = [...buildings]..sort(_compareDepth);
    for (final building in ordered.reversed) {
      if (_buildingHitPath(building, projection).contains(position)) {
        return building;
      }
    }
    return null;
  }

  static int _compareDepth(CityBuilding left, CityBuilding right) {
    final depth = (left.tile.x + left.tile.y).compareTo(
      right.tile.x + right.tile.y,
    );
    return depth != 0 ? depth : left.tile.x.compareTo(right.tile.x);
  }

  static Path _buildingHitPath(
    CityBuilding building,
    IsometricProjection projection,
  ) {
    final anchor = projection.tileCenter(building.tile.x, building.tile.y);
    final width = projection.tileWidth;
    final height = projection.tileHeight;
    final levelScale = 1 + math.min(building.level - 1, 5) * 0.055;

    return switch (building.type) {
      CityBuildingType.townHall =>
        Path()
          ..moveTo(anchor.dx, anchor.dy - width * 1.12 * levelScale)
          ..lineTo(
            anchor.dx + width * 0.38 * levelScale,
            anchor.dy - width * 0.35,
          )
          ..lineTo(anchor.dx + width * 0.34, anchor.dy + height * 0.5)
          ..lineTo(anchor.dx - width * 0.34, anchor.dy + height * 0.5)
          ..lineTo(
            anchor.dx - width * 0.38 * levelScale,
            anchor.dy - width * 0.35,
          )
          ..close(),
      CityBuildingType.market =>
        Path()
          ..moveTo(anchor.dx, anchor.dy - width * 0.68 * levelScale)
          ..lineTo(anchor.dx + width * 0.4, anchor.dy - width * 0.27)
          ..lineTo(anchor.dx + width * 0.35, anchor.dy + height * 0.45)
          ..lineTo(anchor.dx - width * 0.35, anchor.dy + height * 0.45)
          ..lineTo(anchor.dx - width * 0.4, anchor.dy - width * 0.27)
          ..close(),
    };
  }

  void _drawTerrain(Canvas canvas) {
    const lightGrass = Color(0xFF91C96B);
    const darkGrass = Color(0xFF73AD54);
    const gridLine = Color(0x66507A3B);

    for (var sum = 0; sum <= (projection.gridSize - 1) * 2; sum++) {
      for (var x = 0; x < projection.gridSize; x++) {
        final y = sum - x;
        if (y < 0 || y >= projection.gridSize) continue;

        final path = projection.tilePath(x, y, inset: 0.6);
        final isSelected = selectedTile?.x == x && selectedTile?.y == y;
        final primary = (x + y).isEven ? lightGrass : darkGrass;
        final secondary = Color.lerp(primary, Colors.white, 0.12)!;
        final paint = Paint()
          ..isAntiAlias = true
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isSelected
                ? [colorScheme.secondaryContainer, colorScheme.secondary]
                : [secondary, primary],
          ).createShader(path.getBounds());

        canvas.drawPath(path, paint);
        canvas.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = isSelected ? 2.2 : 0.8
            ..color = isSelected ? colorScheme.onSecondaryContainer : gridLine,
        );
      }
    }
  }

  void _drawBuildingShadow(
    Canvas canvas,
    Offset anchor,
    CityBuilding building,
  ) {
    final widthFactor = building.type == CityBuildingType.townHall
        ? 0.72
        : 0.78;
    final path = Path()
      ..addOval(
        Rect.fromCenter(
          center:
              anchor +
              Offset(projection.tileWidth * 0.08, projection.tileHeight * 0.26),
          width: projection.tileWidth * widthFactor,
          height: projection.tileHeight * 0.72,
        ),
      );
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0x440D2B16)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
  }

  void _drawTownHall(Canvas canvas, Offset anchor, int level) {
    final width = projection.tileWidth;
    final height = projection.tileHeight;
    final scale = 1 + math.min(level - 1, 5) * 0.055;
    final baseCenter = anchor + Offset(0, height * 0.2);
    final halfWidth = width * 0.29 * scale;
    final halfDepth = height * 0.38 * scale;
    final wallHeight = width * 0.34 * scale;
    final topCenter = baseCenter - Offset(0, wallHeight);

    final top = topCenter - Offset(0, halfDepth);
    final right = topCenter + Offset(halfWidth, 0);
    final front = topCenter + Offset(0, halfDepth);
    final left = topCenter - Offset(halfWidth, 0);
    final bottomRight = right + Offset(0, wallHeight);
    final bottomFront = front + Offset(0, wallHeight);
    final bottomLeft = left + Offset(0, wallHeight);

    final leftWall = Path()
      ..moveTo(left.dx, left.dy)
      ..lineTo(front.dx, front.dy)
      ..lineTo(bottomFront.dx, bottomFront.dy)
      ..lineTo(bottomLeft.dx, bottomLeft.dy)
      ..close();
    final rightWall = Path()
      ..moveTo(front.dx, front.dy)
      ..lineTo(right.dx, right.dy)
      ..lineTo(bottomRight.dx, bottomRight.dy)
      ..lineTo(bottomFront.dx, bottomFront.dy)
      ..close();
    final topFace = Path()
      ..moveTo(top.dx, top.dy)
      ..lineTo(right.dx, right.dy)
      ..lineTo(front.dx, front.dy)
      ..lineTo(left.dx, left.dy)
      ..close();

    _drawGradientPath(canvas, leftWall, const [
      Color(0xFFE0B778),
      Color(0xFFB9793F),
    ]);
    _drawGradientPath(canvas, rightWall, const [
      Color(0xFFB97843),
      Color(0xFF754226),
    ]);
    _drawGradientPath(canvas, topFace, const [
      Color(0xFFFFE0A1),
      Color(0xFFCA9551),
    ]);

    _drawTownHallMasonry(
      canvas,
      left: left,
      front: front,
      right: right,
      bottomLeft: bottomLeft,
      bottomFront: bottomFront,
      bottomRight: bottomRight,
      wallHeight: wallHeight,
    );
    _drawTownHallOpenings(
      canvas,
      front: front,
      right: right,
      bottomFront: bottomFront,
      wallHeight: wallHeight,
      halfWidth: halfWidth,
    );

    final roofCenter = topCenter - Offset(0, halfDepth * 0.18);
    final roofRadiusX = halfWidth * 1.2;
    final roofRadiusY = halfDepth * 0.75;
    final apex = roofCenter - Offset(0, width * 0.36 * scale);
    final roofLeft = roofCenter - Offset(roofRadiusX, 0);
    final roofRight = roofCenter + Offset(roofRadiusX, 0);
    final roofBottom = roofCenter + Offset(0, roofRadiusY);

    final roofLeftFace = Path()
      ..moveTo(apex.dx, apex.dy)
      ..lineTo(roofBottom.dx, roofBottom.dy)
      ..quadraticBezierTo(
        roofCenter.dx - roofRadiusX * 0.62,
        roofCenter.dy + roofRadiusY * 0.72,
        roofLeft.dx,
        roofLeft.dy,
      )
      ..close();
    final roofRightFace = Path()
      ..moveTo(apex.dx, apex.dy)
      ..lineTo(roofRight.dx, roofRight.dy)
      ..quadraticBezierTo(
        roofCenter.dx + roofRadiusX * 0.62,
        roofCenter.dy + roofRadiusY * 0.72,
        roofBottom.dx,
        roofBottom.dy,
      )
      ..close();

    _drawGradientPath(canvas, roofLeftFace, const [
      Color(0xFFF06A45),
      Color(0xFFB72D2D),
    ]);
    _drawGradientPath(canvas, roofRightFace, const [
      Color(0xFFBE3432),
      Color(0xFF761E27),
    ]);
    canvas.drawPath(
      Path()..addOval(
        Rect.fromCenter(
          center: roofCenter,
          width: roofRadiusX * 2,
          height: roofRadiusY * 0.62,
        ),
      ),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.0, width * 0.025)
        ..color = const Color(0xAA72212A),
    );

    if (level >= 2) {
      _drawTownHallFlag(canvas, apex, width, scale, level);
    }
  }

  void _drawTownHallMasonry(
    Canvas canvas, {
    required Offset left,
    required Offset front,
    required Offset right,
    required Offset bottomLeft,
    required Offset bottomFront,
    required Offset bottomRight,
    required double wallHeight,
  }) {
    final mortarPaint = Paint()
      ..color = const Color(0x4471432C)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;

    for (final fraction in [0.33, 0.66]) {
      canvas.drawLine(
        Offset.lerp(left, bottomLeft, fraction)!,
        Offset.lerp(front, bottomFront, fraction)!,
        mortarPaint,
      );
      canvas.drawLine(
        Offset.lerp(front, bottomFront, fraction)!,
        Offset.lerp(right, bottomRight, fraction)!,
        mortarPaint,
      );
    }

    final shortStroke = wallHeight * 0.12;
    for (final fraction in [0.25, 0.55, 0.82]) {
      final leftPoint = Offset.lerp(left, bottomLeft, fraction)!;
      final rightPoint = Offset.lerp(right, bottomRight, fraction)!;
      canvas.drawLine(
        leftPoint,
        leftPoint + Offset(shortStroke, shortStroke * 0.45),
        mortarPaint,
      );
      canvas.drawLine(
        rightPoint,
        rightPoint - Offset(shortStroke, -shortStroke * 0.45),
        mortarPaint,
      );
    }
  }

  void _drawTownHallOpenings(
    Canvas canvas, {
    required Offset front,
    required Offset right,
    required Offset bottomFront,
    required double wallHeight,
    required double halfWidth,
  }) {
    final doorTop = Offset.lerp(front, bottomFront, 0.48)!;
    final doorBottom = bottomFront - Offset(0, wallHeight * 0.03);
    final door = Path()
      ..moveTo(doorTop.dx, doorTop.dy)
      ..lineTo(doorTop.dx + halfWidth * 0.32, doorTop.dy - halfWidth * 0.16)
      ..lineTo(
        doorBottom.dx + halfWidth * 0.32,
        doorBottom.dy - halfWidth * 0.16,
      )
      ..lineTo(doorBottom.dx, doorBottom.dy)
      ..close();
    _drawGradientPath(canvas, door, const [
      Color(0xFF5B382B),
      Color(0xFF281C1A),
    ]);

    final windowCenter =
        Offset.lerp(right, front, 0.42)! + Offset(0, wallHeight * 0.42);
    final window = Path()
      ..moveTo(windowCenter.dx, windowCenter.dy - halfWidth * 0.12)
      ..lineTo(windowCenter.dx + halfWidth * 0.22, windowCenter.dy)
      ..lineTo(
        windowCenter.dx + halfWidth * 0.22,
        windowCenter.dy + halfWidth * 0.22,
      )
      ..lineTo(windowCenter.dx, windowCenter.dy + halfWidth * 0.1)
      ..close();
    _drawGradientPath(canvas, window, const [
      Color(0xFFB9F2FF),
      Color(0xFF357F9C),
    ]);
  }

  void _drawTownHallFlag(
    Canvas canvas,
    Offset apex,
    double width,
    double scale,
    int level,
  ) {
    final poleTop = apex - Offset(0, width * 0.35 * scale);
    canvas.drawLine(
      apex + Offset(0, width * 0.03),
      poleTop,
      Paint()
        ..strokeWidth = math.max(1.5, width * 0.028)
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFF4D3524),
    );

    final flagWidth = width * 0.3 * scale;
    final flagHeight = width * 0.16 * scale;
    final flag = Path()
      ..moveTo(poleTop.dx, poleTop.dy + flagHeight * 0.12)
      ..quadraticBezierTo(
        poleTop.dx + flagWidth * 0.5,
        poleTop.dy - flagHeight * 0.08,
        poleTop.dx + flagWidth,
        poleTop.dy + flagHeight * 0.25,
      )
      ..lineTo(poleTop.dx + flagWidth * 0.78, poleTop.dy + flagHeight)
      ..quadraticBezierTo(
        poleTop.dx + flagWidth * 0.35,
        poleTop.dy + flagHeight * 0.72,
        poleTop.dx,
        poleTop.dy + flagHeight * 0.9,
      )
      ..close();
    _drawGradientPath(
      canvas,
      flag,
      level >= 4
          ? const [Color(0xFFFFD65A), Color(0xFFC37B16)]
          : const [Color(0xFF59A9FF), Color(0xFF225AB5)],
    );
  }

  void _drawMarket(Canvas canvas, Offset anchor, int level) {
    final width = projection.tileWidth;
    final height = projection.tileHeight;
    final scale = 1 + math.min(level - 1, 5) * 0.045;
    final halfWidth = width * 0.34 * scale;
    final floorCenter = anchor + Offset(0, height * 0.2);
    final counterTopY = floorCenter.dy - width * 0.15 * scale;

    final counterTop = Path()
      ..moveTo(floorCenter.dx, counterTopY - height * 0.22)
      ..lineTo(floorCenter.dx + halfWidth * 0.82, counterTopY)
      ..lineTo(floorCenter.dx, counterTopY + height * 0.24)
      ..lineTo(floorCenter.dx - halfWidth * 0.82, counterTopY)
      ..close();
    final counterFront = Path()
      ..moveTo(floorCenter.dx - halfWidth * 0.82, counterTopY)
      ..lineTo(floorCenter.dx, counterTopY + height * 0.24)
      ..lineTo(floorCenter.dx, floorCenter.dy + height * 0.26)
      ..lineTo(floorCenter.dx - halfWidth * 0.82, floorCenter.dy)
      ..close();
    final counterRight = Path()
      ..moveTo(floorCenter.dx, counterTopY + height * 0.24)
      ..lineTo(floorCenter.dx + halfWidth * 0.82, counterTopY)
      ..lineTo(floorCenter.dx + halfWidth * 0.82, floorCenter.dy)
      ..lineTo(floorCenter.dx, floorCenter.dy + height * 0.26)
      ..close();

    _drawGradientPath(canvas, counterFront, const [
      Color(0xFFC88745),
      Color(0xFF85502C),
    ]);
    _drawGradientPath(canvas, counterRight, const [
      Color(0xFF96613A),
      Color(0xFF59351F),
    ]);
    _drawGradientPath(canvas, counterTop, const [
      Color(0xFFEABF75),
      Color(0xFFA66C35),
    ]);

    final canopyLeft = Offset(
      floorCenter.dx - halfWidth * 1.15,
      floorCenter.dy - width * 0.35 * scale,
    );
    final canopyRight = Offset(
      floorCenter.dx + halfWidth * 1.15,
      floorCenter.dy - width * 0.35 * scale,
    );
    final canopyApex = Offset(
      floorCenter.dx,
      floorCenter.dy - width * 0.68 * scale,
    );

    final polePaint = Paint()
      ..color = const Color(0xFF57412B)
      ..strokeWidth = math.max(1.5, width * 0.025)
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      canopyLeft,
      floorCenter - Offset(halfWidth * 0.82, 0),
      polePaint,
    );
    canvas.drawLine(
      canopyRight,
      floorCenter + Offset(halfWidth * 0.82, 0),
      polePaint,
    );

    final canopy = Path()
      ..moveTo(canopyApex.dx, canopyApex.dy)
      ..lineTo(canopyRight.dx, canopyRight.dy)
      ..quadraticBezierTo(
        floorCenter.dx,
        canopyRight.dy + height * 0.28,
        canopyLeft.dx,
        canopyLeft.dy,
      )
      ..close();
    canvas.drawPath(canopy, Paint()..color = const Color(0xFFF9E6B7));

    canvas.save();
    canvas.clipPath(canopy);
    const stripeCount = 7;
    for (var index = 0; index < stripeCount; index++) {
      final start = Offset.lerp(canopyLeft, canopyRight, index / stripeCount)!;
      final end = Offset.lerp(
        canopyLeft,
        canopyRight,
        (index + 1) / stripeCount,
      )!;
      final stripe = Path()
        ..moveTo(canopyApex.dx, canopyApex.dy)
        ..lineTo(end.dx, end.dy + height * 0.25)
        ..lineTo(start.dx, start.dy + height * 0.25)
        ..close();
      canvas.drawPath(
        stripe,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: index.isEven
                ? const [Color(0xFFE9564F), Color(0xFF9D292C)]
                : const [Color(0xFFFFF1CB), Color(0xFFE1C78C)],
          ).createShader(stripe.getBounds()),
      );
    }
    canvas.restore();
    canvas.drawPath(
      canopy,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.0, width * 0.018)
        ..color = const Color(0xFF7C3030),
    );

    _drawMarketValance(canvas, canopyLeft, canopyRight, width, height);
    _drawMarketGoods(canvas, floorCenter, halfWidth, width, level);
  }

  void _drawMarketValance(
    Canvas canvas,
    Offset left,
    Offset right,
    double width,
    double height,
  ) {
    const segments = 7;
    for (var index = 0; index < segments; index++) {
      final start = Offset.lerp(left, right, index / segments)!;
      final end = Offset.lerp(left, right, (index + 1) / segments)!;
      final drop = height * (index.isEven ? 0.24 : 0.2);
      final segment = Path()
        ..moveTo(start.dx, start.dy)
        ..lineTo(end.dx, end.dy)
        ..lineTo(end.dx, end.dy + drop)
        ..lineTo(start.dx, start.dy + drop)
        ..close();
      canvas.drawPath(
        segment,
        Paint()
          ..color = index.isEven
              ? const Color(0xFFB93335)
              : const Color(0xFFF3DCA8),
      );
    }

    canvas.drawLine(
      left,
      right,
      Paint()
        ..color = const Color(0x9968282A)
        ..strokeWidth = math.max(0.8, width * 0.014),
    );
  }

  void _drawMarketGoods(
    Canvas canvas,
    Offset floorCenter,
    double halfWidth,
    double width,
    int level,
  ) {
    final fruitPaint = Paint()..color = const Color(0xFFF3B52B);
    final fruitRadius = math.max(1.2, width * 0.035);
    for (var index = 0; index < math.min(3 + level, 7); index++) {
      final row = index ~/ 4;
      final column = index % 4;
      canvas.drawCircle(
        floorCenter +
            Offset(
              -halfWidth * 0.45 + column * fruitRadius * 1.7,
              -width * 0.13 - row * fruitRadius * 1.3,
            ),
        fruitRadius,
        fruitPaint,
      );
    }

    if (level >= 2) {
      final signCenter = floorCenter + Offset(halfWidth * 0.74, -width * 0.22);
      final sign = Path()
        ..moveTo(signCenter.dx, signCenter.dy - width * 0.09)
        ..lineTo(signCenter.dx + width * 0.18, signCenter.dy - width * 0.03)
        ..lineTo(signCenter.dx + width * 0.18, signCenter.dy + width * 0.09)
        ..lineTo(signCenter.dx, signCenter.dy + width * 0.03)
        ..close();
      _drawGradientPath(canvas, sign, const [
        Color(0xFF67A9E7),
        Color(0xFF245A9A),
      ]);
    }
  }

  void _drawGradientPath(Canvas canvas, Path path, List<Color> colors) {
    canvas.drawPath(
      path,
      Paint()
        ..isAntiAlias = true
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ).createShader(path.getBounds()),
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(0.7, projection.tileWidth * 0.012)
        ..color = colors.last.withValues(alpha: 0.58),
    );
  }

  @override
  bool shouldRepaint(covariant IsometricCityPainter oldDelegate) {
    return oldDelegate.projection.tileWidth != projection.tileWidth ||
        oldDelegate.projection.tileHeight != projection.tileHeight ||
        oldDelegate.projection.origin != projection.origin ||
        oldDelegate.projection.gridSize != projection.gridSize ||
        oldDelegate.colorScheme != colorScheme ||
        oldDelegate.selectedTile != selectedTile ||
        !identical(oldDelegate.buildingSprites, buildingSprites) ||
        !listEquals(oldDelegate.buildings, buildings);
  }
}
