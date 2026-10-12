import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/notification_batch.dart';
import '../application/habit_controller.dart';
import '../domain/habit.dart';
import 'habit_icons.dart';

const _dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

/// Create a habit, or edit [existing].
Future<void> showHabitForm(BuildContext context, {Habit? existing}) =>
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _HabitForm(existing: existing),
    );

class _HabitForm extends ConsumerStatefulWidget {
  final Habit? existing;
  const _HabitForm({this.existing});
  @override
  ConsumerState<_HabitForm> createState() => _HabitFormState();
}

class _HabitFormState extends ConsumerState<_HabitForm> {
  late final TextEditingController _name;
  late int _icon;
  late int _color;
  late Set<int> _days;
  late int _target;
  int? _remind; // minutes after midnight

  @override
  void initState() {
    super.initState();
    final h = widget.existing;
    _name = TextEditingController(text: h?.name ?? '');
    _icon = h?.iconIndex ?? 0;
    _color = h?.color ?? habitColors.first;
    _days = {...(h?.weekdays ?? const {1, 2, 3, 4, 5, 6, 7})};
    _target = h?.target ?? 1;
    _remind = h?.reminderAt;
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  bool get _valid => _name.text.trim().isNotEmpty && _days.isNotEmpty;

  void _save() {
    if (!_valid) return;
    final ctrl = ref.read(habitControllerProvider.notifier);
    final existing = widget.existing;
    if (existing == null) {
      ctrl.add(
          name: _name.text,
          iconIndex: _icon,
          color: _color,
          weekdays: _days,
          target: _target,
          reminderAt: _remind);
    } else {
      ctrl.edit(
          existing.id,
          (h) => h.copyWith(
              name: _name.text.trim(),
              iconIndex: _icon,
              color: _color,
              weekdays: _days,
              target: _target,
              reminderAt: _remind,
              clearReminder: _remind == null));
    }
    if (_remind != null) ref.read(notificationBatchProvider).requestPermission();
    Navigator.pop(context);
  }

  Future<void> _pickTime() async {
    final m = _remind ?? 9 * 60;
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: m ~/ 60, minute: m % 60),
    );
    if (t != null) setState(() => _remind = t.hour * 60 + t.minute);
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(top: 18, bottom: 8),
        child: Text(text, style: Theme.of(context).textTheme.labelLarge),
      );

  @override
  Widget build(BuildContext context) {
    final color = Color(_color);
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 0, 20, MediaQuery.of(context).viewInsets.bottom + 16),
      child: SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(widget.existing == null ? 'New habit' : 'Edit habit',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          TextField(
            controller: _name,
            autofocus: widget.existing == null,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(hintText: 'e.g. Drink water'),
            onChanged: (_) => setState(() {}),
          ),
          _label('Icon'),
          Wrap(spacing: 10, runSpacing: 10, children: [
            for (var i = 0; i < habitIcons.length; i++)
              GestureDetector(
                onTap: () => setState(() => _icon = i),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: i == _icon ? color : color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(habitIcons[i], color: i == _icon ? Colors.white : color),
                ),
              ),
          ]),
          _label('Color'),
          Wrap(spacing: 12, runSpacing: 10, children: [
            for (final c in habitColors)
              GestureDetector(
                onTap: () => setState(() => _color = c),
                child: CircleAvatar(
                  radius: 16,
                  backgroundColor: Color(c),
                  child: c == _color
                      ? const Icon(Icons.check_rounded, size: 18, color: Colors.white)
                      : null,
                ),
              ),
          ]),
          _label('Repeat'),
          Wrap(spacing: 8, runSpacing: 4, children: [
            for (var d = 1; d <= 7; d++)
              FilterChip(
                label: Text(_dayNames[d - 1]),
                selected: _days.contains(d),
                onSelected: (on) => setState(() => on ? _days.add(d) : _days.remove(d)),
              ),
          ]),
          _label('Daily goal'),
          Row(children: [
            IconButton.filledTonal(
              onPressed: () => setState(() => _target = math.max(1, _target - 1)),
              icon: const Icon(Icons.remove_rounded),
            ),
            SizedBox(
              width: 120,
              child: Text(
                _target == 1 ? 'Once a day' : '$_target times a day',
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            IconButton.filledTonal(
              onPressed: () => setState(() => _target = math.min(20, _target + 1)),
              icon: const Icon(Icons.add_rounded),
            ),
          ]),
          _label('Reminder'),
          Wrap(children: [
            if (_remind == null)
              ActionChip(
                avatar: const Icon(Icons.notifications_none_rounded, size: 18),
                label: const Text('Add reminder'),
                onPressed: _pickTime,
              )
            else
              InputChip(
                avatar: const Icon(Icons.notifications_active_rounded, size: 18),
                label: Text(TimeOfDay(hour: _remind! ~/ 60, minute: _remind! % 60)
                    .format(context)),
                onPressed: _pickTime,
                onDeleted: () => setState(() => _remind = null),
              ),
          ]),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _valid ? _save : null,
              style: FilledButton.styleFrom(
                  backgroundColor: color, padding: const EdgeInsets.all(16)),
              child: Text(widget.existing == null ? 'Create habit' : 'Save changes'),
            ),
          ),
        ]),
      ),
    );
  }
}
