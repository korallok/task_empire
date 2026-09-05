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
    this.city = CityMap.legacy,
    this.preview,
    this.selectedBuildingId,
    this.selectedTile,
    this.showGrid = false,
    this.transformationController,
    super.key,
  });

  final CityMap city;
  final List<CityBuilding> buildings;
  final CityTileTapCallback onTileTap;
  final CityPlacementPreview? preview;
  final String? selectedBuildingId;
  final CityTileCoordinate? selectedTile;
  final bool showGrid;

  /// Optional controller for automated tests and external camera controls.
  final TransformationController? transformationController;

  @override
  State<IsometricCityView> createState() => _IsometricCityViewState();
}

class _IsometricCityViewState extends State<IsometricCityView> {
  static const _tileWidth = 92.0;
  static const _tileHeight = 46.0;

  final _internalController = TransformationController();
  Map<String, ui.Image> _buildingSprites = const {};
  AssetBundle? _loadedBundle;
  String? _loadedAssetSignature;
  Size? _viewportSize;
  String? _layoutSignature;
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
    if (_assetSignature(oldWidget) != _assetSignature(widget)) {
      _loadBuildingSprites(force: true);
    }
    if (oldWidget.transformationController != widget.transformationController ||
        oldWidget.city != widget.city) {
      _viewportSize = null;
      _layoutSignature = null;
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
    final scene = _CitySceneGeometry.fromMap(widget.city);
    return LayoutBuilder(
      builder: (context, constraints) {
        final fallbackSize = MediaQuery.sizeOf(context);
        final viewportSize = Size(
          constraints.maxWidth.isFinite
              ? constraints.maxWidth
              : fallbackSize.width,
          constraints.maxHeight.isFinite
              ? constraints.maxHeight
              : (fallbackSize.height * 0.68).clamp(320, 720).toDouble(),
        );
        final minScale = _minimumScale(viewportSize, scene.size);
        _scheduleInitialView(viewportSize, scene.size);

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
                    maxScale: 2.8,
                    boundaryMargin: const EdgeInsets.all(480),
                    clipBehavior: Clip.hardEdge,
                    scaleFactor: 150,
                    child: GestureDetector(
                      key: const ValueKey('city-scene'),
                      behavior: HitTestBehavior.opaque,
                      onTapUp: (details) =>
                          _handleTap(details.localPosition, scene.projection),
                      child: CustomPaint(
                        size: scene.size,
                        painter: IsometricCityPainter(
                          projection: scene.projection,
                          buildings: widget.buildings,
                          buildingSprites: _buildingSprites,
                          colorScheme: Theme.of(context).colorScheme,
                          preview: widget.preview,
                          selectedBuildingId: widget.selectedBuildingId,
                          selectedTile: widget.selectedTile,
                          showGrid: widget.showGrid,
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 12,
                  right: 12,
                  child: _CityCameraControls(
                    onZoomIn: () => _zoomBy(1.22, scene.size),
                    onZoomOut: () => _zoomBy(1 / 1.22, scene.size),
                    onReset: () => _resetView(scene.size),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _scheduleInitialView(Size viewportSize, Size sceneSize) {
    final signature = '${sceneSize.width}:${sceneSize.height}';
    if (_viewportSize == viewportSize && _layoutSignature == signature) return;
    _viewportSize = viewportSize;
    _layoutSignature = signature;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          _viewportSize != viewportSize ||
          _layoutSignature != signature) {
        return;
      }
      _controller.value = _centeredMatrix(viewportSize, sceneSize);
    });
  }

  Matrix4 _centeredMatrix(Size viewportSize, Size sceneSize) {
    final fitScale = math.min(
      viewportSize.width / sceneSize.width,
      viewportSize.height / sceneSize.height,
    );
    final scale = (fitScale * 1.1)
        .clamp(_minimumScale(viewportSize, sceneSize), 1.0)
        .toDouble();
    return _viewMatrix(
      scale: scale,
      offset: Offset(
        (viewportSize.width - sceneSize.width * scale) / 2,
        (viewportSize.height - sceneSize.height * scale) / 2,
      ),
    );
  }

  double _minimumScale(Size viewportSize, Size sceneSize) {
    final fitScale = math.min(
      viewportSize.width / sceneSize.width,
      viewportSize.height / sceneSize.height,
    );
    return (fitScale * 0.72).clamp(0.12, 1.0).toDouble();
  }

  void _resetView(Size sceneSize) {
    final viewportSize = _viewportSize;
    if (viewportSize == null) return;
    _controller.value = _centeredMatrix(viewportSize, sceneSize);
  }

  void _zoomBy(double factor, Size sceneSize) {
    final viewportSize = _viewportSize;
    if (viewportSize == null) return;

    final currentScale = _controller.value.getMaxScaleOnAxis();
    final nextScale = (currentScale * factor)
        .clamp(_minimumScale(viewportSize, sceneSize), 2.8)
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

  void _handleTap(Offset position, IsometricProjection projection) {
    final tile = projection.tileAt(position);
    if (tile != null) {
      widget.onTileTap(tile);
      return;
    }
    final tappedBuilding = IsometricCityPainter.buildingAt(
      position: position,
      buildings: widget.buildings,
      projection: projection,
    );
    if (tappedBuilding != null) {
      widget.onTileTap(tappedBuilding.position);
    }
  }

  void _loadBuildingSprites({bool force = false}) {
    final bundle = DefaultAssetBundle.of(context);
    final signature = _assetSignature(widget);
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
      additionalDefinitions: [
        if (widget.preview case CityPlacementPreview(:final definition))
          definition,
      ],
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
      setState(() => _buildingSprites = sprites);
    });
  }

  String _assetSignature(IsometricCityView value) {
    final keys = <String>{
      for (final building in value.buildings)
        CityBuildingArt.forBuilding(building).key,
      if (value.preview != null)
        CityBuildingArt.forDefinition(value.preview!.definition).key,
    }.toList()..sort();
    return keys.join('|');
  }
}

final class _CitySceneGeometry {
  const _CitySceneGeometry({required this.size, required this.projection});

  factory _CitySceneGeometry.fromMap(CityMap city) {
    const horizontalMargin = 150.0;
    const topMargin = 250.0;
    const bottomMargin = 120.0;
    final size = Size(
      (city.width + city.height) * _IsometricCityViewState._tileWidth / 2 +
          horizontalMargin * 2,
      (city.width + city.height) * _IsometricCityViewState._tileHeight / 2 +
          topMargin +
          bottomMargin,
    );
    return _CitySceneGeometry(
      size: size,
      projection: IsometricProjection(
        tileWidth: _IsometricCityViewState._tileWidth,
        tileHeight: _IsometricCityViewState._tileHeight,
        origin: Offset(
          horizontalMargin +
              city.height * _IsometricCityViewState._tileWidth / 2,
          topMargin,
        ),
        width: city.width,
        height: city.height,
      ),
    );
  }

  final Size size;
  final IsometricProjection projection;
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
