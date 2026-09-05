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
    this.preview,
    this.selectedBuildingId,
    this.selectedTile,
    this.showGrid = false,
  });

  final IsometricProjection projection;
  final List<CityBuilding> buildings;
  final Map<String, ui.Image> buildingSprites;
  final ColorScheme colorScheme;
  final CityPlacementPreview? preview;
  final String? selectedBuildingId;
  final CityTileCoordinate? selectedTile;
  final bool showGrid;

  @override
  void paint(Canvas canvas, Size size) {
    _drawMapShadow(canvas);
    _drawTerrain(canvas);

    final movingBuildingId = preview?.movingBuildingId;
    final orderedBuildings =
        buildings.where((building) => building.id != movingBuildingId).toList()
          ..sort(compareDepth);
    for (final building in orderedBuildings) {
      _drawBuilding(
        canvas,
        building.definition,
        building.footprint,
        selected: building.id == selectedBuildingId,
      );
    }

    final activePreview = preview;
    if (activePreview != null) {
      _drawBuilding(
        canvas,
        activePreview.definition,
        activePreview.footprint,
        ghostColor: activePreview.validation.isValid
            ? const Color(0xFF2FA866)
            : const Color(0xFFD84B47),
      );
    }
  }

  void _drawMapShadow(Canvas canvas) {
    final outline = _mapOutline();
    canvas.drawPath(
      outline.shift(Offset(0, projection.tileHeight * 0.32)),
      Paint()
        ..color = const Color(0x330E2924)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18),
    );
    canvas.drawPath(outline, Paint()..color = const Color(0xFF6B9E52));
  }

  Path _mapOutline() {
    final top =
        projection.tileCenter(0, 0) - Offset(0, projection.tileHeight / 2);
    final right =
        projection.tileCenter(projection.width - 1, 0) +
        Offset(projection.tileWidth / 2, 0);
    final bottom =
        projection.tileCenter(projection.width - 1, projection.height - 1) +
        Offset(0, projection.tileHeight / 2);
    final left =
        projection.tileCenter(0, projection.height - 1) -
        Offset(projection.tileWidth / 2, 0);
    return Path()
      ..moveTo(top.dx, top.dy)
      ..lineTo(right.dx, right.dy)
      ..lineTo(bottom.dx, bottom.dy)
      ..lineTo(left.dx, left.dy)
      ..close();
  }

  void _drawTerrain(Canvas canvas) {
    const lightGrass = Color(0xFF9ACB72);
    const darkGrass = Color(0xFF83B963);
    const gridLine = Color(0x3D315D36);
    final selectedBuilding = selectedBuildingId == null
        ? null
        : buildings
              .where((building) => building.id == selectedBuildingId)
              .firstOrNull;

    for (
      var depth = 0;
      depth <= projection.width + projection.height - 2;
      depth++
    ) {
      for (var x = 0; x < projection.width; x++) {
        final y = depth - x;
        if (y < 0 || y >= projection.height) continue;

        final tile = CityTileCoordinate(x, y);
        final path = projection.tilePath(x, y, inset: 0.45);
        final inPreview = preview?.footprint.contains(tile) ?? false;
        final inSelectedBuilding =
            selectedBuilding?.footprint.contains(tile) ?? false;
        final isSelectedTile = selectedTile == tile;
        final base = (x + y).isEven ? lightGrass : darkGrass;
        final colors = inPreview
            ? preview!.validation.isValid
                  ? const [Color(0xFF92E3AE), Color(0xFF46B875)]
                  : const [Color(0xFFFFA09B), Color(0xFFD95751)]
            : inSelectedBuilding || isSelectedTile
            ? const [Color(0xFFFFE99B), Color(0xFFE4B94E)]
            : [Color.lerp(base, Colors.white, 0.10)!, base];
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
        if (showGrid || inPreview || inSelectedBuilding || isSelectedTile) {
          canvas.drawPath(
            path,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = inPreview ? 2.1 : 0.75
              ..color = inPreview
                  ? preview!.validation.isValid
                        ? const Color(0xFF167A45)
                        : const Color(0xFFAA2528)
                  : gridLine,
          );
        }
      }
    }
  }

  void _drawBuilding(
    Canvas canvas,
    BuildingDefinition definition,
    CityFootprint footprint, {
    bool selected = false,
    Color? ghostColor,
  }) {
    final anchor = projection.footprintCenter(footprint);
    final artSpec = CityBuildingArt.forDefinition(definition);
    final sprite = buildingSprites[artSpec.key];
    _drawBuildingShadow(canvas, anchor, footprint, color: ghostColor);
    if (sprite != null) {
      _drawBuildingSprite(canvas, anchor, sprite, artSpec, tint: ghostColor);
    } else {
      _drawFallbackBuilding(
        canvas,
        anchor,
        definition,
        footprint,
        tint: ghostColor,
      );
    }

    if (selected) {
      final bounds = _buildingHitPath(
        definition: definition,
        footprint: footprint,
        projection: projection,
      ).getBounds();
      canvas.drawRRect(
        RRect.fromRectAndRadius(bounds.inflate(5), const Radius.circular(14)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = const Color(0xFFF0BD5B),
      );
    }
  }

  void _drawBuildingSprite(
    Canvas canvas,
    Offset anchor,
    ui.Image image,
    CityBuildingArtSpec artSpec, {
    Color? tint,
  }) {
    final width = projection.tileWidth * artSpec.renderWidthInTiles;
    final destination = Rect.fromLTWH(
      anchor.dx - width * artSpec.pivot.dx,
      anchor.dy - width * artSpec.pivot.dy,
      width,
      width,
    );
    final paint = Paint()
      ..isAntiAlias = true
      ..filterQuality = FilterQuality.high;
    if (tint != null) {
      paint
        ..color = Colors.white.withValues(alpha: 0.66)
        ..colorFilter = ColorFilter.mode(
          tint.withValues(alpha: 0.72),
          BlendMode.modulate,
        );
    }
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      destination,
      paint,
    );
  }

  void _drawBuildingShadow(
    Canvas canvas,
    Offset anchor,
    CityFootprint footprint, {
    Color? color,
  }) {
    final footprintSpan = footprint.size.width + footprint.size.height;
    canvas.drawOval(
      Rect.fromCenter(
        center: anchor + Offset(0, projection.tileHeight * 0.34),
        width: projection.tileWidth * footprintSpan * 0.38,
        height: projection.tileHeight * footprintSpan * 0.27,
      ),
      Paint()
        ..color = (color ?? const Color(0xFF0D2B16)).withValues(alpha: 0.24)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );
  }

  void _drawFallbackBuilding(
    Canvas canvas,
    Offset anchor,
    BuildingDefinition definition,
    CityFootprint footprint, {
    Color? tint,
  }) {
    final visualCode = definition.visualCode;
    if (visualCode == 'garden') {
      _drawGarden(canvas, anchor, footprint, tint: tint);
      return;
    }

    final palette = _paletteFor(visualCode, tint);
    final span = footprint.size.width + footprint.size.height;
    final halfWidth = projection.tileWidth * span * 0.18;
    final halfDepth = projection.tileHeight * span * 0.17;
    final heightFactor = switch (visualCode) {
      'tower' => 1.18,
      'town_hall' => 0.92,
      'library' => 0.68,
      'workshop' => 0.58,
      'market' => 0.52,
      _ => 0.48,
    };
    final wallHeight = projection.tileWidth * heightFactor;
    final baseCenter = anchor + Offset(0, projection.tileHeight * 0.28);
    final topCenter = baseCenter - Offset(0, wallHeight);
    final left = topCenter - Offset(halfWidth, 0);
    final right = topCenter + Offset(halfWidth, 0);
    final front = topCenter + Offset(0, halfDepth);
    final back = topCenter - Offset(0, halfDepth);
    final bottomLeft = left + Offset(0, wallHeight);
    final bottomRight = right + Offset(0, wallHeight);
    final bottomFront = front + Offset(0, wallHeight);

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
    _fillPath(canvas, leftWall, palette.$2);
    _fillPath(canvas, rightWall, palette.$3);

    if (visualCode == 'market') {
      final canopy = Path()
        ..moveTo(back.dx, back.dy - halfDepth * 0.8)
        ..lineTo(right.dx + halfWidth * 0.18, right.dy)
        ..lineTo(front.dx, front.dy + halfDepth * 0.35)
        ..lineTo(left.dx - halfWidth * 0.18, left.dy)
        ..close();
      _fillPath(canvas, canopy, palette.$1);
      _drawCanopyStripes(canvas, canopy.getBounds(), tint);
    } else {
      final roofHeight = visualCode == 'tower'
          ? wallHeight * 0.42
          : wallHeight * 0.34;
      final apex = back - Offset(0, roofHeight);
      final roofLeft = Path()
        ..moveTo(apex.dx, apex.dy)
        ..lineTo(front.dx, front.dy)
        ..lineTo(left.dx - halfWidth * 0.12, left.dy)
        ..close();
      final roofRight = Path()
        ..moveTo(apex.dx, apex.dy)
        ..lineTo(right.dx + halfWidth * 0.12, right.dy)
        ..lineTo(front.dx, front.dy)
        ..close();
      _fillPath(canvas, roofLeft, palette.$1);
      _fillPath(canvas, roofRight, Color.lerp(palette.$1, Colors.black, 0.18)!);
      if (visualCode == 'town_hall' || visualCode == 'tower') {
        _drawFlag(canvas, apex, palette.$1, tint);
      }
    }

    _drawDoorAndWindows(
      canvas,
      front: front,
      bottomFront: bottomFront,
      halfWidth: halfWidth,
      wallHeight: wallHeight,
      code: visualCode,
      tint: tint,
    );
  }

  void _drawGarden(
    Canvas canvas,
    Offset anchor,
    CityFootprint footprint, {
    Color? tint,
  }) {
    final spread =
        projection.tileWidth *
        (footprint.size.width + footprint.size.height) *
        0.12;
    final ground = Path()
      ..addOval(
        Rect.fromCenter(
          center: anchor + Offset(0, projection.tileHeight * 0.15),
          width: spread * 2.3,
          height: spread,
        ),
      );
    _fillPath(
      canvas,
      ground,
      tint ?? const Color(0xFF5A9C4A),
      opacity: tint == null ? 1 : 0.62,
    );
    final treeColor = tint ?? const Color(0xFF2D7545);
    for (final offset in const [
      Offset(-0.52, 0.05),
      Offset(0.0, -0.22),
      Offset(0.5, 0.08),
      Offset(-0.08, 0.26),
    ]) {
      final center = anchor + Offset(offset.dx * spread, offset.dy * spread);
      canvas.drawLine(
        center + Offset(0, spread * 0.08),
        center + Offset(0, spread * 0.52),
        Paint()
          ..strokeWidth = math.max(2, projection.tileWidth * 0.045)
          ..color = const Color(
            0xFF765237,
          ).withValues(alpha: tint == null ? 1 : 0.55),
      );
      canvas.drawCircle(
        center,
        spread * 0.38,
        Paint()..color = treeColor.withValues(alpha: tint == null ? 1 : 0.62),
      );
      canvas.drawCircle(
        center - Offset(spread * 0.10, spread * 0.11),
        spread * 0.22,
        Paint()
          ..color = Color.lerp(
            treeColor,
            Colors.white,
            0.18,
          )!.withValues(alpha: tint == null ? 1 : 0.62),
      );
    }
  }

  void _drawCanopyStripes(Canvas canvas, Rect bounds, Color? tint) {
    final stripeColor = tint ?? const Color(0xFFF7E4B5);
    for (var index = 0; index < 5; index++) {
      if (index.isOdd) continue;
      canvas.drawRect(
        Rect.fromLTWH(
          bounds.left + bounds.width * index / 5,
          bounds.top + bounds.height * 0.35,
          bounds.width / 5,
          bounds.height * 0.25,
        ),
        Paint()
          ..color = stripeColor.withValues(alpha: tint == null ? 0.7 : 0.4),
      );
    }
  }

  void _drawFlag(Canvas canvas, Offset apex, Color color, Color? tint) {
    final poleHeight = projection.tileWidth * 0.34;
    final top = apex - Offset(0, poleHeight);
    canvas.drawLine(
      apex,
      top,
      Paint()
        ..strokeWidth = math.max(1.5, projection.tileWidth * 0.025)
        ..color = const Color(
          0xFF55412E,
        ).withValues(alpha: tint == null ? 1 : 0.6),
    );
    final flag = Path()
      ..moveTo(top.dx, top.dy)
      ..lineTo(top.dx + projection.tileWidth * 0.28, top.dy + 5)
      ..lineTo(top.dx, top.dy + projection.tileWidth * 0.13)
      ..close();
    _fillPath(canvas, flag, tint ?? color, opacity: tint == null ? 1 : 0.65);
  }

  void _drawDoorAndWindows(
    Canvas canvas, {
    required Offset front,
    required Offset bottomFront,
    required double halfWidth,
    required double wallHeight,
    required String code,
    required Color? tint,
  }) {
    final opacity = tint == null ? 1.0 : 0.48;
    final doorTop = Offset.lerp(front, bottomFront, 0.48)!;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(doorTop.dx, doorTop.dy + wallHeight * 0.22),
          width: halfWidth * 0.34,
          height: wallHeight * 0.43,
        ),
        const Radius.circular(3),
      ),
      Paint()..color = const Color(0xFF4D352B).withValues(alpha: opacity),
    );
    if (code == 'workshop') return;
    for (final side in [-1.0, 1.0]) {
      canvas.drawCircle(
        front + Offset(side * halfWidth * 0.42, wallHeight * 0.42),
        math.max(2.5, halfWidth * 0.09),
        Paint()..color = const Color(0xFFB9E8F2).withValues(alpha: opacity),
      );
    }
  }

  (Color, Color, Color) _paletteFor(String code, Color? tint) {
    if (tint != null) {
      return (
        Color.lerp(tint, Colors.white, 0.18)!.withValues(alpha: 0.70),
        tint.withValues(alpha: 0.62),
        Color.lerp(tint, Colors.black, 0.18)!.withValues(alpha: 0.62),
      );
    }
    return switch (code) {
      'town_hall' => const (
        Color(0xFFD95A43),
        Color(0xFFD7AA6A),
        Color(0xFFA66C3D),
      ),
      'house' => const (
        Color(0xFFB95043),
        Color(0xFFF0C887),
        Color(0xFFC58D54),
      ),
      'library' => const (
        Color(0xFF4E769B),
        Color(0xFFE2CEAA),
        Color(0xFFB49B72),
      ),
      'workshop' => const (
        Color(0xFF765C56),
        Color(0xFFB78358),
        Color(0xFF80563F),
      ),
      'market' => const (
        Color(0xFFCC4D4D),
        Color(0xFFE0B36B),
        Color(0xFFA46E3B),
      ),
      'tower' => const (
        Color(0xFF6E7083),
        Color(0xFFB9B5AA),
        Color(0xFF858078),
      ),
      _ => const (Color(0xFF4D7C6C), Color(0xFFD2BA86), Color(0xFF9A7A50)),
    };
  }

  void _fillPath(Canvas canvas, Path path, Color color, {double opacity = 1}) {
    canvas.drawPath(
      path,
      Paint()
        ..isAntiAlias = true
        ..color = color.withValues(alpha: color.a * opacity),
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(0.8, projection.tileWidth * 0.012)
        ..color = Color.lerp(
          color,
          Colors.black,
          0.28,
        )!.withValues(alpha: 0.58 * opacity),
    );
  }

  static CityBuilding? buildingAt({
    required Offset position,
    required List<CityBuilding> buildings,
    required IsometricProjection projection,
  }) {
    final ordered = [...buildings]..sort(compareDepth);
    final tile = projection.tileAt(position);
    for (final building in ordered.reversed) {
      if ((tile != null && building.footprint.contains(tile)) ||
          _buildingHitPath(
            definition: building.definition,
            footprint: building.footprint,
            projection: projection,
          ).contains(position)) {
        return building;
      }
    }
    return null;
  }

  static int compareDepth(CityBuilding left, CityBuilding right) {
    final leftBase = left.footprint;
    final rightBase = right.footprint;
    final depth = leftBase.depth.compareTo(rightBase.depth);
    if (depth != 0) return depth;
    final y = leftBase.baseY.compareTo(rightBase.baseY);
    if (y != 0) return y;
    final x = leftBase.baseX.compareTo(rightBase.baseX);
    if (x != 0) return x;
    return left.id.compareTo(right.id);
  }

  static Path _buildingHitPath({
    required BuildingDefinition definition,
    required CityFootprint footprint,
    required IsometricProjection projection,
  }) {
    final anchor = projection.footprintCenter(footprint);
    final span = footprint.size.width + footprint.size.height;
    final halfWidth = projection.tileWidth * span * 0.23;
    final heightFactor = switch (definition.visualCode) {
      'tower' => 1.65,
      'town_hall' => 1.35,
      'garden' => 0.48,
      _ => 1.0,
    };
    final top = anchor.dy - projection.tileWidth * heightFactor;
    final bottom = anchor.dy + projection.tileHeight * span * 0.28;
    return Path()
      ..moveTo(anchor.dx, top)
      ..lineTo(anchor.dx + halfWidth, anchor.dy - projection.tileHeight * 0.2)
      ..lineTo(anchor.dx + halfWidth * 0.88, bottom)
      ..lineTo(anchor.dx - halfWidth * 0.88, bottom)
      ..lineTo(anchor.dx - halfWidth, anchor.dy - projection.tileHeight * 0.2)
      ..close();
  }

  @override
  bool shouldRepaint(covariant IsometricCityPainter oldDelegate) {
    return oldDelegate.projection.tileWidth != projection.tileWidth ||
        oldDelegate.projection.tileHeight != projection.tileHeight ||
        oldDelegate.projection.origin != projection.origin ||
        oldDelegate.projection.width != projection.width ||
        oldDelegate.projection.height != projection.height ||
        oldDelegate.colorScheme != colorScheme ||
        oldDelegate.preview != preview ||
        oldDelegate.selectedBuildingId != selectedBuildingId ||
        oldDelegate.selectedTile != selectedTile ||
        oldDelegate.showGrid != showGrid ||
        !identical(oldDelegate.buildingSprites, buildingSprites) ||
        !listEquals(oldDelegate.buildings, buildings);
  }
}
