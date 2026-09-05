import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:task_empire/core/theme/app_theme.dart';
import 'package:task_empire/features/tasks/bloc/tasks_bloc.dart';
import 'package:task_empire/features/tasks/presentation/widgets/tasks_screen_support.dart';

class TaskCalendarScreen extends StatelessWidget {
  const TaskCalendarScreen({this.isActive = true, super.key});

  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return TasksEffects(
      isActive: isActive,
      child: BlocBuilder<TasksBloc, TasksState>(
        builder: (context, state) {
          final bottomInset = MediaQuery.sizeOf(context).width < 900
              ? 92.0
              : 20.0;
          final snapshot = state.snapshot;
          return Scaffold(
            backgroundColor: Colors.transparent,
            body: SafeArea(
              bottom: false,
              child: switch (state) {
                TasksFailure(:final message, previousSnapshot: null) =>
                  TasksFailureView(message: message),
                _ when snapshot == null => const Center(
                  child: CircularProgressIndicator(),
                ),
                _ => _CalendarBody(
                  state: state,
                  snapshot: snapshot,
                  bottomInset: bottomInset,
                ),
              },
            ),
            floatingActionButton: Padding(
              padding: EdgeInsets.only(bottom: bottomInset - 20),
              child: FloatingActionButton.extended(
                key: const ValueKey('calendar-add-task'),
                onPressed: state is TasksDisplay && snapshot != null
                    ? () => context.read<TasksBloc>().add(
                        TasksCreateRequested(
                          initialDate: snapshot.selectedDate,
                        ),
                      )
                    : null,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Запланировать'),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _CalendarBody extends StatelessWidget {
  const _CalendarBody({
    required this.state,
    required this.snapshot,
    required this.bottomInset,
  });

  final TasksState state;
  final TasksSnapshot snapshot;
  final double bottomInset;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: () => _refresh(context),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(16, 14, 16, bottomInset + 72),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1120),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const _CalendarHeader(),
                      const SizedBox(height: 16),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final wide = constraints.maxWidth >= 840;
                          final calendar = IgnorePointer(
                            ignoring: state is! TasksDisplay,
                            child: AnimatedOpacity(
                              duration: const Duration(milliseconds: 180),
                              opacity: state is TasksDisplay ? 1 : 0.65,
                              child: _CalendarPicker(snapshot: snapshot),
                            ),
                          );
                          final tasks = _SelectedDayTasks(
                            state: state,
                            snapshot: snapshot,
                          );
                          if (!wide) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                calendar,
                                const SizedBox(height: 16),
                                tasks,
                              ],
                            );
                          }
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(width: 410, child: calendar),
                              const SizedBox(width: 18),
                              Expanded(child: tasks),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        if (state is TasksLoading)
          const Align(
            alignment: Alignment.topCenter,
            child: LinearProgressIndicator(minHeight: 2),
          ),
      ],
    );
  }

  Future<void> _refresh(BuildContext context) async {
    final bloc = context.read<TasksBloc>();
    if (bloc.state is! TasksDisplay) return;
    bloc.add(const TasksRefreshRequested());
    await bloc.stream.firstWhere(
      (next) => next is TasksDisplay || next is TasksFailure,
    );
  }
}

class _CalendarHeader extends StatelessWidget {
  const _CalendarHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: BoxDecoration(
        gradient: AppColors.forestGradient,
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(
            color: Color(0x26153B33),
            blurRadius: 22,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: const Row(
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: AppColors.goldGradient,
              borderRadius: BorderRadius.all(Radius.circular(16)),
            ),
            child: SizedBox.square(
              dimension: 52,
              child: Icon(
                Icons.calendar_month_rounded,
                color: AppColors.forest950,
              ),
            ),
          ),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'КАЛЕНДАРЬ',
                  style: TextStyle(
                    color: AppColors.gold400,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.6,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Планируйте путь вперёд',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 23,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.45,
                  ),
                ),
                Text(
                  'Выберите день, чтобы увидеть или перенести задачи.',
                  style: TextStyle(color: Colors.white60, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CalendarPicker extends StatelessWidget {
  const _CalendarPicker({required this.snapshot});

  final TasksSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.paper,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: const Color(0x140E2924)),
      ),
      clipBehavior: Clip.antiAlias,
      child: CalendarDatePicker(
        initialDate: snapshot.selectedDate,
        firstDate: DateTime(2020),
        lastDate: DateTime(2100),
        currentDate: DateTime.now(),
        onDateChanged: (day) =>
            context.read<TasksBloc>().add(TasksDaySelected(day)),
      ),
    );
  }
}

class _SelectedDayTasks extends StatelessWidget {
  const _SelectedDayTasks({required this.state, required this.snapshot});

  final TasksState state;
  final TasksSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final tasks = snapshot.selectedTasks;
    final completed = snapshot.completedForDay(snapshot.selectedDate);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      DateFormat(
                        'd MMMM, EEEE',
                        'ru',
                      ).format(snapshot.selectedDate),
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    Text(
                      tasks.isEmpty
                          ? 'Нет запланированных задач'
                          : '$completed из ${tasks.length} выполнено',
                      style: const TextStyle(color: AppColors.mutedInk),
                    ),
                  ],
                ),
              ),
              if (tasks.isNotEmpty)
                SizedBox.square(
                  dimension: 46,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CircularProgressIndicator(
                        value: snapshot.progressForDay(snapshot.selectedDate),
                        strokeWidth: 5,
                        color: AppColors.gold600,
                        backgroundColor: const Color(0xFFE1DACC),
                        semanticsLabel: 'Прогресс задач за выбранный день',
                      ),
                      Center(
                        child: Text(
                          '${(snapshot.progressForDay(snapshot.selectedDate) * 100).round()}%',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        TaskCards(
          tasks: tasks,
          state: state,
          emptyTitle: 'День пока свободен',
          emptyDescription:
              'Добавьте задачу на выбранную дату или перенесите сюда '
              'уже существующую.',
        ),
      ],
    );
  }
}
