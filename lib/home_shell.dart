import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:task_empire/core/theme/app_theme.dart';
import 'package:task_empire/features/city/bloc/city_bloc.dart';
import 'package:task_empire/features/city/presentation/city_screen.dart';
import 'package:task_empire/features/progression/bloc/progression_bloc.dart';
import 'package:task_empire/features/progression/presentation/profile_screen.dart';
import 'package:task_empire/features/tasks/presentation/task_calendar_screen.dart';
import 'package:task_empire/features/tasks/presentation/today_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  var _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final useRail = constraints.maxWidth >= 900;
        final pages = [
          TickerMode(
            enabled: _selectedIndex == 0,
            child: TodayScreen(isActive: _selectedIndex == 0),
          ),
          TickerMode(
            enabled: _selectedIndex == 1,
            child: TaskCalendarScreen(isActive: _selectedIndex == 1),
          ),
          TickerMode(
            enabled: _selectedIndex == 2,
            child: CityScreen(isActive: _selectedIndex == 2),
          ),
          TickerMode(
            enabled: _selectedIndex == 3,
            child: ProfileScreen(isActive: _selectedIndex == 3),
          ),
        ];

        return Scaffold(
          extendBody: !useRail,
          body: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFF8F4EA), Color(0xFFECE5D7)],
              ),
            ),
            child: useRail
                ? Row(
                    children: [
                      _EmpireRail(
                        selectedIndex: _selectedIndex,
                        onSelected: _selectDestination,
                      ),
                      Expanded(
                        child: IndexedStack(
                          index: _selectedIndex,
                          children: pages,
                        ),
                      ),
                    ],
                  )
                : IndexedStack(index: _selectedIndex, children: pages),
          ),
          bottomNavigationBar: useRail
              ? null
              : _EmpireBottomNavigation(
                  selectedIndex: _selectedIndex,
                  onSelected: _selectDestination,
                ),
        );
      },
    );
  }

  void _selectDestination(int index) {
    if (index == _selectedIndex) return;
    setState(() => _selectedIndex = index);
    if (index == 2) {
      final cityBloc = context.read<CityBloc>();
      if (cityBloc.state is CityOperationInProgress) return;
      if (cityBloc.state.data == null) {
        cityBloc.add(const CityStarted());
      } else {
        cityBloc.add(const CityRefreshRequested());
      }
    }
    if (index == 3) {
      final progressionBloc = context.read<ProgressionBloc>();
      if (progressionBloc.state case ProgressionLoading(
        previousProfile: null,
      )) {
        progressionBloc.add(const ProgressionStarted());
      } else {
        progressionBloc.add(const ProgressionRefreshRequested());
      }
    }
  }
}

class _EmpireRail extends StatelessWidget {
  const _EmpireRail({required this.selectedIndex, required this.onSelected});

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: AppColors.forestGradient,
        boxShadow: [
          BoxShadow(
            color: Color(0x330E2924),
            blurRadius: 24,
            offset: Offset(8, 0),
          ),
        ],
      ),
      child: SafeArea(
        child: NavigationRail(
          minWidth: 112,
          selectedIndex: selectedIndex,
          onDestinationSelected: onSelected,
          labelType: NavigationRailLabelType.all,
          leading: const Padding(
            padding: EdgeInsets.only(top: 10, bottom: 28),
            child: _EmpireMark(),
          ),
          destinations: const [
            NavigationRailDestination(
              icon: Icon(Icons.today_outlined),
              selectedIcon: Icon(Icons.today_rounded),
              label: Text('Сегодня'),
            ),
            NavigationRailDestination(
              icon: Icon(Icons.calendar_month_outlined),
              selectedIcon: Icon(Icons.calendar_month_rounded),
              label: Text('Календарь'),
            ),
            NavigationRailDestination(
              icon: Icon(Icons.location_city_outlined),
              selectedIcon: Icon(Icons.location_city_rounded),
              label: Text('Город'),
            ),
            NavigationRailDestination(
              icon: Icon(Icons.person_outline_rounded),
              selectedIcon: Icon(Icons.person_rounded),
              label: Text('Профиль'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmpireBottomNavigation extends StatelessWidget {
  const _EmpireBottomNavigation({
    required this.selectedIndex,
    required this.onSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.paper,
          borderRadius: BorderRadius.circular(24),
          boxShadow: const [
            BoxShadow(
              color: Color(0x240E2924),
              blurRadius: 22,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: NavigationBar(
            selectedIndex: selectedIndex,
            onDestinationSelected: onSelected,
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.today_outlined),
                selectedIcon: Icon(Icons.today_rounded),
                label: 'Сегодня',
              ),
              NavigationDestination(
                icon: Icon(Icons.calendar_month_outlined),
                selectedIcon: Icon(Icons.calendar_month_rounded),
                label: 'Календарь',
              ),
              NavigationDestination(
                icon: Icon(Icons.location_city_outlined),
                selectedIcon: Icon(Icons.location_city_rounded),
                label: 'Город',
              ),
              NavigationDestination(
                icon: Icon(Icons.person_outline_rounded),
                selectedIcon: Icon(Icons.person_rounded),
                label: 'Профиль',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmpireMark extends StatelessWidget {
  const _EmpireMark();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 50,
          height: 50,
          decoration: const BoxDecoration(
            gradient: AppColors.goldGradient,
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: Color(0x55F0BD5B), blurRadius: 18)],
          ),
          child: const Icon(
            Icons.account_balance_rounded,
            color: AppColors.forest950,
            size: 28,
          ),
        ),
        const SizedBox(height: 9),
        const Text(
          'TASK\nEMPIRE',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: 10,
            height: 1.05,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.4,
          ),
        ),
      ],
    );
  }
}
