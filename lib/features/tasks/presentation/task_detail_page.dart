import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/date_utils.dart';
import '../../../core/focus_request.dart';
import '../../../core/task_focus_time.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/app_card.dart';
import '../application/list_controller.dart';
import '../application/task_controller.dart';
import '../domain/duration_options.dart';
import '../domain/reminder.dart';
import '../domain/task.dart';
import '../domain/task_list.dart';
import 'date_pickers.dart';
import 'detail_row.dart';
import 'duration_sheet.dart';
import 'markdown_editor.dart';
import 'markdown_view.dart';
import 'reminders_editor.dart';
import 'repeat_sheet.dart';
import 'subtask_sheet.dart';
import 'tag_dialog.dart';
import 'task_tile.dart';

enum _Action { duplicate, wontDo, delete }

String _formatSeconds(int s) {
  final h = s ~/ 3600;
  final m = (s % 3600) ~/ 60;
  return h > 0 ? '${h}h ${m}m' : '${m}m';
}

class TaskDetailPage extends ConsumerStatefulWidget {
  final String taskId;
  const TaskDetailPage({super.key, required this.taskId});
  @override
  ConsumerState<TaskDetailPage> createState() => _TaskDetailPageState();
}

class _TaskDetailPageState extends ConsumerState<TaskDetailPage> {
  late final TextEditingController _title;
  late final TextEditingController _notes;
  final _sub = TextEditingController();
  final _subFocus = FocusNode();
  final _comment = TextEditingController();
  bool _editingNotes = false;

  @override
  void initState() {
    super.initState();
    final t = ref.read(taskByIdProvider(widget.taskId));
    _title = TextEditingController(text: t?.title ?? '');
    _notes = TextEditingController(text: t?.notes ?? '');
  }

  @override
  void dispose() {
    _title.dispose();
    _notes.dispose();
    _sub.dispose();
    _subFocus.dispose();
    _comment.dispose();
    super.dispose();
  }

  Future<void> _pickDate(TaskItem task) async {
    final d = await pickDate(context, initial: task.due);
    if (d == null) return;
    ref.read(taskControllerProvider.notifier).edit(task.id,
        (t) => t.copyWith(due: withDay(t.due, d, keepTime: t.hasTime)));
  }

  Future<void> _pickTime(TaskItem task) async {
    final tm = await pickTimeOfDay(context, initial: task.due, hasTime: task.hasTime);
    if (tm == null) return;
    ref.read(taskControllerProvider.notifier).edit(
        task.id,
        (t) =>
            t.copyWith(due: withTime(t.due, tm.hour, tm.minute), hasTime: true));
  }

  Widget _sectionTitle(BuildContext context, String text, {Widget? trailing}) => Row(children: [
        Expanded(
          child: Text(text,
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700)),
        ),
        if (trailing != null) trailing,
      ]);

  @override
  Widget build(BuildContext context) {
    final task = ref.watch(taskByIdProvider(widget.taskId));
    if (task == null) return const Scaffold();
    final ctrl = ref.read(taskControllerProvider.notifier);
    final lists = ref.watch(listControllerProvider).value ?? [TaskList.inbox()];
    final currentList =
        lists.firstWhere((l) => l.id == task.listId, orElse: () => TaskList.inbox());
    final focusSeconds = ref.watch(taskFocusSecondsProvider(task.id));
    final subDone = task.subtasks.where((s) => s.done).length;
    final hasDue = task.due != null;
    final scheme = Theme.of(context).colorScheme;
    final titleStyle = Theme.of(context)
        .textTheme
        .titleLarge
        ?.copyWith(fontWeight: FontWeight.w700);

    String durationText() {
      final m = task.durationMinutes;
      if (m == null) return 'Add duration';
      final end = DateFormat.jm().format(task.due!.add(Duration(minutes: m)));
      return '${durationLabel(m)} · ends $end';
    }

    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            tooltip: 'Focus on this task',
            icon: const Icon(Icons.timer_outlined),
            onPressed: () {
              ref.read(focusRequestProvider.notifier).request(task.id);
              Navigator.of(context).popUntil((r) => r.isFirst);
            },
          ),
          IconButton(
            tooltip: task.pinned ? 'Unpin' : 'Pin to top',
            icon: Icon(task.pinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
                color: task.pinned ? AppColors.orange : null),
            onPressed: () => ctrl.togglePin(task.id),
          ),
          PopupMenuButton<_Action>(
            onSelected: (a) {
              switch (a) {
                case _Action.duplicate:
                  ctrl.duplicate(task.id);
                  Navigator.pop(context);
                case _Action.wontDo:
                  ctrl.setWontDo(task.id, !task.wontDo);
                case _Action.delete:
                  {
                    final messenger = ScaffoldMessenger.of(context);
                    ctrl.remove(task.id);
                    Navigator.pop(context);
                    messenger.showSnackBar(SnackBar(
                      content: const Text('Task deleted'),
                      action: SnackBarAction(
                          label: 'Undo', onPressed: () => ctrl.restore(task)),
                    ));
                  }
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: _Action.duplicate, child: Text('Duplicate')),
              PopupMenuItem(
                  value: _Action.wontDo,
                  child: Text(task.wontDo ? 'Reopen' : "Won't do")),
              const PopupMenuItem(
                  value: _Action.delete,
                  child: Text('Delete', style: TextStyle(color: AppColors.red))),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
        children: [
          // ---- title ----
          AppCard(
            padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                if (task.wontDo)
                  IconButton(
                    icon: const Icon(Icons.do_not_disturb_on_rounded, color: Colors.grey),
                    onPressed: () => ctrl.toggle(task.id),
                  )
                else
                  Checkbox(
                    value: task.done,
                    shape: const CircleBorder(),
                    side: BorderSide(color: priorityColor(task.priority), width: 2),
                    activeColor: priorityColor(task.priority),
                    onChanged: (_) => ctrl.toggle(task.id),
                  ),
                Expanded(
                  child: TextField(
                    controller: _title,
                    style: titleStyle,
                    maxLines: null,
                    decoration: const InputDecoration(
                        border: InputBorder.none, hintText: 'Task title'),
                    onChanged: (v) => ctrl.edit(task.id, (t) => t.copyWith(title: v)),
                  ),
                ),
              ]),
              if (task.wontDo)
                const Padding(
                  padding: EdgeInsets.only(left: 12, bottom: 4),
                  child: Text("Marked as won't do",
                      style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w600)),
                ),
            ]),
          ),
          const SizedBox(height: 12),

          // ---- rich notes ----
          AppCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _sectionTitle(
                context,
                'Notes',
                trailing: _editingNotes
                    ? TextButton(
                        onPressed: () => setState(() => _editingNotes = false),
                        child: const Text('Done'))
                    : IconButton(
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.edit_outlined, size: 20),
                        onPressed: () => setState(() => _editingNotes = true),
                      ),
              ),
              const SizedBox(height: 6),
              if (_editingNotes)
                MarkdownEditor(
                  controller: _notes,
                  autofocus: true,
                  onChanged: (v) => ctrl.edit(task.id, (t) => t.copyWith(notes: v)),
                )
              else if (task.notes.trim().isEmpty)
                InkWell(
                  onTap: () => setState(() => _editingNotes = true),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text('Add notes... (bold, lists and checklists supported)',
                        style: TextStyle(color: scheme.onSurfaceVariant)),
                  ),
                )
              else
                MarkdownView(
                  text: task.notes,
                  onChanged: (v) {
                    _notes.text = v; // keep the editor in sync
                    ctrl.edit(task.id, (t) => t.copyWith(notes: v));
                  },
                ),
            ]),
          ),
          const SizedBox(height: 12),

          // ---- schedule ----
          AppCard(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(children: [
              DetailRow(
                icon: Icons.event_rounded,
                color: AppColors.blue,
                label: hasDue ? DateFormat.yMMMEd().format(task.due!) : 'Add date',
                muted: !hasDue,
                onTap: () => _pickDate(task),
                onClear: hasDue
                    ? () => ctrl.edit(task.id, (t) => t.copyWith(clearDue: true))
                    : null,
              ),
              const Divider(indent: 66),
              DetailRow(
                icon: Icons.schedule_rounded,
                color: AppColors.violet,
                label: task.hasTime ? DateFormat.jm().format(task.due!) : 'Add time',
                muted: !task.hasTime,
                onTap: () => _pickTime(task),
                onClear: task.hasTime
                    ? () => ctrl.edit(
                        task.id,
                        (t) => t.copyWith(
                              due: dateOnly(t.due!),
                              hasTime: false,
                              reminders: t.reminders
                                  .where(reminderPresetsFor(false).contains)
                                  .toList(),
                            ))
                    : null,
              ),
              const Divider(indent: 66),
              DetailRow(
                icon: Icons.hourglass_bottom_rounded,
                color: AppColors.teal,
                label: task.hasTime ? durationText() : 'Set a time to add a duration',
                muted: task.durationMinutes == null,
                enabled: task.hasTime,
                onTap: () => showDurationSheet(
                  context,
                  current: task.durationMinutes,
                  onSelected: (m) => ctrl.edit(task.id,
                      (t) => t.copyWith(durationMinutes: m, clearDuration: m == null)),
                ),
                onClear: task.durationMinutes == null
                    ? null
                    : () => ctrl.edit(task.id, (t) => t.copyWith(clearDuration: true)),
              ),
              const Divider(indent: 66),
              RemindersEditor(
                reminders: task.reminders,
                hasTime: task.hasTime,
                enabled: hasDue,
                onChanged: (r) => ctrl.edit(task.id, (t) => t.copyWith(reminders: r)),
              ),
              const Divider(indent: 66),
              DetailRow(
                icon: Icons.repeat_rounded,
                color: AppColors.green,
                label: !hasDue
                    ? 'Set a date to repeat'
                    : (task.recurrence?.label ?? 'Does not repeat'),
                muted: task.recurrence == null,
                enabled: hasDue,
                onTap: () => showRepeatSheet(
                  context,
                  current: task.recurrence,
                  onSelected: (r) => ctrl.edit(
                      task.id,
                      (t) => t.copyWith(
                            recurrence: r,
                            clearRecurrence: r == null,
                            due: r == null || t.due == null ? null : r.alignDue(t.due!),
                          )),
                ),
                onClear: task.recurrence == null
                    ? null
                    : () => ctrl.edit(task.id, (t) => t.copyWith(clearRecurrence: true)),
              ),
            ]),
          ),
          const SizedBox(height: 12),

          // ---- list, priority, tags ----
          AppCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                IconBadge(icon: Icons.folder_rounded, color: Color(currentList.color)),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: currentList.id,
                      items: [
                        for (final l in lists)
                          DropdownMenuItem(value: l.id, child: Text(l.name)),
                      ],
                      onChanged: (id) {
                        if (id != null) {
                          ctrl.edit(task.id, (t) => t.copyWith(listId: id));
                        }
                      },
                    ),
                  ),
                ),
              ]),
              const SizedBox(height: 16),
              Text('Priority', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 4, children: [
                for (final p in Priority.values.reversed)
                  ChoiceChip(
                    avatar: Icon(Icons.flag_rounded, size: 16, color: priorityColor(p)),
                    label: Text(p.name),
                    selected: task.priority == p,
                    onSelected: (_) =>
                        ctrl.edit(task.id, (t) => t.copyWith(priority: p)),
                  ),
              ]),
              const SizedBox(height: 16),
              Text('Tags', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 4, children: [
                for (final tag in task.tags)
                  InputChip(
                      label: Text('#$tag'),
                      onDeleted: () => ctrl.removeTag(task.id, tag)),
                ActionChip(
                  avatar: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Tag'),
                  onPressed: () async {
                    final raw = await showTagDialog(
                      context,
                      title: 'Add tag',
                      suggestions: [
                        for (final (name, _) in ref.read(allTagsProvider))
                          if (!task.tags.contains(name)) name
                      ],
                    );
                    if (raw != null) ctrl.addTag(task.id, raw);
                  },
                ),
              ]),
            ]),
          ),
          const SizedBox(height: 12),

          // ---- subtasks ----
          AppCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const IconBadge(icon: Icons.account_tree_rounded, color: AppColors.teal),
                const SizedBox(width: 12),
                Expanded(child: _sectionTitle(context, 'Subtasks')),
                if (task.subtasks.isNotEmpty)
                  Text('$subDone/${task.subtasks.length}',
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, color: AppColors.teal)),
              ]),
              if (task.subtasks.isNotEmpty) ...[
                const SizedBox(height: 12),
                LinearProgressIndicator(
                  value: subDone / task.subtasks.length,
                  minHeight: 6,
                  borderRadius: BorderRadius.circular(3),
                  color: AppColors.teal,
                  backgroundColor: AppColors.teal.withValues(alpha: 0.15),
                ),
              ],
              for (final s in task.subtasks)
                InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => showSubtaskSheet(context,
                      taskId: task.id, subtaskId: s.id),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(children: [
                      Checkbox(
                        value: s.done,
                        shape: const CircleBorder(),
                        activeColor: AppColors.teal,
                        onChanged: (_) => ctrl.toggleSubtask(task.id, s.id),
                      ),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(s.title,
                              style: TextStyle(
                                  decoration:
                                      s.done ? TextDecoration.lineThrough : null,
                                  color: s.done ? Colors.grey : null)),
                          if (s.due != null || s.reminders.isNotEmpty)
                            Row(children: [
                              if (s.due != null)
                                Text(friendlyDue(s.due!, hasTime: s.hasTime),
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: s.done
                                            ? Colors.grey
                                            : AppColors.blue)),
                              if (s.reminders.isNotEmpty) ...[
                                const SizedBox(width: 6),
                                const Icon(Icons.notifications_active_rounded,
                                    size: 12, color: AppColors.orange),
                              ],
                            ]),
                        ]),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 18),
                        onPressed: () => ctrl.removeSubtask(task.id, s.id),
                      ),
                    ]),
                  ),
                ),
              TextField(
                controller: _sub,
                focusNode: _subFocus,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.add_rounded),
                  hintText: 'Add subtask (tap one to set date & reminders)',
                  border: InputBorder.none,
                ),
                onSubmitted: (v) {
                  if (v.trim().isNotEmpty) ctrl.addSubtask(task.id, v);
                  _sub.clear();
                  _subFocus.requestFocus();
                },
              ),
            ]),
          ),
          const SizedBox(height: 12),

          // ---- comments ----
          AppCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const IconBadge(
                    icon: Icons.chat_bubble_outline_rounded, color: AppColors.pink),
                const SizedBox(width: 12),
                Expanded(child: _sectionTitle(context, 'Comments')),
                if (task.comments.isNotEmpty)
                  Text('${task.comments.length}',
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, color: AppColors.pink)),
              ]),
              for (final c in task.comments)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(c.text),
                  subtitle: Text(DateFormat.MMMd().add_jm().format(c.createdAt)),
                  trailing: IconButton(
                    icon: const Icon(Icons.close_rounded, size: 18),
                    onPressed: () => ctrl.removeComment(task.id, c.id),
                  ),
                ),
              TextField(
                controller: _comment,
                decoration: InputDecoration(
                  hintText: 'Add a comment',
                  border: InputBorder.none,
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.send_rounded),
                    onPressed: () {
                      ctrl.addComment(task.id, _comment.text);
                      _comment.clear();
                    },
                  ),
                ),
                onSubmitted: (v) {
                  ctrl.addComment(task.id, v);
                  _comment.clear();
                },
              ),
            ]),
          ),
          const SizedBox(height: 16),

          // ---- footer ----
          Center(
            child: Column(children: [
              if (focusSeconds > 0)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.timer_rounded, size: 16, color: AppColors.violet),
                    const SizedBox(width: 6),
                    Text('Focused ${_formatSeconds(focusSeconds)}',
                        style: const TextStyle(
                            color: AppColors.violet, fontWeight: FontWeight.w600)),
                  ]),
                ),
              Text('Created ${DateFormat.yMMMd().add_jm().format(task.createdAt)}',
                  style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
              if (task.completedAt != null)
                Text(
                    '${task.wontDo ? "Closed" : "Completed"} ${DateFormat.yMMMd().add_jm().format(task.completedAt!)}',
                    style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
            ]),
          ),
        ],
      ),
    );
  }
}
