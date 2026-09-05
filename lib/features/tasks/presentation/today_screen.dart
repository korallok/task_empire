import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:task_empire/core/theme/app_theme.dart';
import 'package:task_empire/features/tasks/bloc/tasks_bloc.dart';
import 'package:task_empire/features/tasks/domain/task_models.dart';
import 'package:task_empire/features/tasks/presentation/widgets/tasks_screen_support.dart';

class TodayScreen extends StatelessWidget {
  const TodayScreen({this.isActive = true, super.key});

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
          return Scaffold(
            backgroundColor: Colors.transparent,
            body: SafeArea(
              bottom: false,
              child: switch (state) {
                TasksFailure(:final message, previousSnapshot: null) =>
                  TasksFailureView(message: message),
                _ => _TodayBody(state: state, bottomInset: bottomInset),
              },
            ),
            floatingActionButton: Padding(
              padding: EdgeInsets.only(bottom: bottomInset - 20),
              child: FloatingActionButton.extended(
                key: const ValueKey('today-add-task'),
                onPressed: state is TasksDisplay
                    ? () => context.read<TasksBloc>().add(
                        TasksCreateRequested(initialDate: DateTime.now()),
                      )
                    : null,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Новая задача'),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _TodayBody extends StatelessWidget {
  const _TodayBody({required this.state, required this.bottomInset});

  final TasksState state;
  final double bottomInset;

  @override
  Widget build(BuildContext context) {
    final snapshot = state.snapshot;
    if (snapshot == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final today = dateOnly(DateTime.now());
    final tasks = snapshot.tasksForDay(today);

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
                  constraints: const BoxConstraints(maxWidth: 980),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _TodayHero(snapshot: snapshot, day: today),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Задачи на сегодня',
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                          ),
                          Text(
                            '${snapshot.completedForDay(today)} / ${tasks.length}',
                            style: const TextStyle(
                              color: AppColors.mutedInk,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TaskCards(
                        tasks: tasks,
                        state: state,
                        emptyTitle: 'Сегодня всё свободно',
                        emptyDescription:
                            'Добавьте одно реальное дело — его выполнение '
                            'станет следующим шагом в развитии города.',
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

class _TodayHero extends StatelessWidget {
  const _TodayHero({required this.snapshot, required this.day});

  final TasksSnapshot snapshot;
  final DateTime day;

  @override
  Widget build(BuildContext context) {
    final progress = snapshot.progressForDay(day);
    final tasks = snapshot.tasksForDay(day);
    final completed = snapshot.completedForDay(day);
    final remaining = tasks.length - completed;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
      decoration: BoxDecoration(
        gradient: AppColors.forestGradient,
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(
            color: Color(0x32153B33),
            blurRadius: 26,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Stack(
        children: [
          const Positioned(
            right: -42,
            top: -52,
            child: _GlowOrb(size: 168, color: Color(0x183F9373)),
          ),
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 600;
              final heading = Row(
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    decoration: const BoxDecoration(
                      gradient: AppColors.goldGradient,
                      borderRadius: BorderRadius.all(Radius.circular(17)),
                    ),
                    child: const Icon(
                      Icons.wb_sunny_outlined,
                      color: AppColors.forest950,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          DateFormat(
                            'EEEE, d MMMM',
                            'ru',
                          ).format(day).toUpperCase(),
                          style: const TextStyle(
                            color: AppColors.gold400,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 3),
                        const Text(
                          'Сегодня строим империю',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 23,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                          ),
                        ),
                        Text(
                          remaining == 0 && tasks.isNotEmpty
                              ? 'План выполнен — награды уже в казне.'
                              : '$remaining дел отделяют вас от нового прогресса.',
                          style: const TextStyle(
                            color: Colors.white60,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
              final progressCard = _TodayProgress(
                completed: completed,
                total: tasks.length,
                progress: progress,
              );
              if (compact) {
                return Column(
                  children: [heading, const SizedBox(height: 18), progressCard],
                );
              }
              return Row(
                children: [
                  Expanded(flex: 3, child: heading),
                  const SizedBox(width: 24),
                  Expanded(flex: 2, child: progressCard),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _TodayProgress extends StatelessWidget {
  const _TodayProgress({
    required this.completed,
    required this.total,
    required this.progress,
  });

  final int completed;
  final int total;
  final double progress;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.09)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Text(
                'Прогресс дня',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Text(
                '$completed / $total',
                style: const TextStyle(
                  color: AppColors.gold400,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              color: AppColors.gold400,
              backgroundColor: Colors.white12,
            ),
          ),
        ],
      ),
    );
  }
}

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
