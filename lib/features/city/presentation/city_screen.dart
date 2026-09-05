import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:task_empire/core/theme/app_theme.dart';
import 'package:task_empire/features/city/bloc/city_bloc.dart';
import 'package:task_empire/features/city/domain/city_building.dart';
import 'package:task_empire/features/city/domain/city_state_data.dart';
import 'package:task_empire/features/city/presentation/isometric_city_view.dart';

class CityScreen extends StatelessWidget {
  const CityScreen({this.isActive = true, super.key});

  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return BlocListener<CityBloc, CityState>(
      listenWhen: (previous, current) {
        if (!isActive || current is! CityDisplay || current.feedback == null) {
          return false;
        }
        return previous is! CityDisplay ||
            previous.feedback?.id != current.feedback?.id;
      },
      listener: (context, state) {
        final feedback = (state as CityDisplay).feedback!;
        final colors = Theme.of(context).colorScheme;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(feedback.message),
              backgroundColor: feedback.isError
                  ? colors.error
                  : colors.inverseSurface,
            ),
          );
      },
      child: BlocBuilder<CityBloc, CityState>(
        builder: (context, state) {
          return Scaffold(
            backgroundColor: Colors.transparent,
            body: SafeArea(bottom: false, child: _CityContent(state: state)),
          );
        },
      ),
    );
  }
}

class _CityContent extends StatelessWidget {
  const _CityContent({required this.state});

  final CityState state;

  @override
  Widget build(BuildContext context) {
    final data = state.data;
    if (data == null) {
      if (state case CityFailure(:final message)) {
        return _FailureView(message: message);
      }
      return const Center(child: CircularProgressIndicator());
    }

    final display = state is CityDisplay ? state as CityDisplay : null;
    final compactNavigation = MediaQuery.sizeOf(context).width < 900;
    return Stack(
      children: [
        Positioned.fill(
          child: Container(
            key: const ValueKey('city-scene-panel'),
            margin: const EdgeInsets.fromLTRB(10, 8, 10, 8),
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFDCECDD), Color(0xFFBFD4C4)],
              ),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: const Color(0x263F9373)),
              boxShadow: const [AppShadows.elevated],
            ),
            child: IsometricCityView(
              city: data.city,
              buildings: data.buildings,
              preview: state.preview,
              selectedBuildingId: state.selectedBuildingId,
              selectedTile: state.selectedTile,
              showGrid: state.mode != CityMode.view,
              onTileTap: (tile) =>
                  context.read<CityBloc>().add(CityTileTapped(tile)),
            ),
          ),
        ),
        Positioned(
          left: 20,
          top: 18,
          right: 76,
          child: _CityHeader(state: state, data: data),
        ),
        Positioned(
          left: 20,
          right: 20,
          bottom: compactNavigation ? 94 : 18,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: AnimatedSwitcher(
                duration: AppMotion.quick,
                child: _bottomPanel(context, display, data),
              ),
            ),
          ),
        ),
        if (state is CityLoading)
          const Positioned(
            left: 24,
            right: 80,
            top: 16,
            child: LinearProgressIndicator(minHeight: 2),
          ),
        if (state case CityOperationInProgress(:final message)) ...[
          const Positioned.fill(
            child: ModalBarrier(dismissible: false, color: Color(0x3D0E2924)),
          ),
          Center(
            child: Material(
              color: AppColors.paper,
              borderRadius: BorderRadius.circular(22),
              elevation: 8,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 22,
                  vertical: 18,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox.square(
                      dimension: 24,
                      child: CircularProgressIndicator(strokeWidth: 3),
                    ),
                    const SizedBox(width: 14),
                    Text(message),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _bottomPanel(
    BuildContext context,
    CityDisplay? display,
    CityStateData data,
  ) {
    if (display == null) {
      return const SizedBox.shrink(key: ValueKey('city-loading-controls'));
    }
    final preview = display.preview;
    if (preview != null) {
      return _PlacementPanel(
        key: ValueKey('city-mode-${display.mode.name}'),
        mode: display.mode,
        preview: preview,
      );
    }
    if (display.mode == CityMode.edit) {
      return _EditPanel(
        key: const ValueKey('city-mode-edit'),
        data: data,
        selectedBuilding: display.selectedBuilding,
      );
    }
    final building = display.selectedBuilding;
    if (building != null) {
      return _BuildingInfoPanel(
        key: const ValueKey('city-building-info'),
        building: building,
      );
    }
    return const _CityHint(key: ValueKey('city-mode-view'));
  }
}

class _CityHeader extends StatelessWidget {
  const _CityHeader({required this.state, required this.data});

  final CityState state;
  final CityStateData data;

  @override
  Widget build(BuildContext context) {
    final canInteract = state is CityDisplay;
    final inViewMode = state.mode == CityMode.view;
    return Material(
      color: AppColors.forest950.withValues(alpha: 0.94),
      borderRadius: BorderRadius.circular(22),
      elevation: 4,
      shadowColor: AppColors.forest950.withValues(alpha: 0.24),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 11, 10, 11),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: const BoxDecoration(
                    gradient: AppColors.goldGradient,
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                  ),
                  child: const Icon(
                    Icons.location_city_rounded,
                    color: AppColors.forest950,
                    size: 21,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'МОЙ ГОРОД',
                        style: TextStyle(
                          color: AppColors.gold400,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.25,
                        ),
                      ),
                      Text(
                        state.mode == CityMode.view
                            ? 'Город ${data.city.level} уровня'
                            : 'Планировка города',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Обновить город',
                  onPressed: canInteract && state.preview == null
                      ? () => context.read<CityBloc>().add(
                          const CityRefreshRequested(),
                        )
                      : null,
                  color: Colors.white,
                  disabledColor: Colors.white24,
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.refresh_rounded, size: 20),
                ),
                const SizedBox(width: 3),
                FilledButton.tonalIcon(
                  key: const ValueKey('city-edit-toggle'),
                  onPressed: !canInteract
                      ? null
                      : () => context.read<CityBloc>().add(
                          inViewMode
                              ? const CityEditModeRequested()
                              : const CityViewModeRequested(),
                        ),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    backgroundColor: inViewMode
                        ? AppColors.gold400
                        : Colors.white.withValues(alpha: 0.12),
                    foregroundColor: inViewMode
                        ? AppColors.forest950
                        : Colors.white,
                  ),
                  icon: Icon(
                    inViewMode ? Icons.edit_rounded : Icons.done_rounded,
                    size: 17,
                  ),
                  label: Text(inViewMode ? 'Править' : 'Готово'),
                ),
              ],
            ),
            const SizedBox(height: 9),
            Row(
              children: [
                _HeaderMetric(
                  icon: Icons.monetization_on_rounded,
                  value: '${data.profile.gold}',
                  label: 'золото',
                  color: AppColors.gold400,
                ),
                const SizedBox(width: 7),
                _HeaderMetric(
                  icon: Icons.auto_graph_rounded,
                  value: '${data.profile.prosperity}',
                  label: 'процветание',
                  color: const Color(0xFF7FD5AA),
                ),
                const SizedBox(width: 7),
                _HeaderMetric(
                  icon: Icons.star_rounded,
                  value: '${data.profile.level}',
                  label: 'уровень',
                  color: const Color(0xFF9CCAE8),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderMetric extends StatelessWidget {
  const _HeaderMetric({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.075),
          borderRadius: BorderRadius.circular(11),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                '$value $label',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CityHint extends StatelessWidget {
  const _CityHint({super.key});

  @override
  Widget build(BuildContext context) {
    return _GlassPanel(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.pan_tool_alt_rounded, color: AppColors.forest700),
          SizedBox(width: 9),
          Flexible(
            child: Text(
              'Перемещайте и масштабируйте карту. Нажмите на здание, чтобы узнать о нём больше.',
              style: TextStyle(
                color: AppColors.ink,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BuildingInfoPanel extends StatelessWidget {
  const _BuildingInfoPanel({required this.building, super.key});

  final CityBuilding building;

  @override
  Widget build(BuildContext context) {
    return _GlassPanel(
      child: Row(
        children: [
          _BuildingIcon(code: building.definition.visualCode),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  building.name,
                  style: const TextStyle(
                    color: AppColors.ink,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Уровень ${building.level} · '
                  '${building.footprint.size.width}×${building.footprint.size.height} · '
                  '+${building.prosperity} процветания',
                  style: const TextStyle(
                    color: AppColors.mutedInk,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Закрыть',
            onPressed: () =>
                context.read<CityBloc>().add(const CityActionDismissed()),
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
    );
  }
}

class _EditPanel extends StatelessWidget {
  const _EditPanel({
    required this.data,
    required this.selectedBuilding,
    super.key,
  });

  final CityStateData data;
  final CityBuilding? selectedBuilding;

  @override
  Widget build(BuildContext context) {
    final building = selectedBuilding;
    return _GlassPanel(
      child: Row(
        children: [
          if (building != null) ...[
            _BuildingIcon(code: building.definition.visualCode),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    building.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                    ),
                  ),
                  Text(
                    'Клетка ${building.position.x + 1}:${building.position.y + 1}',
                    style: const TextStyle(
                      color: AppColors.mutedInk,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            OutlinedButton.icon(
              key: const ValueKey('city-move-building'),
              onPressed: () => context.read<CityBloc>().add(
                CityMoveModeRequested(building.id),
              ),
              icon: const Icon(Icons.open_with_rounded, size: 18),
              label: const Text('Перенести'),
            ),
            const SizedBox(width: 8),
          ] else ...[
            const Icon(Icons.grid_view_rounded, color: AppColors.forest700),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Выберите постройку на карте или добавьте новую.',
                style: TextStyle(
                  color: AppColors.mutedInk,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
          FilledButton.icon(
            key: const ValueKey('city-open-catalog'),
            onPressed: () => _openCatalog(context, data),
            icon: const Icon(Icons.add_business_rounded, size: 18),
            label: const Text('Строить'),
          ),
        ],
      ),
    );
  }

  Future<void> _openCatalog(BuildContext context, CityStateData data) async {
    final code = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (_) => _CityCatalogSheet(data: data),
    );
    if (code == null || !context.mounted) return;
    context.read<CityBloc>().add(CityBuildModeRequested(code));
  }
}

class _PlacementPanel extends StatelessWidget {
  const _PlacementPanel({required this.mode, required this.preview, super.key});

  final CityMode mode;
  final CityPlacementPreview preview;

  @override
  Widget build(BuildContext context) {
    final isValid = preview.validation.isValid;
    final size = preview.footprint.size;
    return _GlassPanel(
      key: ValueKey(
        isValid ? 'city-placement-valid' : 'city-placement-invalid',
      ),
      borderColor: isValid ? const Color(0x6631A666) : const Color(0x66C33E3E),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: (isValid ? const Color(0xFF2FA866) : AppColors.danger)
                  .withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(
              isValid ? Icons.check_rounded : Icons.close_rounded,
              color: isValid ? const Color(0xFF1D8250) : AppColors.danger,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  preview.definition.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.ink,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  '${preview.validation.message} · '
                  '${size.width}×${size.height} · '
                  '${preview.rotation.degrees}°',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isValid ? AppColors.mutedInk : AppColors.danger,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          IconButton.outlined(
            key: const ValueKey('city-rotate-placement'),
            tooltip: 'Повернуть на 90°',
            onPressed: () =>
                context.read<CityBloc>().add(const CityPlacementRotated()),
            icon: const Icon(Icons.rotate_90_degrees_cw_rounded),
          ),
          const SizedBox(width: 7),
          IconButton.outlined(
            key: const ValueKey('city-cancel-placement'),
            tooltip: 'Отменить',
            onPressed: () =>
                context.read<CityBloc>().add(const CityPlacementCanceled()),
            icon: const Icon(Icons.close_rounded),
          ),
          const SizedBox(width: 7),
          FilledButton.icon(
            key: const ValueKey('city-confirm-placement'),
            onPressed: isValid
                ? () => context.read<CityBloc>().add(
                    const CityPlacementConfirmed(),
                  )
                : null,
            icon: Icon(
              mode == CityMode.build
                  ? Icons.construction_rounded
                  : Icons.done_rounded,
              size: 18,
            ),
            label: Text(
              mode == CityMode.build
                  ? '${preview.definition.price} золота'
                  : 'Сохранить',
            ),
          ),
        ],
      ),
    );
  }
}

class _CityCatalogSheet extends StatelessWidget {
  const _CityCatalogSheet({required this.data});

  final CityStateData data;

  @override
  Widget build(BuildContext context) {
    final items = data.buildableDefinitions;
    return FractionallySizedBox(
      heightFactor: 0.72,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFD1C9BA),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const SizedBox(height: 17),
            Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'АРХИТЕКТУРНОЕ БЮРО',
                        style: TextStyle(
                          color: AppColors.gold600,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                        ),
                      ),
                      Text(
                        'Выберите постройку',
                        style: TextStyle(
                          color: AppColors.ink,
                          fontSize: 21,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
                _GoldBadge(value: data.profile.gold),
              ],
            ),
            const SizedBox(height: 14),
            Expanded(
              child: items.isEmpty
                  ? const Center(child: Text('Каталог пока пуст.'))
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        final columns = constraints.maxWidth >= 680 ? 3 : 2;
                        return GridView.builder(
                          itemCount: items.length,
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: columns,
                                mainAxisSpacing: 10,
                                crossAxisSpacing: 10,
                                childAspectRatio: columns == 3 ? 1.55 : 1.12,
                              ),
                          itemBuilder: (context, index) => _CatalogCard(
                            definition: items[index],
                            profile: data.profile,
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CatalogCard extends StatelessWidget {
  const _CatalogCard({required this.definition, required this.profile});

  final BuildingDefinition definition;
  final CityProfile profile;

  @override
  Widget build(BuildContext context) {
    final unlocked = definition.isUnlockedAt(profile.level);
    final affordable = profile.gold >= definition.price;
    final enabled = unlocked && affordable;
    return Opacity(
      opacity: enabled ? 1 : 0.58,
      child: Material(
        key: ValueKey('city-catalog-${definition.code}'),
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: enabled
              ? () => Navigator.of(context).pop(definition.code)
              : null,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _BuildingIcon(code: definition.code),
                    const Spacer(),
                    if (!unlocked)
                      const Icon(
                        Icons.lock_rounded,
                        size: 18,
                        color: AppColors.mutedInk,
                      ),
                  ],
                ),
                const Spacer(),
                Text(
                  definition.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.ink,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  !unlocked
                      ? 'Нужен уровень ${definition.requiredPlayerLevel}'
                      : !affordable
                      ? 'Не хватает ${definition.price - profile.gold}'
                      : '${definition.footprintWidth}×${definition.footprintHeight} · '
                            '+${definition.prosperity}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.mutedInk,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 7),
                Row(
                  children: [
                    const Icon(
                      Icons.monetization_on_rounded,
                      size: 16,
                      color: AppColors.gold600,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${definition.price}',
                      style: const TextStyle(
                        color: AppColors.forest900,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BuildingIcon extends StatelessWidget {
  const _BuildingIcon({required this.code});

  final String code;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: AppColors.mint200,
        borderRadius: BorderRadius.circular(13),
      ),
      child: Icon(_iconForBuilding(code), color: AppColors.forest700, size: 22),
    );
  }
}

class _GoldBadge extends StatelessWidget {
  const _GoldBadge({required this.value});

  final int value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEBC5),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.monetization_on_rounded,
            size: 17,
            color: AppColors.gold600,
          ),
          const SizedBox(width: 5),
          Text(
            '$value',
            style: const TextStyle(
              color: AppColors.forest900,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _GlassPanel extends StatelessWidget {
  const _GlassPanel({required this.child, this.borderColor, super.key});

  final Widget child;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.paper.withValues(alpha: 0.96),
      borderRadius: BorderRadius.circular(22),
      elevation: 5,
      shadowColor: AppColors.forest950.withValues(alpha: 0.18),
      child: Container(
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: borderColor ?? const Color(0x243F9373)),
        ),
        child: child,
      ),
    );
  }
}

class _FailureView extends StatelessWidget {
  const _FailureView({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_outlined,
              size: 56,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () =>
                  context.read<CityBloc>().add(const CityStarted()),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Повторить'),
            ),
          ],
        ),
      ),
    );
  }
}

IconData _iconForBuilding(String code) {
  return switch (code) {
    'town_hall' => Icons.account_balance_rounded,
    'house' => Icons.home_rounded,
    'library' => Icons.local_library_rounded,
    'workshop' => Icons.handyman_rounded,
    'market' => Icons.storefront_rounded,
    'tower' => Icons.castle_rounded,
    'garden' => Icons.park_rounded,
    _ => Icons.apartment_rounded,
  };
}
