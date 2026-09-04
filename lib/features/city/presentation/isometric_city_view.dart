import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:task_empire/core/theme/app_theme.dart';
import 'package:task_empire/features/city/domain/city_building.dart';
import 'package:task_empire/features/city/presentation/city_building_art.dart';
import 'package:task_empire/features/city/presentation/isometric_city_painter.dart';
import 'package:task_empire/features/city/presentation/isometric_projection.dart';

typedef CityTileTapCallback = void Function(CityTileCoordinate tile);

class IsometricCityView extends StatefulWidget {
  const IsometricCityView({
    required this.buildings,
    required this.onTileTap,
    this.transformationController,
    super.key,
  });

  final List<CityBuilding> buildings;
  final CityTileTapCallback onTileTap;

  /// Optional controller for automated tests and external camera controls.
  final TransformationController? transformationController;

  @override
  State<IsometricCityView> createState() => _IsometricCityViewState();
}

class _IsometricCityViewState extends State<IsometricCityView> {
  static const _sceneSize = Size(1040, 720);
  static const _tileWidth = 104.0;
  static const _tileHeight = 52.0;
  static const _projection = IsometricProjection(
    tileWidth: _tileWidth,
    tileHeight: _tileHeight,
    origin: Offset(520, 224),
  );

  final _internalController = TransformationController();
  CityTileCoordinate? _selectedTile;
  Map<String, ui.Image> _buildingSprites = const {};
  AssetBundle? _loadedBundle;
  String? _loadedAssetSignature;
  Size? _viewportSize;
  int _spriteLoadGeneration = 0;

  TransformationController get _controller =>
      widget.transformationController ?? _internalController;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadBuildingSprites();
  }

  @override
  void didUpdateWidget(covariant IsometricCityView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_assetSignature(oldWidget.buildings) !=
        _assetSignature(widget.buildings)) {
      _loadBuildingSprites(force: true);
    }
    if (oldWidget.transformationController != widget.transformationController) {
      _viewportSize = null;
    }
  }

  @override
  void dispose() {
    _spriteLoadGeneration++;
    for (final image in _buildingSprites.values) {
      image.dispose();
    }
    _internalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        final viewportSize = Size(
          availableWidth,
          (availableWidth * 0.72).clamp(310.0, 620.0),
        );
        final minScale = _minimumScale(viewportSize);
        _scheduleInitialView(viewportSize);

        return Semantics(
          label:
              'Изометрический город. Перетаскивайте карту и масштабируйте её.',
          child: SizedBox.fromSize(
            size: viewportSize,
            child: Stack(
              children: [
                Positioned.fill(
                  child: InteractiveViewer(
                    key: const ValueKey('city-interactive-view'),
                    transformationController: _controller,
                    constrained: false,
                    alignment: Alignment.topLeft,
                    minScale: minScale,
                    maxScale: 2.5,
                    boundaryMargin: const EdgeInsets.all(360),
                    clipBehavior: Clip.hardEdge,
                    scaleFactor: 160,
                    child: GestureDetector(
                      key: const ValueKey('city-scene'),
                      behavior: HitTestBehavior.opaque,
                      onTapUp: (details) => _handleTap(details.localPosition),
                      child: CustomPaint(
                        size: _sceneSize,
                        painter: IsometricCityPainter(
                          projection: _projection,
                          buildings: widget.buildings,
                          buildingSprites: _buildingSprites,
                          colorScheme: Theme.of(context).colorScheme,
                          selectedTile: _selectedTile,
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 12,
                  right: 12,
                  child: _CityCameraControls(
                    onZoomIn: () => _zoomBy(1.22),
                    onZoomOut: () => _zoomBy(1 / 1.22),
                    onReset: _resetView,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _scheduleInitialView(Size viewportSize) {
    if (_viewportSize == viewportSize) return;
    _viewportSize = viewportSize;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _viewportSize != viewportSize) return;
      _controller.value = _centeredMatrix(viewportSize);
    });
  }

  Matrix4 _centeredMatrix(Size viewportSize) {
    final fitScale = math.min(
      viewportSize.width / _sceneSize.width,
      viewportSize.height / _sceneSize.height,
    );
    final scale = (fitScale * 1.22)
        .clamp(_minimumScale(viewportSize), 1.08)
        .toDouble();
    final horizontalOffset =
        (viewportSize.width - _sceneSize.width * scale) / 2;
    final verticalOffset =
        (viewportSize.height - _sceneSize.height * scale) / 2 + 12;
    return _viewMatrix(
      scale: scale,
      offset: Offset(horizontalOffset, verticalOffset),
    );
  }

  double _minimumScale(Size viewportSize) {
    final fitScale = math.min(
      viewportSize.width / _sceneSize.width,
      viewportSize.height / _sceneSize.height,
    );
    return (fitScale * 0.86).clamp(0.25, 1.0).toDouble();
  }

  void _resetView() {
    final viewportSize = _viewportSize;
    if (viewportSize == null) return;
    _controller.value = _centeredMatrix(viewportSize);
  }

  void _zoomBy(double factor) {
    final viewportSize = _viewportSize;
    if (viewportSize == null) return;

    final currentScale = _controller.value.getMaxScaleOnAxis();
    final nextScale = (currentScale * factor)
        .clamp(_minimumScale(viewportSize), 2.5)
        .toDouble();
    final viewportCenter = viewportSize.center(Offset.zero);
    final scenePoint = _controller.toScene(viewportCenter);
    _controller.value = _viewMatrix(
      scale: nextScale,
      offset: viewportCenter - scenePoint * nextScale,
    );
  }

  Matrix4 _viewMatrix({required double scale, required Offset offset}) {
    return Matrix4.identity()
      ..setEntry(0, 0, scale)
      ..setEntry(1, 1, scale)
      ..setEntry(2, 2, scale)
      ..setEntry(0, 3, offset.dx)
      ..setEntry(1, 3, offset.dy);
  }

  void _handleTap(Offset position) {
    final tappedBuilding = IsometricCityPainter.buildingAt(
      position: position,
      buildings: widget.buildings,
      projection: _projection,
    );
    final tile = tappedBuilding?.tile ?? _projection.tileAt(position);
    if (tile == null) return;

    if (_selectedTile != tile) {
      setState(() => _selectedTile = tile);
    }
    widget.onTileTap(tile);
  }

  void _loadBuildingSprites({bool force = false}) {
    final bundle = DefaultAssetBundle.of(context);
    final signature = _assetSignature(widget.buildings);
    if (!force &&
        identical(bundle, _loadedBundle) &&
        signature == _loadedAssetSignature) {
      return;
    }
    _loadedBundle = bundle;
    _loadedAssetSignature = signature;
    final generation = ++_spriteLoadGeneration;

    CityBuildingArt.loadAvailableSprites(
      bundle: bundle,
      buildings: widget.buildings,
    ).then((sprites) {
      if (!mounted || generation != _spriteLoadGeneration) {
        for (final image in sprites.values) {
          image.dispose();
        }
        return;
      }
      for (final image in _buildingSprites.values) {
        image.dispose();
      }
      setState(() => _buildingSprites = Map.unmodifiable(sprites));
    });
  }

  String _assetSignature(Iterable<CityBuilding> buildings) {
    final keys =
        buildings
            .map((building) => CityBuildingArt.forBuilding(building).key)
            .toSet()
            .toList()
          ..sort();
    return keys.join('|');
  }
}

class _CityCameraControls extends StatelessWidget {
  const _CityCameraControls({
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onReset,
  });

  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.paper.withValues(alpha: 0.92),
      borderRadius: BorderRadius.circular(16),
      elevation: 3,
      shadowColor: AppColors.forest950.withValues(alpha: 0.18),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _CameraButton(
            tooltip: 'Приблизить',
            icon: Icons.add_rounded,
            onPressed: onZoomIn,
          ),
          const _CameraDivider(),
          _CameraButton(
            tooltip: 'Отдалить',
            icon: Icons.remove_rounded,
            onPressed: onZoomOut,
          ),
          const _CameraDivider(),
          _CameraButton(
            key: const ValueKey('city-reset-view'),
            tooltip: 'Вернуть город в центр',
            icon: Icons.center_focus_strong_rounded,
            onPressed: onReset,
          ),
        ],
      ),
    );
  }
}

class _CameraButton extends StatelessWidget {
  const _CameraButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    super.key,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      visualDensity: VisualDensity.compact,
      color: AppColors.forest700,
      icon: Icon(icon, size: 20),
    );
  }
}

class _CameraDivider extends StatelessWidget {
  const _CameraDivider();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 24,
      child: Divider(height: 1, color: Color(0x1F153B33)),
    );
  }
}
