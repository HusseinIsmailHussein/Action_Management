import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../domain/recurrence.dart';
import 'date_pickers.dart';

const _dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

/// Calls [onSelected] with the chosen rule, or null for "does not repeat".
/// Also edits the end condition and "repeat from completion date".
Future<void> showRepeatSheet(
  BuildContext context, {
  required Recurrence? current,
  required ValueChanged<Recurrence?> onSelected,
}) {
  // Keep the end condition and completion mode when switching between rules.
  Recurrence carry(Recurrence r) => r.copyWith(
        fromCompletion: current?.fromCompletion ?? false,
        until: current?.until,
        count: current?.count,
      );

  bool isPreset(Recurrence r) =>
      current != null &&
      current.weekdays.isEmpty &&
      current.unit == r.unit &&
      current.interval == r.interval;

  final isCustom = current != null && !kRepeatPresets.any(isPreset);

  Widget option(BuildContext ctx, String label, Recurrence? value, bool selected) =>
      ListTile(
        title: Text(label),
        trailing: selected ? const Icon(Icons.check) : null,
        onTap: () {
          Navigator.pop(ctx);
          onSelected(value == null ? null : carry(value));
        },
      );

  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => SafeArea(
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          option(ctx, 'Does not repeat', null, current == null),
          for (final r in kRepeatPresets) option(ctx, r.ruleLabel, r, isPreset(r)),
          ListTile(
            title: Text(isCustom ? 'Custom: ${current.ruleLabel}' : 'Custom...'),
            trailing: isCustom ? const Icon(Icons.check) : null,
            onTap: () async {
              Navigator.pop(ctx);
              final r = await _customDialog(context, current);
              if (r != null) onSelected(r);
            },
          ),
          const Divider(),
          ListTile(
            enabled: current != null,
            leading: const Icon(Icons.event_busy_rounded),
            title: const Text('Ends'),
            subtitle: Text(current?.endLabel ?? 'Never'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: current == null
                ? null
                : () async {
                    Navigator.pop(ctx);
                    final r = await _endDialog(context, current);
                    if (r != null) onSelected(r);
                  },
          ),
          SwitchListTile(
            title: const Text('Repeat from completion date'),
            subtitle: const Text('Next one is counted from when you finish it'),
            value: current?.fromCompletion ?? false,
            onChanged: current == null
                ? null
                : (v) {
                    Navigator.pop(ctx);
                    onSelected(current.copyWith(fromCompletion: v));
                  },
          ),
        ]),
      ),
    ),
  );
}

/// Interval, unit and (for weekly rules) the weekdays.
Future<Recurrence?> _customDialog(BuildContext context, Recurrence? initial) {
  final count = TextEditingController(text: '${initial?.interval ?? 2}');
  var unit = initial?.unit ?? RepeatUnit.day;
  final days = <int>{...?initial?.weekdays};

  return showDialog<Recurrence>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        title: const Text('Repeat every'),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            SizedBox(
              width: 64,
              child: TextField(
                controller: count,
                keyboardType: TextInputType.number,
                autofocus: true,
              ),
            ),
            const SizedBox(width: 16),
            DropdownButton<RepeatUnit>(
              value: unit,
              items: [
                for (final u in RepeatUnit.values)
                  DropdownMenuItem(value: u, child: Text('${u.name}(s)')),
              ],
              onChanged: (u) {
                if (u != null) setState(() => unit = u);
              },
            ),
          ]),
          if (unit == RepeatUnit.week) ...[
            const SizedBox(height: 16),
            const Text('On'),
            const SizedBox(height: 8),
            Wrap(spacing: 6, runSpacing: 4, children: [
              for (var d = 1; d <= 7; d++)
                FilterChip(
                  label: Text(_dayNames[d - 1]),
                  selected: days.contains(d),
                  onSelected: (on) => setState(() => on ? days.add(d) : days.remove(d)),
                ),
            ]),
          ],
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final n = int.tryParse(count.text) ?? 0;
              if (n < 1) return;
              Navigator.pop(
                ctx,
                Recurrence(
                  unit: unit,
                  interval: n > 999 ? 999 : n,
                  fromCompletion: initial?.fromCompletion ?? false,
                  weekdays: unit == RepeatUnit.week ? {...days} : const {},
                  until: initial?.until,
                  count: initial?.count,
                ),
              );
            },
            child: const Text('Done'),
          ),
        ],
      ),
    ),
  );
}

/// Never / on a date / after N occurrences.
Future<Recurrence?> _endDialog(BuildContext context, Recurrence current) {
  var mode = current.until != null ? 1 : (current.count != null ? 2 : 0);
  DateTime? until = current.until;
  final times = TextEditingController(text: '${current.count ?? 5}');

  return showDialog<Recurrence>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        title: const Text('Ends'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          SegmentedButton<int>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: 0, label: Text('Never')),
              ButtonSegment(value: 1, label: Text('On date')),
              ButtonSegment(value: 2, label: Text('After')),
            ],
            selected: {mode},
            onSelectionChanged: (s) => setState(() => mode = s.first),
          ),
          const SizedBox(height: 16),
          if (mode == 1)
            OutlinedButton.icon(
              icon: const Icon(Icons.event_rounded),
              label: Text(until == null ? 'Pick a date' : DateFormat.yMMMd().format(until!)),
              onPressed: () async {
                final d = await pickDate(ctx, initial: until);
                if (d != null) setState(() => until = d);
              },
            ),
          if (mode == 2)
            Row(mainAxisSize: MainAxisSize.min, children: [
              const Text('After'),
              const SizedBox(width: 12),
              SizedBox(
                width: 64,
                child: TextField(controller: times, keyboardType: TextInputType.number),
              ),
              const SizedBox(width: 12),
              const Text('times'),
            ]),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              var r = current.copyWith(clearUntil: true, clearCount: true);
              if (mode == 1) {
                if (until == null) return;
                r = r.copyWith(until: DateTime(until!.year, until!.month, until!.day));
              } else if (mode == 2) {
                final n = int.tryParse(times.text) ?? 0;
                if (n < 1) return;
                r = r.copyWith(count: n > 999 ? 999 : n);
              }
              Navigator.pop(ctx, r);
            },
            child: const Text('Done'),
          ),
        ],
      ),
    ),
  );
}
