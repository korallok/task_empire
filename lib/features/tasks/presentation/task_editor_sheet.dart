import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:task_empire/core/theme/app_theme.dart';
import 'package:task_empire/features/tasks/domain/task_models.dart';

class TaskEditorSheet extends StatefulWidget {
  const TaskEditorSheet({required this.initialDate, this.original, super.key});

  final DateTime initialDate;
  final EmpireTask? original;

  @override
  State<TaskEditorSheet> createState() => _TaskEditorSheetState();
}

class _TaskEditorSheetState extends State<TaskEditorSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late TaskCategory _category;
  late TaskDifficulty _difficulty;
  late final TaskVerificationMode _verificationMode;
  late DateTime _scheduledDate;
  DateTime? _deadline;

  @override
  void initState() {
    super.initState();
    final original = widget.original;
    _titleController = TextEditingController(text: original?.title ?? '');
    _descriptionController = TextEditingController(
      text: original?.description ?? '',
    );
    _category = original?.category ?? TaskCategory.personal;
    _difficulty = original?.difficulty ?? TaskDifficulty.normal;
    _verificationMode = original?.verificationMode ?? TaskVerificationMode.none;
    _scheduledDate = dateOnly(original?.scheduledDate ?? widget.initialDate);
    _deadline = original?.deadline;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.paper,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            18,
            10,
            18,
            18 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
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
                        width: 48,
                        height: 48,
                        decoration: const BoxDecoration(
                          gradient: AppColors.goldGradient,
                          borderRadius: BorderRadius.all(Radius.circular(15)),
                        ),
                        child: const Icon(
                          Icons.flag_rounded,
                          color: AppColors.forest950,
                        ),
                      ),
                      const SizedBox(width: 13),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'РЕАЛЬНАЯ ЦЕЛЬ',
                              style: TextStyle(
                                color: AppColors.gold600,
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.3,
                              ),
                            ),
                            Text(
                              widget.original == null
                                  ? 'Новая задача'
                                  : 'Изменить задачу',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Закрыть',
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  TextFormField(
                    key: const ValueKey('task-title-field'),
                    controller: _titleController,
                    autofocus: widget.original == null,
                    textInputAction: TextInputAction.next,
                    maxLength: 500,
                    decoration: const InputDecoration(
                      labelText: 'Название',
                      hintText: 'Например, закончить курсовую',
                      prefixIcon: Icon(Icons.edit_note_rounded),
                    ),
                    validator: (value) {
                      final length = value?.trim().length ?? 0;
                      if (length == 0) return 'Введите название задачи';
                      if (length > 500) return 'Не более 500 символов';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _descriptionController,
                    minLines: 2,
                    maxLines: 4,
                    maxLength: 4000,
                    decoration: const InputDecoration(
                      labelText: 'Описание',
                      hintText: 'Что именно должно быть готово?',
                      alignLabelWithHint: true,
                      prefixIcon: Icon(Icons.subject_rounded),
                    ),
                  ),
                  const SizedBox(height: 12),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final compact = constraints.maxWidth < 520;
                      final category = DropdownButtonFormField<TaskCategory>(
                        initialValue: _category,
                        decoration: const InputDecoration(
                          labelText: 'Категория',
                          prefixIcon: Icon(Icons.folder_outlined),
                        ),
                        items: [
                          for (final category in TaskCategory.values)
                            DropdownMenuItem(
                              value: category,
                              child: Text(category.displayName),
                            ),
                        ],
                        onChanged: (value) {
                          if (value != null) setState(() => _category = value);
                        },
                      );
                      final difficulty =
                          DropdownButtonFormField<TaskDifficulty>(
                            initialValue: _difficulty,
                            decoration: const InputDecoration(
                              labelText: 'Сложность',
                              prefixIcon: Icon(Icons.bolt_rounded),
                            ),
                            items: [
                              for (final difficulty in TaskDifficulty.values)
                                DropdownMenuItem(
                                  value: difficulty,
                                  child: Text(difficulty.displayName),
                                ),
                            ],
                            onChanged: (value) {
                              if (value != null) {
                                setState(() => _difficulty = value);
                              }
                            },
                          );
                      if (compact) {
                        return Column(
                          children: [
                            category,
                            const SizedBox(height: 12),
                            difficulty,
                          ],
                        );
                      }
                      return Row(
                        children: [
                          Expanded(child: category),
                          const SizedBox(width: 12),
                          Expanded(child: difficulty),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  _DateAction(
                    icon: Icons.calendar_today_rounded,
                    label: 'Запланировано',
                    value: DateFormat('d MMMM y', 'ru').format(_scheduledDate),
                    onTap: _pickScheduledDate,
                  ),
                  const SizedBox(height: 10),
                  _DateAction(
                    icon: Icons.alarm_rounded,
                    label: 'Дедлайн',
                    value: _deadline == null
                        ? 'Без дедлайна'
                        : DateFormat('d MMM, HH:mm', 'ru').format(_deadline!),
                    onTap: _pickDeadline,
                    onClear: _deadline == null
                        ? null
                        : () => setState(() => _deadline = null),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.mint200.withValues(alpha: 0.52),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.redeem_rounded,
                          color: AppColors.forest700,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Награда: ${_difficulty.xpReward} XP и '
                            '${_difficulty.goldReward} золота',
                            style: const TextStyle(
                              color: AppColors.forest900,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  ListTile(
                    enabled: false,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                    leading: const Icon(Icons.auto_awesome_rounded),
                    title: const Text('AI-подтверждение — позже'),
                    subtitle: Text(
                      _verificationMode == TaskVerificationMode.ai
                          ? 'Режим этой задачи сохранён, но отправка '
                                'подтверждения пока недоступна.'
                          : 'Опциональный режим появится после подключения '
                                'загрузки доказательств.',
                    ),
                    trailing: Switch(
                      value: _verificationMode == TaskVerificationMode.ai,
                      onChanged: null,
                    ),
                  ),
                  const SizedBox(height: 14),
                  FilledButton.icon(
                    key: const ValueKey('submit-task'),
                    onPressed: _submit,
                    icon: Icon(
                      widget.original == null
                          ? Icons.add_task_rounded
                          : Icons.save_rounded,
                    ),
                    label: Text(
                      widget.original == null ? 'Создать задачу' : 'Сохранить',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickScheduledDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _scheduledDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      helpText: 'Дата задачи',
    );
    if (selected == null || !mounted) return;
    setState(() {
      _scheduledDate = dateOnly(selected);
      if (_deadline != null && dateOnly(_deadline!).isBefore(_scheduledDate)) {
        _deadline = null;
      }
    });
  }

  Future<void> _pickDeadline() async {
    final initial =
        _deadline ??
        DateTime(
          _scheduledDate.year,
          _scheduledDate.month,
          _scheduledDate.day,
          20,
        );
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(_scheduledDate) ? _scheduledDate : initial,
      firstDate: _scheduledDate,
      lastDate: DateTime(2100),
      helpText: 'Дата дедлайна',
    );
    if (selectedDate == null || !mounted) return;
    final selectedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
      helpText: 'Время дедлайна',
    );
    if (selectedTime == null || !mounted) return;
    setState(() {
      _deadline = DateTime(
        selectedDate.year,
        selectedDate.month,
        selectedDate.day,
        selectedTime.hour,
        selectedTime.minute,
      );
    });
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_deadline != null &&
        dateOnly(_deadline!).isBefore(dateOnly(_scheduledDate))) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Дедлайн не может быть раньше даты задачи.'),
        ),
      );
      return;
    }
    Navigator.pop(
      context,
      TaskDraft(
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        category: _category,
        difficulty: _difficulty,
        scheduledDate: _scheduledDate,
        deadline: _deadline,
        verificationMode: _verificationMode,
      ),
    );
  }
}

class _DateAction extends StatelessWidget {
  const _DateAction({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
    this.onClear,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF4F0E7),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0x140E2924)),
      ),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        onTap: onTap,
        leading: Icon(icon, color: AppColors.forest700),
        title: Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text(value),
        trailing: onClear == null
            ? const Icon(Icons.chevron_right_rounded)
            : IconButton(
                tooltip: 'Убрать дедлайн',
                onPressed: onClear,
                icon: const Icon(Icons.close_rounded),
              ),
      ),
    );
  }
}
