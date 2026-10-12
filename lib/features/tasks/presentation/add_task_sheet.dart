import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/date_utils.dart';
import '../application/list_controller.dart';
import '../application/reminder_providers.dart';
import '../application/task_controller.dart';
import '../domain/quick_add.dart';
import '../domain/recurrence.dart';
import '../domain/reminder.dart';
import '../domain/tag.dart';
import '../domain/task.dart';
import '../domain/task_list.dart';
import 'quick_add_widgets.dart';
import 'reminder_sheet.dart';
import 'repeat_sheet.dart';
import 'tag_dialog.dart';
import 'task_tile.dart';

/// [due]/[hasTime] pre-fill the sheet (used by the calendar).
/// Without them, defaults follow the view the user is looking at.
Future<void> showAddTaskSheet(BuildContext context,
        {DateTime? due, bool hasTime = false}) =>
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _AddTaskSheet(initialDue: due, initialHasTime: hasTime),
    );

class _AddTaskSheet extends ConsumerStatefulWidget {
  final DateTime? initialDue;
  final bool initialHasTime;
  const _AddTaskSheet({this.initialDue, this.initialHasTime = false});
  @override
  ConsumerState<_AddTaskSheet> createState() => _AddTaskSheetState();
}

class _AddTaskSheetState extends ConsumerState<_AddTaskSheet> {
  final _title = TextEditingController();
  DateTime? _due;
  bool _hasTime = false;
  Priority _priority = Priority.none;
  List<int> _reminders = [];
  Recurrence? _repeat;
  final List<String> _tags = [];
  String _listId = inboxId;
  final Set<QuickKind> _ignored = {}; // quick-add details the user switched off

  @override
  void initState() {
    super.initState();
    final sel = ref.read(selectedViewProvider);
    if (sel.listId != null) _listId = sel.listId!;
    if (sel.tag != null) _tags.add(sel.tag!);
    if (widget.initialDue != null) {
      _due = widget.initialDue;
      _hasTime = widget.initialHasTime;
    } else if (sel.smart == SmartView.today) {
      _due = dateOnly(DateTime.now());
    }
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  List<QuickList> _quickLists() => [
        for (final l in ref.read(listControllerProvider).value ?? <TaskList>[])
          (id: l.id, name: l.name)
      ];

  /// Sets the day, keeping the time-of-day if one was chosen.
  void _setDate(DateTime d) =>
      setState(() => _due = withDay(_due, d, keepTime: _hasTime));

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _due ?? now,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 3650)),
    );
    if (d != null) _setDate(d);
  }

  Future<void> _pickTime() async {
    final tm = await showTimePicker(
      context: context,
      initialTime: _hasTime && _due != null
          ? TimeOfDay.fromDateTime(_due!)
          : TimeOfDay.now(),
    );
    if (tm != null) {
      setState(() {
        _due = withTime(_due, tm.hour, tm.minute);
        _hasTime = true;
      });
    }
  }

  void _submit() {
    final raw = _title.text.trim();
    if (raw.isEmpty) return;

    // Quick add: details typed into the title win over the chips below.
    // If nothing would be left as a title, keep the text exactly as typed.
    var parsed = parseQuickAdd(raw, DateTime.now(), lists: _quickLists(), ignore: _ignored);
    final usePhrase = parsed.title.isNotEmpty;
    if (!usePhrase) parsed = const QuickAddResult(title: '');

    final due = parsed.due ?? _due;
    final hasTime = parsed.due != null ? parsed.hasTime : _hasTime;
    final reminders = parsed.reminders.isNotEmpty ? parsed.reminders : _reminders;

    ref.read(taskControllerProvider.notifier).add(
          usePhrase ? parsed.title : raw,
          due: due,
          hasTime: due == null ? false : hasTime,
          durationMinutes: due == null ? null : parsed.durationMinutes,
          reminders: due == null ? const [] : reminders,
          recurrence: due == null ? null : (parsed.recurrence ?? _repeat),
          tags: {..._tags, ...parsed.tags}.toList(),
          priority: parsed.priority ?? _priority,
          listId: parsed.listId ?? _listId,
        );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final lists = ref.watch(listControllerProvider).value ?? [TaskList.inbox()];
    final current =
        lists.firstWhere((l) => l.id == _listId, orElse: () => TaskList.inbox());
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;

    // Everything quick add can read from the text (chips), and what it will apply.
    final detected = parseQuickAdd(_title.text, now, lists: _quickLists());
    final typed = _title.text.trim().isNotEmpty;

    return Padding(
      padding: EdgeInsets.fromLTRB(
          16, 16, 16, MediaQuery.of(context).viewInsets.bottom + 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _title,
            autofocus: true,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w600),
            decoration: const InputDecoration(
                hintText: 'What would you like to do?', border: InputBorder.none),
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _submit(),
          ),
          if (!typed)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(children: [
                Expanded(
                  child: Text('Try: Dentist friday 3pm #health !high',
                      style: TextStyle(fontSize: 12, color: muted)),
                ),
                TextButton(
                  onPressed: () => showQuickAddHelp(context),
                  child: const Text('Quick add tips'),
                ),
              ]),
            ),
          QuickAddChips(
            detected: detected,
            ignored: _ignored,
            onToggle: (k) =>
                setState(() => _ignored.contains(k) ? _ignored.remove(k) : _ignored.add(k)),
          ),
          Wrap(
            spacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ChoiceChip(
                label: const Text('Today'),
                selected: _due != null && isSameDay(_due!, now),
                onSelected: (_) => _setDate(now),
              ),
              ChoiceChip(
                label: const Text('Tomorrow'),
                selected: _due != null && isSameDay(_due!, tomorrow),
                onSelected: (_) => _setDate(tomorrow),
              ),
              ActionChip(
                avatar: const Icon(Icons.event, size: 18),
                label: Text(_due == null ? 'Date' : DateFormat.MMMd().format(_due!)),
                onPressed: _pickDate,
              ),
              InputChip(
                avatar: const Icon(Icons.schedule, size: 18),
                label: Text(_hasTime ? DateFormat.jm().format(_due!) : 'Time'),
                onPressed: _pickTime,
                onDeleted: _hasTime
                    ? () => setState(() {
                          _due = dateOnly(_due!);
                          _hasTime = false;
                          _reminders = _reminders
                              .where(reminderPresetsFor(false).contains)
                              .toList();
                        })
                    : null,
              ),
              for (final tag in _tags)
                InputChip(
                    label: Text('#$tag'),
                    onDeleted: () => setState(() => _tags.remove(tag))),
              ActionChip(
                avatar: const Icon(Icons.tag, size: 18),
                label: const Text('Tag'),
                onPressed: () async {
                  final raw = await showTagDialog(
                    context,
                    title: 'Add tag',
                    suggestions: [
                      for (final (name, _) in ref.read(allTagsProvider))
                        if (!_tags.contains(name)) name
                    ],
                  );
                  final tag = raw == null ? '' : normalizeTag(raw);
                  if (!mounted || tag.isEmpty || _tags.contains(tag)) return;
                  setState(() => _tags.add(tag));
                },
              ),
              InputChip(
                avatar: const Icon(Icons.repeat, size: 18),
                label: Text(_repeat?.label ?? 'Repeat'),
                onPressed: _due == null
                    ? null
                    : () => showRepeatSheet(
                          context,
                          current: _repeat,
                          onSelected: (r) => setState(() {
                            _repeat = r;
                            if (r != null && _due != null) _due = r.alignDue(_due!);
                          }),
                        ),
                onDeleted: _repeat == null ? null : () => setState(() => _repeat = null),
              ),
              for (final m in _reminders)
                InputChip(
                  avatar: const Icon(Icons.notifications_active_rounded, size: 18),
                  label: Text(reminderLabel(m, hasTime: _hasTime)),
                  onDeleted: () => setState(() => _reminders.remove(m)),
                ),
              ActionChip(
                avatar: const Icon(Icons.notifications_none, size: 18),
                label: Text(_reminders.isEmpty ? 'Remind' : 'Add reminder'),
                onPressed: _due == null
                    ? null
                    : () => showReminderSheet(
                          context,
                          hasTime: _hasTime,
                          taken: _reminders.toSet(),
                          onSelected: (m) {
                            setState(() => _reminders = withReminder(_reminders, m));
                            ref.read(reminderSchedulerProvider).requestPermission();
                          },
                        ),
              ),
              PopupMenuButton<Priority>(
                onSelected: (p) => setState(() => _priority = p),
                itemBuilder: (_) => [
                  for (final p in Priority.values)
                    PopupMenuItem(value: p, child: Text(p.name)),
                ],
                child: Chip(
                  avatar: Icon(Icons.flag, size: 18, color: priorityColor(_priority)),
                  label: Text(_priority.name),
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (id) => setState(() => _listId = id),
                itemBuilder: (_) => [
                  for (final l in lists) PopupMenuItem(value: l.id, child: Text(l.name)),
                ],
                child: Chip(
                  avatar: Icon(Icons.circle, size: 12, color: Color(current.color)),
                  label: Text(current.name),
                ),
              ),
            ],
          ),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: _submit,
              icon: const Icon(Icons.arrow_upward_rounded),
              label: const Text('Add task'),
            ),
          ),
        ],
      ),
    );
  }
}
