import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:task_empire/core/theme/app_theme.dart';
import 'package:task_empire/features/calendar/bloc/calendar_bloc.dart';
import 'package:task_empire/features/calendar/data/task_item.dart';
import 'package:task_empire/features/calendar/presentation/add_task_sheet.dart';
import 'package:task_empire/features/calendar/presentation/task_list.dart';

class CalendarScreen extends StatelessWidget {
  const CalendarScreen({this.isActive = true, super.key});

  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: BlocListener<CalendarBloc, CalendarState>(
        listenWhen: (previous, current) {
          if (!isActive) return false;
          final addFormOpened =
              previous is! CalendarAdding && current is CalendarAdding;
          final hasFeedback =
              current is CalendarDisplay && current.feedback != null;
          return addFormOpened || hasFeedback;
        },
        listener: (context, state) {
          if (state is CalendarAdding && !state.isSubmitting) {
            unawaited(_openAddTaskSheet(context));
          }
          if (state case CalendarDisplay(:final feedback?)) {
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
        child: BlocBuilder<CalendarBloc, CalendarState>(
          builder: (context, state) {
            final hasBottomNavigation = MediaQuery.sizeOf(context).width < 900;
            return Scaffold(
              backgroundColor: Colors.transparent,
              body: SafeArea(
                bottom: false,
                child: Column(
                  children: [
                    _CalendarHero(state: state),
                    const _CalendarTabs(),
                    Expanded(child: _CalendarBody(state: state)),
                  ],
                ),
              ),
              floatingActionButton: Padding(
                padding: EdgeInsets.only(bottom: hasBottomNavigation ? 76 : 0),
                child: FloatingActionButton.extended(
                  onPressed: state is CalendarDisplay
                      ? () => context.read<CalendarBloc>().add(
                          const CalendarAddFormRequested(),
                        )
                      : null,
                  icon: const Icon(Icons.add),
                  label: const Text('Новая задача'),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _openAddTaskSheet(BuildContext context) async {
    final draft = await showModalBottomSheet<NewTaskDraft>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: false,
      backgroundColor: Colors.transparent,
      barrierColor: AppColors.forest950.withValues(alpha: 0.58),
      builder: (_) => const AddTaskSheet(),
    );
    if (!context.mounted) return;

    context.read<CalendarBloc>().add(
      draft == null
          ? const CalendarAddCancelled()
          : CalendarTaskSubmitted(draft),
    );
  }
}

class _CalendarHero extends StatelessWidget {
  const _CalendarHero({required this.state});

  final CalendarState state;

  @override
  Widget build(BuildContext context) {
    final snapshot = state.snapshot;
    final tasks = snapshot == null
        ? const <TaskItem>[]
        : [...snapshot.deadlineTasks, ...snapshot.timelessTasks];
    final completed = tasks.where((task) => task.isCompleted).length;
    final active = tasks.length - completed;
    final progress = tasks.isEmpty ? 0.0 : completed / tasks.length;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
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
            right: -34,
            top: -44,
            child: _HeroOrb(size: 150, color: Color(0x183F9373)),
          ),
          const Positioned(
            right: 66,
            bottom: -54,
            child: _HeroOrb(size: 110, color: Color(0x16F0BD5B)),
          ),
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 540;
              final title = Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: const BoxDecoration(
                      gradient: AppColors.goldGradient,
                      borderRadius: BorderRadius.all(Radius.circular(17)),
                    ),
                    child: const Icon(
                      Icons.auto_awesome_rounded,
                      color: AppColors.forest950,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ШТАБ ИМПЕРИИ',
                          style: TextStyle(
                            color: AppColors.gold400,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.7,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'План на победу',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                          ),
                        ),
                        Text(
                          'Каждая задача укрепляет ваш город',
                          style: TextStyle(color: Colors.white60, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              );
              final stats = _HeroProgress(
                active: active,
                completed: completed,
                progress: progress,
              );

              if (compact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [title, const SizedBox(height: 18), stats],
                );
              }
              return Row(
                children: [
                  Expanded(flex: 3, child: title),
                  const SizedBox(width: 26),
                  Expanded(flex: 2, child: stats),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _HeroProgress extends StatelessWidget {
  const _HeroProgress({
    required this.active,
    required this.completed,
    required this.progress,
  });

  final int active;
  final int completed;
  final double progress;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.09)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              _HeroStat(value: '$active', label: 'активно'),
              Container(
                width: 1,
                height: 32,
                margin: const EdgeInsets.symmetric(horizontal: 16),
                color: Colors.white12,
              ),
              _HeroStat(value: '$completed', label: 'готово'),
              const Spacer(),
              Text(
                '${(progress * 100).round()}%',
                style: const TextStyle(
                  color: AppColors.gold400,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 11),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 7,
              color: AppColors.gold400,
              backgroundColor: Colors.white12,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  const _HeroStat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
        Text(
          label,
          style: const TextStyle(color: Colors.white54, fontSize: 10),
        ),
      ],
    );
  }
}

class _HeroOrb extends StatelessWidget {
  const _HeroOrb({required this.size, required this.color});

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

class _CalendarTabs extends StatelessWidget {
  const _CalendarTabs();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFE4DED1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: TabBar(
        dividerColor: Colors.transparent,
        indicatorSize: TabBarIndicatorSize.tab,
        indicator: BoxDecoration(
          color: AppColors.paper,
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [
            BoxShadow(
              color: Color(0x160E2924),
              blurRadius: 8,
              offset: Offset(0, 3),
            ),
          ],
        ),
        labelColor: AppColors.forest900,
        unselectedLabelColor: AppColors.mutedInk,
        labelStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
        unselectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
        tabs: const [
          Tab(text: 'С дедлайном'),
          Tab(text: 'Без срока'),
        ],
      ),
    );
  }
}

class _CalendarBody extends StatelessWidget {
  const _CalendarBody({required this.state});

  final CalendarState state;

  @override
  Widget build(BuildContext context) {
    final snapshot = state.snapshot;

    if (snapshot == null) {
      if (state case CalendarFailure(:final message)) {
        return _FailureView(message: message);
      }
      return const Center(child: CircularProgressIndicator());
    }

    final completingTaskId = state is CalendarCompleting
        ? (state as CalendarCompleting).taskId
        : null;

    return Stack(
      children: [
        TabBarView(
          children: [
            TaskList(
              tasks: snapshot.deadlineTasks,
              emptyTitle: 'Нет задач с дедлайном',
              emptyDescription:
                  'Добавьте задачу и включите переключатель дедлайна.',
              completingTaskId: completingTaskId,
              interactionEnabled: state is CalendarDisplay,
              onRefresh: () => _refresh(context),
              onComplete: (taskId) => _complete(context, taskId),
            ),
            TaskList(
              tasks: snapshot.timelessTasks,
              emptyTitle: 'Нет бессрочных планов',
              emptyDescription:
                  'Здесь появятся задачи, которым не назначена дата.',
              completingTaskId: completingTaskId,
              interactionEnabled: state is CalendarDisplay,
              onRefresh: () => _refresh(context),
              onComplete: (taskId) => _complete(context, taskId),
            ),
          ],
        ),
        if (state is CalendarLoading)
          const Align(
            alignment: Alignment.topCenter,
            child: LinearProgressIndicator(minHeight: 2),
          ),
        if (state case CalendarAdding(isSubmitting: true)) ...[
          const ModalBarrier(dismissible: false, color: Color(0x33000000)),
          const Center(
            child: Card(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(width: 16),
                    Text('Добавляем задачу…'),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  void _complete(BuildContext context, String taskId) {
    context.read<CalendarBloc>().add(CalendarTaskCompletionRequested(taskId));
  }

  Future<void> _refresh(BuildContext context) async {
    final bloc = context.read<CalendarBloc>();
    if (bloc.state is CalendarAdding ||
        bloc.state is CalendarCompleting ||
        bloc.state is CalendarLoading) {
      return;
    }

    bloc.add(const CalendarRefreshRequested());
    try {
      await bloc.stream
          .firstWhere(
            (state) => state is CalendarDisplay || state is CalendarFailure,
          )
          .timeout(const Duration(seconds: 20));
    } on TimeoutException {
      // The BLoC keeps ownership of the active request and will update the UI
      // when it finishes; the pull-to-refresh indicator may safely stop.
    }
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
                  context.read<CalendarBloc>().add(const CalendarStarted()),
              icon: const Icon(Icons.refresh),
              label: const Text('Повторить'),
            ),
          ],
        ),
      ),
    );
  }
}
