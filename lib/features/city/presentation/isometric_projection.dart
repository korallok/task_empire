import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:task_empire/features/city/domain/city_building.dart';

final class IsometricProjection {
  const IsometricProjection({
    required this.tileWidth,
    required this.tileHeight,
    required this.origin,
    int? width,
    int? height,
    int? gridSize,
  }) : width = width ?? gridSize ?? CityTileCoordinate.gridSize,
       height = height ?? gridSize ?? CityTileCoordinate.gridSize,
       assert(tileWidth > 0),
       assert(tileHeight > 0),
       assert((width ?? gridSize ?? CityTileCoordinate.gridSize) > 0),
       assert((height ?? gridSize ?? CityTileCoordinate.gridSize) > 0);

  final double tileWidth;
  final double tileHeight;
  final Offset origin;
  final int width;
  final int height;

  /// Compatibility helper for callers that still use square maps.
  int get gridSize => math.max(width, height);

  Offset gridPoint(double x, double y) {
    return origin + Offset((x - y) * tileWidth / 2, (x + y) * tileHeight / 2);
  }

  Offset tileCenter(int x, int y) => gridPoint(x.toDouble(), y.toDouble());

  Offset footprintCenter(CityFootprint footprint) {
    return gridPoint(footprint.centerX, footprint.centerY);
  }

  Path tilePath(int x, int y, {double inset = 0}) {
    final center = tileCenter(x, y);
    final halfWidth = math.max(0.0, tileWidth / 2 - inset);
    final halfHeight = math.max(0.0, tileHeight / 2 - inset / 2);

    return Path()
      ..moveTo(center.dx, center.dy - halfHeight)
      ..lineTo(center.dx + halfWidth, center.dy)
      ..lineTo(center.dx, center.dy + halfHeight)
      ..lineTo(center.dx - halfWidth, center.dy)
      ..close();
  }

  CityTileCoordinate? tileAt(Offset screenPosition) {
    final localX = screenPosition.dx - origin.dx;
    final localY = screenPosition.dy - origin.dy;

    final fractionalX = localX / tileWidth + localY / tileHeight;
    final fractionalY = localY / tileHeight - localX / tileWidth;
    final centerX = fractionalX.round();
    final centerY = fractionalY.round();

    CityTileCoordinate? bestMatch;
    var bestDistanceSquared = double.infinity;
    for (var x = centerX - 1; x <= centerX + 1; x++) {
      for (var y = centerY - 1; y <= centerY + 1; y++) {
        if (!_isInsideGrid(x, y) || !tilePath(x, y).contains(screenPosition)) {
          continue;
        }

        final center = tileCenter(x, y);
        final delta = center - screenPosition;
        final distanceSquared = delta.dx * delta.dx + delta.dy * delta.dy;
        if (distanceSquared < bestDistanceSquared) {
          bestDistanceSquared = distanceSquared;
          bestMatch = CityTileCoordinate(x, y);
        }
      }
    }

    return bestMatch;
  }

  bool _isInsideGrid(int x, int y) {
    return x >= 0 && x < width && y >= 0 && y < height;
  }
}
