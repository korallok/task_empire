import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:task_empire/core/theme/app_theme.dart';
import 'package:task_empire/features/calendar/data/task_item.dart';

class AddTaskSheet extends StatefulWidget {
  const AddTaskSheet({super.key});

  @override
  State<AddTaskSheet> createState() => _AddTaskSheetState();
}

class _AddTaskSheetState extends State<AddTaskSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  bool _hasDeadline = false;
  DateTime? _deadline;

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: AppColors.paper,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        child: AnimatedPadding(
          duration: const Duration(milliseconds: 180),
          padding: EdgeInsets.only(
            left: 20,
            top: 12,
            right: 20,
            bottom: MediaQuery.viewInsetsOf(context).bottom + 20,
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
                        color: theme.colorScheme.outlineVariant,
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
                          Icons.add_task_rounded,
                          color: AppColors.forest950,
                        ),
                      ),
                      const SizedBox(width: 13),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'НОВАЯ МИССИЯ',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: AppColors.gold600,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.4,
                              ),
                            ),
                            Text(
                              'Добавить задачу',
                              style: theme.textTheme.headlineSmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _titleController,
                    autofocus: true,
                    minLines: 2,
                    maxLines: 4,
                    maxLength: 500,
                    textInputAction: TextInputAction.done,
                    decoration: const InputDecoration(
                      labelText: 'Что нужно сделать?',
                      hintText: 'Например: подготовить презентацию к встрече',
                    ),
                    validator: (value) {
                      final title = value?.trim() ?? '';
                      if (title.isEmpty) return 'Введите название задачи';
                      if (title.length > 500) return 'Не более 500 символов';
                      return null;
                    },
                    onFieldSubmitted: (_) => _submit(),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Material(
                      color: AppColors.parchment,
                      borderRadius: BorderRadius.circular(18),
                      clipBehavior: Clip.antiAlias,
                      child: SwitchListTile.adaptive(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                        ),
                        activeTrackColor: AppColors.forest500,
                        title: const Text(
                          'Добавить дедлайн',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                        subtitle: const Text('Указать дату и точное время'),
                        value: _hasDeadline,
                        onChanged: _toggleDeadline,
                      ),
                    ),
                  ),
                  if (_hasDeadline) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _pickDate,
                            icon: const Icon(Icons.calendar_month_outlined),
                            label: Text(
                              DateFormat('d MMMM y', 'ru').format(_deadline!),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _pickTime,
                            icon: const Icon(Icons.schedule_outlined),
                            label: Text(DateFormat('HH:mm').format(_deadline!)),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    key: const ValueKey('submit-task'),
                    onPressed: _submit,
                    icon: const Icon(Icons.add_task),
                    label: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text('Добавить задачу'),
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

  void _toggleDeadline(bool enabled) {
    setState(() {
      _hasDeadline = enabled;
      if (enabled && _deadline == null) {
        final nextHour = DateTime.now().add(const Duration(hours: 1));
        _deadline = DateTime(
          nextHour.year,
          nextHour.month,
          nextHour.day,
          nextHour.hour,
        );
      }
    });
  }

  Future<void> _pickDate() async {
    final current = _deadline!;
    final today = DateUtils.dateOnly(DateTime.now());
    final selected = await showDatePicker(
      context: context,
      initialDate: current.isBefore(today) ? today : current,
      firstDate: today,
      lastDate: DateTime(today.year + 20),
    );
    if (selected == null || !mounted) return;

    setState(() {
      _deadline = DateTime(
        selected.year,
        selected.month,
        selected.day,
        current.hour,
        current.minute,
      );
    });
  }

  Future<void> _pickTime() async {
    final current = _deadline!;
    final selected = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current),
    );
    if (selected == null || !mounted) return;

    setState(() {
      _deadline = DateTime(
        current.year,
        current.month,
        current.day,
        selected.hour,
        selected.minute,
      );
    });
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    Navigator.of(context).pop(
      NewTaskDraft(
        title: _titleController.text.trim(),
        deadline: _hasDeadline ? _deadline : null,
      ),
    );
  }
}
