import 'dart:async';

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
        if (!isActive) return false;
        final actionOpened =
            previous is! CityActionRequired && current is CityActionRequired;
        final hasFeedback = current is CityDisplay && current.feedback != null;
        return actionOpened || hasFeedback;
      },
      listener: (context, state) {
        if (state is CityActionRequired) {
          unawaited(_openTileAction(context, state));
        }
        if (state case CityDisplay(:final feedback?)) {
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
        }
      },
      child: BlocBuilder<CityBloc, CityState>(
        builder: (context, state) {
          return Scaffold(
            backgroundColor: Colors.transparent,
            body: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  _CityHero(state: state),
                  Expanded(child: _CityBody(state: state)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _openTileAction(
    BuildContext context,
    CityActionRequired state,
  ) async {
    final building = state.building;
    if (building == null) {
      final selectedType = await showModalBottomSheet<CityBuildingType>(
        context: context,
        useSafeArea: true,
        showDragHandle: false,
        backgroundColor: Colors.transparent,
        barrierColor: AppColors.forest950.withValues(alpha: 0.58),
        builder: (_) => _CityShopSheet(data: state.data, tile: state.tile),
      );
      if (!context.mounted) return;

      context.read<CityBloc>().add(
        selectedType == null
            ? const CityActionDismissed()
            : CityBuildRequested(type: selectedType, tile: state.tile),
      );
      return;
    }

    final shouldUpgrade = await showDialog<bool>(
      context: context,
      builder: (_) => _BuildingDialog(
        building: building,
        availableGold: state.data.profile.gold,
      ),
    );
    if (!context.mounted) return;

    context.read<CityBloc>().add(
      shouldUpgrade == true
          ? CityUpgradeRequested(building.id)
          : const CityActionDismissed(),
    );
  }
}

class _CityHero extends StatelessWidget {
  const _CityHero({required this.state});

  final CityState state;

  @override
  Widget build(BuildContext context) {
    final profile = state.data?.profile;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      padding: const EdgeInsets.fromLTRB(18, 17, 12, 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF244E43), AppColors.forest950],
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(
            color: Color(0x32153B33),
            blurRadius: 26,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: const BoxDecoration(
                  gradient: AppColors.goldGradient,
                  borderRadius: BorderRadius.all(Radius.circular(17)),
                ),
                child: const Icon(
                  Icons.location_city_rounded,
                  color: AppColors.forest950,
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ВЛАДЕНИЯ',
                      style: TextStyle(
                        color: AppColors.gold400,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.7,
                      ),
                    ),
                    Text(
                      'Мой город',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                    ),
                    Text(
                      'Развивайте империю силой выполненных задач',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.white60, fontSize: 11),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Обновить город',
                onPressed: state is CityDisplay
                    ? () => context.read<CityBloc>().add(
                        const CityRefreshRequested(),
                      )
                    : null,
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: 0.08),
                  foregroundColor: Colors.white,
                  disabledForegroundColor: Colors.white24,
                ),
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _CityHeroStat(
                  icon: Icons.monetization_on_rounded,
                  label: 'Золото',
                  value: profile == null ? '—' : '${profile.gold}',
                  color: AppColors.gold400,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _CityHeroStat(
                  icon: Icons.auto_graph_rounded,
                  label: 'Рост',
                  value: profile == null ? '—' : '${profile.prosperity}',
                  color: const Color(0xFF7FD5AA),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _CityHeroStat(
                  icon: Icons.schedule_rounded,
                  label: 'В час',
                  value: profile == null ? '—' : '+${profile.incomePerHour}',
                  color: const Color(0xFF8BC7EA),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CityHeroStat extends StatelessWidget {
  const _CityHeroStat({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 19),
          const SizedBox(width: 7),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white54, fontSize: 9),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CityBody extends StatelessWidget {
  const _CityBody({required this.state});

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

    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: () => _refresh(context),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 24),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 13,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.paper.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0x140E2924)),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.touch_app_rounded,
                          size: 18,
                          color: AppColors.forest700,
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Двигайте город одним пальцем, масштабируйте двумя. Коснитесь участка или здания для действия.',
                            style: TextStyle(
                              color: AppColors.mutedInk,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Container(
                  margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFFDCEBDD), Color(0xFFC8D8CC)],
                    ),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: const Color(0x243F9373)),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x1F153B33),
                        blurRadius: 20,
                        offset: Offset(0, 10),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    children: [
                      const Positioned(
                        right: -50,
                        top: -54,
                        child: _CityBackdropOrb(size: 180),
                      ),
                      IsometricCityView(
                        buildings: data.buildings,
                        onTileTap: (tile) =>
                            context.read<CityBloc>().add(CityTileTapped(tile)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        if (state is CityLoading)
          const Align(
            alignment: Alignment.topCenter,
            child: LinearProgressIndicator(minHeight: 2),
          ),
        if (state case CityOperationInProgress(:final message)) ...[
          const ModalBarrier(dismissible: false, color: Color(0x33000000)),
          Center(
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(width: 16),
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

  Future<void> _refresh(BuildContext context) async {
    final bloc = context.read<CityBloc>();
    if (bloc.state is! CityDisplay) return;

    bloc.add(const CityRefreshRequested());
    try {
      await bloc.stream
          .firstWhere((state) => state is CityDisplay || state is CityFailure)
          .timeout(const Duration(seconds: 20));
    } on TimeoutException {
      // The active request remains owned by the BLoC.
    }
  }
}

class _CityBackdropOrb extends StatelessWidget {
  const _CityBackdropOrb({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: Color(0x26FFFFFF),
        shape: BoxShape.circle,
      ),
    );
  }
}

class _CityShopSheet extends StatelessWidget {
  const _CityShopSheet({required this.data, required this.tile});

  final CityStateData data;
  final CityTileCoordinate tile;

  @override
  Widget build(BuildContext context) {
    final items = [
      data.catalogItem(CityBuildingType.market),
      data.catalogItem(CityBuildingType.townHall),
    ];

    return Material(
      color: AppColors.paper,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
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
              const SizedBox(height: 18),
              Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: const BoxDecoration(
                      gradient: AppColors.goldGradient,
                      borderRadius: BorderRadius.all(Radius.circular(16)),
                    ),
                    child: const Icon(
                      Icons.architecture_rounded,
                      color: AppColors.forest950,
                    ),
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'АРХИТЕКТУРНОЕ БЮРО',
                          style: TextStyle(
                            color: AppColors.gold600,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.3,
                          ),
                        ),
                        Text(
                          'Выберите постройку',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        Text(
                          'Участок ${tile.x + 1} · ${tile.y + 1}',
                          style: const TextStyle(
                            color: AppColors.mutedInk,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 11,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFEBC5),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.monetization_on_rounded,
                          size: 17,
                          color: AppColors.gold600,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          '${data.profile.gold}',
                          style: const TextStyle(
                            color: AppColors.forest900,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              for (final item in items)
                _ShopItem(
                  item: item,
                  availableGold: data.profile.gold,
                  onSelected: () => Navigator.pop(context, item.type),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShopItem extends StatelessWidget {
  const _ShopItem({
    required this.item,
    required this.availableGold,
    required this.onSelected,
  });

  final CityCatalogItem item;
  final int availableGold;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final canAfford = availableGold >= item.buildPrice;
    final icon = item.type == CityBuildingType.market
        ? Icons.storefront_rounded
        : Icons.account_balance_rounded;

    return Opacity(
      opacity: canAfford ? 1 : 0.62,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: canAfford
                ? const Color(0x253F9373)
                : const Color(0x1F776F63),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: canAfford ? onSelected : null,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.mint200,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Icon(icon, color: AppColors.forest700),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.type.displayName,
                        style: const TextStyle(
                          color: AppColors.ink,
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Wrap(
                        spacing: 10,
                        runSpacing: 4,
                        children: [
                          _ShopMetric(
                            icon: Icons.monetization_on_rounded,
                            text: '${item.buildPrice}',
                            color: AppColors.gold600,
                          ),
                          _ShopMetric(
                            icon: Icons.schedule_rounded,
                            text: '+${item.incomePerHour}/ч',
                            color: AppColors.forest700,
                          ),
                          _ShopMetric(
                            icon: Icons.auto_graph_rounded,
                            text: '+${item.prosperity}',
                            color: const Color(0xFF3C7B82),
                          ),
                        ],
                      ),
                      if (!canAfford) ...[
                        const SizedBox(height: 5),
                        Text(
                          'Не хватает ${item.buildPrice - availableGold} золота',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: canAfford ? AppColors.forest700 : AppColors.mutedInk,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ShopMetric extends StatelessWidget {
  const _ShopMetric({
    required this.icon,
    required this.text,
    required this.color,
  });

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 3),
        Text(
          text,
          style: const TextStyle(
            color: AppColors.mutedInk,
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _BuildingDialog extends StatelessWidget {
  const _BuildingDialog({required this.building, required this.availableGold});

  final CityBuilding building;
  final int availableGold;

  @override
  Widget build(BuildContext context) {
    final upgradeCost = building.upgradeCost;
    final canUpgrade =
        upgradeCost != null &&
        !building.isMaxLevel &&
        availableGold >= upgradeCost;

    final icon = building.type == CityBuildingType.market
        ? Icons.storefront_rounded
        : Icons.account_balance_rounded;

    return AlertDialog(
      backgroundColor: AppColors.paper,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      titlePadding: const EdgeInsets.fromLTRB(22, 22, 22, 0),
      contentPadding: const EdgeInsets.fromLTRB(22, 18, 22, 8),
      title: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(
              gradient: AppColors.goldGradient,
              borderRadius: BorderRadius.all(Radius.circular(15)),
            ),
            child: Icon(icon, color: AppColors.forest950),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'УПРАВЛЕНИЕ ЗДАНИЕМ',
                  style: TextStyle(
                    color: AppColors.gold600,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.1,
                  ),
                ),
                Text(
                  building.type.displayName,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                Text(
                  '${building.level} уровень',
                  style: const TextStyle(
                    color: AppColors.mutedInk,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.mint200,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _BuildingMetric(
                    label: 'Доход',
                    value: '+${building.incomePerHour}/ч',
                    icon: Icons.schedule_rounded,
                  ),
                ),
                Container(width: 1, height: 32, color: const Color(0x1F153B33)),
                Expanded(
                  child: _BuildingMetric(
                    label: 'Рост',
                    value: '+${building.prosperity}',
                    icon: Icons.auto_graph_rounded,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (upgradeCost != null && !building.isMaxLevel) ...[
            Text(
              'Улучшение до ${building.level + 1} уровня',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              'Стоимость — $upgradeCost золота.',
              style: const TextStyle(color: AppColors.mutedInk),
            ),
            if (!canUpgrade) ...[
              const SizedBox(height: 8),
              Text(
                'Недостаточно золота.',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ] else
            const Text('Достигнут максимальный уровень.'),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Закрыть'),
        ),
        FilledButton.icon(
          onPressed: canUpgrade ? () => Navigator.pop(context, true) : null,
          icon: const Icon(Icons.upgrade_rounded),
          label: const Text('Улучшить'),
        ),
      ],
    );
  }
}

class _BuildingMetric extends StatelessWidget {
  const _BuildingMetric({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 18, color: AppColors.forest700),
        const SizedBox(width: 7),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: const TextStyle(
                color: AppColors.forest900,
                fontWeight: FontWeight.w900,
              ),
            ),
            Text(
              label,
              style: const TextStyle(color: AppColors.mutedInk, fontSize: 10),
            ),
          ],
        ),
      ],
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
              icon: const Icon(Icons.refresh),
              label: const Text('Повторить'),
            ),
          ],
        ),
      ),
    );
  }
}
