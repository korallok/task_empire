import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:task_empire/core/theme/app_theme.dart';
import 'package:task_empire/features/tasks/bloc/tasks_bloc.dart';
import 'package:task_empire/features/tasks/domain/task_models.dart';
import 'package:task_empire/features/tasks/presentation/task_editor_sheet.dart';
import 'package:task_empire/features/tasks/presentation/widgets/empire_task_card.dart';

class TasksEffects extends StatelessWidget {
  const TasksEffects({required this.isActive, required this.child, super.key});

  final bool isActive;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return BlocListener<TasksBloc, TasksState>(
      listenWhen: (previous, current) {
        if (!isActive) return false;
        final editorOpened =
            previous is! TasksEditing && current is TasksEditing;
        final feedbackReady =
            current is TasksDisplay && current.feedback != null;
        return editorOpened || feedbackReady;
      },
      listener: (context, state) {
        if (state is TasksEditing && !state.isSubmitting) {
          unawaited(_openEditor(context, state));
        }
        if (state case TasksDisplay(:final feedback?)) {
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
      child: child,
    );
  }

  Future<void> _openEditor(BuildContext context, TasksEditing state) async {
    final draft = await showModalBottomSheet<TaskDraft>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: AppColors.forest950.withValues(alpha: 0.58),
      builder: (_) => TaskEditorSheet(
        initialDate: state.initialDate,
        original: state.original,
      ),
    );
    if (!context.mounted) return;
    context.read<TasksBloc>().add(
      draft == null ? const TasksEditorCancelled() : TasksSaved(draft),
    );
  }
}

class TaskCards extends StatelessWidget {
  const TaskCards({
    required this.tasks,
    required this.state,
    required this.emptyTitle,
    required this.emptyDescription,
    super.key,
  });

  final List<EmpireTask> tasks;
  final TasksState state;
  final String emptyTitle;
  final String emptyDescription;

  @override
  Widget build(BuildContext context) {
    if (tasks.isEmpty) {
      return TasksEmptyState(title: emptyTitle, description: emptyDescription);
    }

    final busyId = state is TasksOperationInProgress
        ? (state as TasksOperationInProgress).taskId
        : null;
    final actionsEnabled = state is TasksDisplay;
    return Column(
      children: [
        for (var index = 0; index < tasks.length; index++) ...[
          EmpireTaskCard(
            task: tasks[index],
            isBusy: busyId == tasks[index].id,
            isEnabled: actionsEnabled,
            onComplete: () => context.read<TasksBloc>().add(
              TasksCompletionRequested(tasks[index].id),
            ),
            onEdit: () =>
                context.read<TasksBloc>().add(TasksEditRequested(tasks[index])),
            onDelete: () => _confirmDelete(context, tasks[index]),
          ),
          if (index != tasks.length - 1) const SizedBox(height: 10),
        ],
      ],
    );
  }

  Future<void> _confirmDelete(BuildContext context, EmpireTask task) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Удалить задачу?'),
        content: Text('«${task.title}» будет удалена без начисления награды.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      context.read<TasksBloc>().add(TasksDeleteRequested(task.id));
    }
  }
}

class TasksEmptyState extends StatelessWidget {
  const TasksEmptyState({
    required this.title,
    required this.description,
    super.key,
  });

  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 220),
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: AppColors.paper.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: const Color(0x140E2924)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 68,
            height: 68,
            decoration: const BoxDecoration(
              gradient: AppColors.goldGradient,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.flag_outlined,
              color: AppColors.forest950,
              size: 32,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 7),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Text(
              description,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.mutedInk, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

class TasksFailureView extends StatelessWidget {
  const TasksFailureView({required this.message, super.key});

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
              size: 54,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 14),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: () =>
                  context.read<TasksBloc>().add(const TasksStarted()),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Повторить'),
            ),
          ],
        ),
      ),
    );
  }
}
