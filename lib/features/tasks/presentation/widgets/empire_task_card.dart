import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:task_empire/core/theme/app_theme.dart';
import 'package:task_empire/features/tasks/domain/task_models.dart';

class EmpireTaskCard extends StatelessWidget {
  const EmpireTaskCard({
    required this.task,
    required this.onComplete,
    required this.onEdit,
    required this.onDelete,
    this.isBusy = false,
    this.isEnabled = true,
    super.key,
  });

  final EmpireTask task;
  final VoidCallback onComplete;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final bool isBusy;
  final bool isEnabled;

  @override
  Widget build(BuildContext context) {
    final accent = _categoryColor(task.category);
    final now = DateTime.now();
    final isOverdue =
        !task.isCompleted &&
        task.deadline != null &&
        task.deadline!.isBefore(now);

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 180),
      opacity: task.isCompleted ? 0.68 : 1,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.paper,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: accent.withValues(alpha: 0.18)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x110E2924),
              blurRadius: 18,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 5,
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: const BorderRadius.horizontal(
                    left: Radius.circular(22),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 14, 8, 14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _CompletionButton(
                        task: task,
                        isBusy: isBusy,
                        isEnabled: isEnabled,
                        accent: accent,
                        onPressed: onComplete,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Text(
                                    task.title,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(
                                          decoration: task.isCompleted
                                              ? TextDecoration.lineThrough
                                              : null,
                                        ),
                                  ),
                                ),
                                if (!task.isCompleted)
                                  PopupMenuButton<_TaskMenuAction>(
                                    tooltip: 'Действия с задачей',
                                    padding: EdgeInsets.zero,
                                    enabled: isEnabled && !isBusy,
                                    onSelected: (action) {
                                      switch (action) {
                                        case _TaskMenuAction.edit:
                                          onEdit();
                                        case _TaskMenuAction.delete:
                                          onDelete();
                                      }
                                    },
                                    itemBuilder: (_) => const [
                                      PopupMenuItem(
                                        value: _TaskMenuAction.edit,
                                        child: ListTile(
                                          contentPadding: EdgeInsets.zero,
                                          leading: Icon(Icons.edit_outlined),
                                          title: Text('Изменить'),
                                        ),
                                      ),
                                      PopupMenuItem(
                                        value: _TaskMenuAction.delete,
                                        child: ListTile(
                                          contentPadding: EdgeInsets.zero,
                                          leading: Icon(Icons.delete_outline),
                                          title: Text('Удалить'),
                                        ),
                                      ),
                                    ],
                                    icon: const Icon(Icons.more_horiz_rounded),
                                  ),
                              ],
                            ),
                            if (task.description.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                task.description,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: AppColors.mutedInk,
                                  fontSize: 12,
                                  height: 1.35,
                                ),
                              ),
                            ],
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 7,
                              runSpacing: 7,
                              children: [
                                _MetaChip(
                                  icon: _categoryIcon(task.category),
                                  label: task.category.displayName,
                                  color: accent,
                                ),
                                _MetaChip(
                                  icon: Icons.bolt_rounded,
                                  label:
                                      '${task.difficulty.displayName} · '
                                      '${task.difficulty.xpReward} XP · '
                                      '${task.difficulty.goldReward} зол.',
                                  color: _difficultyColor(task.difficulty),
                                ),
                                if (task.deadline != null)
                                  _MetaChip(
                                    icon: isOverdue
                                        ? Icons.warning_amber_rounded
                                        : Icons.schedule_rounded,
                                    label: DateFormat(
                                      'd MMM, HH:mm',
                                      'ru',
                                    ).format(task.deadline!),
                                    color: isOverdue
                                        ? AppColors.danger
                                        : AppColors.mutedInk,
                                  ),
                                if (task.verificationMode ==
                                    TaskVerificationMode.ai)
                                  const _MetaChip(
                                    icon: Icons.auto_awesome_rounded,
                                    label: 'AI-проверка пока недоступна',
                                    color: Color(0xFF7656A8),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _TaskMenuAction { edit, delete }

class _CompletionButton extends StatelessWidget {
  const _CompletionButton({
    required this.task,
    required this.isBusy,
    required this.isEnabled,
    required this.accent,
    required this.onPressed,
  });

  final EmpireTask task;
  final bool isBusy;
  final bool isEnabled;
  final Color accent;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final requiresAi = task.verificationMode == TaskVerificationMode.ai;
    final canComplete = isEnabled && !task.isCompleted && !requiresAi;
    return SizedBox.square(
      dimension: 48,
      child: isBusy
          ? Padding(
              padding: const EdgeInsets.all(11),
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: accent,
                semanticsLabel: 'Завершение задачи «${task.title}»',
              ),
            )
          : IconButton(
              key: ValueKey('complete-task-${task.id}'),
              tooltip: task.isCompleted
                  ? 'Задача выполнена'
                  : requiresAi
                  ? 'AI-подтверждение пока недоступно'
                  : 'Выполнить задачу',
              onPressed: canComplete ? onPressed : null,
              style: IconButton.styleFrom(
                backgroundColor: accent.withValues(alpha: 0.1),
                foregroundColor: accent,
                disabledBackgroundColor: accent.withValues(alpha: 0.1),
                disabledForegroundColor: task.isCompleted
                    ? accent
                    : AppColors.mutedInk,
              ),
              icon: Icon(
                task.isCompleted
                    ? Icons.check_rounded
                    : requiresAi
                    ? Icons.lock_clock_outlined
                    : Icons.radio_button_unchecked_rounded,
              ),
            ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

IconData _categoryIcon(TaskCategory category) => switch (category) {
  TaskCategory.study => Icons.school_outlined,
  TaskCategory.work => Icons.work_outline_rounded,
  TaskCategory.personal => Icons.person_outline_rounded,
  TaskCategory.health => Icons.favorite_outline_rounded,
};

Color _categoryColor(TaskCategory category) => switch (category) {
  TaskCategory.study => const Color(0xFF3D78A8),
  TaskCategory.work => const Color(0xFF7656A8),
  TaskCategory.personal => AppColors.gold600,
  TaskCategory.health => AppColors.forest700,
};

Color _difficultyColor(TaskDifficulty difficulty) => switch (difficulty) {
  TaskDifficulty.easy => AppColors.forest700,
  TaskDifficulty.normal => const Color(0xFF3D78A8),
  TaskDifficulty.hard => AppColors.danger,
};
