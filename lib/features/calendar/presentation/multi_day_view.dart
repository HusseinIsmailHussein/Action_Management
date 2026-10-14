import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/date_utils.dart';
import '../../../core/theme.dart';
import '../../tasks/application/task_controller.dart';
import '../../tasks/domain/duration_options.dart';
import '../../tasks/domain/task.dart';
import '../../tasks/presentation/add_task_sheet.dart';
import '../../tasks/presentation/task_detail_page.dart';
import '../../tasks/presentation/task_tile.dart';
import '../application/calendar_controller.dart';
import '../application/calendar_entry.dart';
import '../domain/day_layout.dart';

const _hourHeight = 56.0;
const _labelWidth = 44.0;
const _snapStep = 15; // minutes

/// Side-by-side days with an hour grid: used for both the week (7 days) and
/// the 3-day view (see CalendarState.dayCount).
///
/// - Tap an empty slot to add a task at that day and hour.
/// - Press and hold a task block, then drag it to another day or time to
///   reschedule it (snaps to 15 minutes; an Undo bar appears).
/// - Tap a day number to open that day on its own.
/// - Swipe sideways to move by a screenful of days.
class MultiDayView extends ConsumerStatefulWidget {
  const MultiDayView({super.key});
  @override
  ConsumerState<MultiDayView> createState() => _MultiDayViewState();
}

class _MultiDayViewState extends ConsumerState<MultiDayView> {
  late final ScrollController _scroll;
  final _viewportKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    // Open near the current time instead of at midnight.
    _scroll = ScrollController(
        initialScrollOffset: math.max(0, DateTime.now().hour - 1) * _hourHeight);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// A block was dropped on a new slot: reschedule, with Undo.
  void _move(CalendarEntry entry, DateTime newDue) {
    final old = entry.task.due;
    if (old == null || newDue == old) return;
    final ctrl = ref.read(taskControllerProvider.notifier);
    final id = entry.task.id;
    ctrl.edit(id, (t) => t.copyWith(due: newDue));
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(
            'Moved to ${DateFormat.MMMEd().format(newDue)}, ${DateFormat.jm().format(newDue)}'),
        action: SnackBarAction(
            label: 'Undo', onPressed: () => ctrl.edit(id, (t) => t.copyWith(due: old))),
      ));
  }

  /// A block's bottom edge was dragged: set the new duration, with Undo.
  void _resize(CalendarEntry entry, int minutes) {
    final old = entry.task.durationMinutes;
    if (minutes == (old ?? 30)) return; // blocks without a duration show as 30 min
    final ctrl = ref.read(taskControllerProvider.notifier);
    final id = entry.task.id;
    ctrl.edit(id, (t) => t.copyWith(durationMinutes: minutes));
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text('Duration set to ${durationLabel(minutes)}'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () => ctrl.edit(
              id,
              (t) => old == null
                  ? t.copyWith(clearDuration: true)
                  : t.copyWith(durationMinutes: old)),
        ),
      ));
  }

  @override
  Widget build(BuildContext context) {
    final cal = ref.watch(calendarControllerProvider);
    final ctrl = ref.read(calendarControllerProvider.notifier);
    final byDay = ref.watch(tasksByDayProvider);
    final n = cal.dayCount;
    final first = cal.firstVisibleDay;
    final days = [for (var i = 0; i < n; i++) DateTime(first.year, first.month, first.day + i)];
    final today = dateOnly(DateTime.now());

    List<CalendarEntry> entriesOf(DateTime d) => byDay[d] ?? const [];
    final allDay = [for (final d in days) entriesOf(d).where((e) => !e.task.hasTime).toList()];
    final timed = [for (final d in days) entriesOf(d).where((e) => e.task.hasTime).toList()];

    return GestureDetector(
      onHorizontalDragEnd: (d) {
        final v = d.primaryVelocity ?? 0;
        if (v < -200) ctrl.shiftDay(n);
        if (v > 200) ctrl.shiftDay(-n);
      },
      child: Column(children: [
        _DayHeader(
          days: days,
          selected: cal.selectedDay,
          today: today,
          onTap: (d) {
            ctrl.selectDay(d);
            ctrl.setMode(CalendarMode.day);
          },
        ),
        if (allDay.any((l) => l.isNotEmpty)) _AllDayStrip(perDay: allDay),
        const Divider(height: 1),
        Expanded(
          child: SingleChildScrollView(
            key: _viewportKey,
            controller: _scroll,
            padding: const EdgeInsets.only(bottom: 100),
            child: _Grid(
              days: days,
              timed: timed,
              today: today,
              scroll: _scroll,
              viewportKey: _viewportKey,
              onMove: _move,
              onResize: _resize,
            ),
          ),
        ),
      ]),
    );
  }
}

class _DayHeader extends StatelessWidget {
  final List<DateTime> days;
  final DateTime selected;
  final DateTime today;
  final ValueChanged<DateTime> onTap;
  const _DayHeader({
    required this.days,
    required this.selected,
    required this.today,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(children: [
      const SizedBox(width: _labelWidth),
      for (final d in days)
        Expanded(
          child: InkWell(
            onTap: () => onTap(d),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(children: [
                Text(
                  days.length <= 3
                      ? DateFormat.E().format(d)
                      : DateFormat.E().format(d).substring(0, 1),
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: 4),
                Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSameDay(d, selected)
                        ? scheme.primary
                        : (isSameDay(d, today) ? scheme.primaryContainer : null),
                  ),
                  child: Text(
                    '${d.day}',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: isSameDay(d, selected)
                          ? scheme.onPrimary
                          : (isSameDay(d, today) ? scheme.onPrimaryContainer : null),
                    ),
                  ),
                ),
              ]),
            ),
          ),
        ),
    ]);
  }
}

/// Tasks without a time, shown as small chips above the grid.
class _AllDayStrip extends StatelessWidget {
  final List<List<CalendarEntry>> perDay;
  const _AllDayStrip({required this.perDay});

  static const _maxChips = 2;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
          width: _labelWidth,
          child: Padding(
            padding: const EdgeInsets.only(top: 3, right: 4),
            child: Text('All day',
                textAlign: TextAlign.right, style: TextStyle(fontSize: 9, color: muted)),
          ),
        ),
        for (final entries in perDay)
          Expanded(
            child: Column(children: [
              for (final e in entries.take(_maxChips)) _Chip(entry: e),
              if (entries.length > _maxChips)
                Text('+${entries.length - _maxChips}',
                    style: TextStyle(fontSize: 10, color: muted)),
            ]),
          ),
      ]),
    );
  }
}

class _Chip extends StatelessWidget {
  final CalendarEntry entry;
  const _Chip({required this.entry});

  @override
  Widget build(BuildContext context) {
    final t = entry.task;
    final color = t.priority == Priority.none
        ? Theme.of(context).colorScheme.primary
        : priorityColor(t.priority);
    return InkWell(
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => TaskDetailPage(taskId: t.id))),
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.fromLTRB(1, 1, 1, 0),
        padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: entry.projected ? 0.08 : 0.2),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          t.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 10,
            fontStyle: entry.projected ? FontStyle.italic : null,
            decoration: t.done ? TextDecoration.lineThrough : null,
            color: t.done ? Colors.grey : null,
          ),
        ),
      ),
    );
  }
}

TimeSpan _spanOf(CalendarEntry e) {
  final due = e.task.due!;
  final start = due.hour * 60 + due.minute;
  return (start: start, end: math.min(24 * 60, start + (e.task.durationMinutes ?? 30)));
}

double _blockHeight(TimeSpan span) =>
    math.max(22.0, (span.end - span.start) / 60 * _hourHeight - 1);

/// The hour grid with one column per day, including the drag-to-reschedule gesture.
class _Grid extends StatefulWidget {
  final List<DateTime> days;
  final List<List<CalendarEntry>> timed;
  final DateTime today;
  final ScrollController scroll; // lets a drag scroll the view near its edges
  final GlobalKey viewportKey; // the scroll view, to find its edges on screen
  final void Function(CalendarEntry entry, DateTime newDue) onMove;
  final void Function(CalendarEntry entry, int minutes) onResize;
  const _Grid({
    required this.days,
    required this.timed,
    required this.today,
    required this.scroll,
    required this.viewportKey,
    required this.onMove,
    required this.onResize,
  });

  @override
  State<_Grid> createState() => _GridState();
}

class _GridState extends State<_Grid> {
  // ---- drag state ----
  CalendarEntry? _dragging;
  double _originTop = 0;
  int _originCol = 0;
  double _scrollAtStart = 0;
  Offset _delta = Offset.zero; // pointer movement since the long press
  Offset _pointer = Offset.zero; // pointer position on screen
  double _colW = 1; // column width, set while building
  Timer? _edgeTimer;
  int _edgeDir = 0; // -1 scrolling up, 1 down, 0 not scrolling

  // ---- resize state (dragging a block's bottom edge) ----
  CalendarEntry? _resizing;
  int _resizeBase = 30; // duration when the drag started, in minutes
  double _resizeDy = 0; // how far the edge has been dragged, in pixels

  @override
  void dispose() {
    _edgeTimer?.cancel();
    super.dispose();
  }

  void _start(CalendarEntry entry, double top, int col) {
    HapticFeedback.mediumImpact();
    setState(() {
      _dragging = entry;
      _originTop = top;
      _originCol = col;
      _scrollAtStart = widget.scroll.hasClients ? widget.scroll.offset : 0;
      _delta = Offset.zero;
    });
  }

  void _update(LongPressMoveUpdateDetails d) {
    setState(() {
      _delta = d.offsetFromOrigin;
      _pointer = d.globalPosition;
    });
    _updateEdgeScroll();
  }

  void _end() {
    final entry = _dragging;
    if (entry == null) return;
    final t = _target();
    _stop();
    final day = widget.days[t.col];
    widget.onMove(entry, DateTime(day.year, day.month, day.day, t.minute ~/ 60, t.minute % 60));
  }

  void _stop() {
    _edgeTimer?.cancel();
    _edgeTimer = null;
    _edgeDir = 0;
    if (mounted) setState(() => _dragging = null);
  }

  void _resizeStart(CalendarEntry entry, int baseMinutes) {
    HapticFeedback.selectionClick();
    setState(() {
      _resizing = entry;
      _resizeBase = baseMinutes;
      _resizeDy = 0;
    });
  }

  void _resizeUpdate(DragUpdateDetails d) => setState(() => _resizeDy += d.delta.dy);

  /// The duration (snapped, at least one step, not past midnight) for the current drag.
  int _resizeMinutes(CalendarEntry entry) {
    final due = entry.task.due!;
    final start = due.hour * 60 + due.minute;
    return snapDuration(_resizeBase + _resizeDy / _hourHeight * 60,
        step: _snapStep, min: _snapStep, max: 24 * 60 - start);
  }

  void _resizeEnd() {
    final entry = _resizing;
    if (entry == null) return;
    final minutes = _resizeMinutes(entry);
    setState(() => _resizing = null);
    widget.onResize(entry, minutes);
  }

  void _resizeCancel() => setState(() => _resizing = null);

  /// The column and (snapped) start minute the dragged block would drop onto.
  ({int col, int minute}) _target() {
    final scrolled = widget.scroll.hasClients ? widget.scroll.offset - _scrollAtStart : 0.0;
    final top = _originTop + _delta.dy + scrolled;
    final left = _originCol * _colW + _delta.dx;
    return (
      col: (left / _colW).round().clamp(0, widget.days.length - 1).toInt(),
      minute: snapMinute(top / _hourHeight * 60,
          step: _snapStep, latestStart: 24 * 60 - _snapStep),
    );
  }

  /// Scroll the grid while the pointer sits near its top or bottom edge.
  void _updateEdgeScroll() {
    final box = widget.viewportKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.attached) return;
    final top = box.localToGlobal(Offset.zero).dy;
    final bottom = top + box.size.height;
    _edgeDir = _pointer.dy < top + 56 ? -1 : (_pointer.dy > bottom - 56 ? 1 : 0);
    if (_edgeDir == 0) {
      _edgeTimer?.cancel();
      _edgeTimer = null;
      return;
    }
    _edgeTimer ??= Timer.periodic(const Duration(milliseconds: 16), (_) {
      if (!widget.scroll.hasClients || _edgeDir == 0) return;
      final max = widget.scroll.position.maxScrollExtent;
      widget.scroll.jumpTo((widget.scroll.offset + _edgeDir * 8).clamp(0.0, max).toDouble());
      if (mounted) setState(() {}); // keep the ghost under the finger
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final line = scheme.outlineVariant.withValues(alpha: 0.5);
    final days = widget.days;

    return LayoutBuilder(builder: (context, c) {
      final colW = (c.maxWidth - _labelWidth) / days.length;
      _colW = colW;
      final children = <Widget>[];

      // Tint today's column.
      for (var i = 0; i < days.length; i++) {
        if (isSameDay(days[i], widget.today)) {
          children.add(Positioned(
            left: _labelWidth + i * colW,
            top: 0,
            width: colW,
            height: 24 * _hourHeight,
            child: ColoredBox(color: scheme.primary.withValues(alpha: 0.05)),
          ));
        }
      }

      // Hour lines and labels.
      for (var h = 0; h < 24; h++) {
        children.add(Positioned(
            top: h * _hourHeight,
            left: _labelWidth,
            right: 0,
            height: 1,
            child: ColoredBox(color: line)));
        children.add(Positioned(
          top: h * _hourHeight + 2,
          left: 0,
          width: _labelWidth - 6,
          child: Text(
            DateFormat.j().format(DateTime(2000, 1, 1, h)),
            textAlign: TextAlign.right,
            style: TextStyle(fontSize: 10, color: scheme.onSurfaceVariant),
          ),
        ));
      }

      // Day separators.
      for (var i = 0; i <= days.length; i++) {
        children.add(Positioned(
            left: _labelWidth + i * colW,
            top: 0,
            bottom: 0,
            width: 1,
            child: ColoredBox(color: line)));
      }

      // Tap an empty slot to add a task there (blocks sit above and take their own taps).
      children.add(Positioned.fill(
        left: _labelWidth,
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTapUp: (d) {
            final col = (d.localPosition.dx ~/ colW).clamp(0, days.length - 1).toInt();
            final hour = (d.localPosition.dy ~/ _hourHeight).clamp(0, 23).toInt();
            final day = days[col];
            showAddTaskSheet(context,
                due: DateTime(day.year, day.month, day.day, hour), hasTime: true);
          },
        ),
      ));

      // Task blocks, with overlapping ones side by side.
      for (var i = 0; i < days.length; i++) {
        final entries = widget.timed[i];
        final spans = [for (final e in entries) _spanOf(e)];
        for (final p in layoutLanes(spans)) {
          final entry = entries[p.index];
          final span = spans[p.index];
          final laneW = (colW - 2) / p.lanes;
          final resizing = identical(_resizing, entry);
          // While resizing, the block follows the finger and shows its new time range.
          final minutes = resizing ? _resizeMinutes(entry) : span.end - span.start;
          final height = resizing
              ? math.max(22.0, minutes / 60 * _hourHeight - 1)
              : _blockHeight(span);
          final top = span.start / 60 * _hourHeight;
          final movable = !entry.projected; // future repeats can't be dragged or resized
          final due = entry.task.due!;
          children.add(Positioned(
            top: top,
            left: _labelWidth + i * colW + 1 + p.lane * laneW,
            width: laneW - 1,
            height: height,
            child: _Block(
              entry: entry,
              height: height,
              showTime: laneW > 90,
              faded: identical(_dragging, entry),
              rangeLabel: resizing
                  ? '${DateFormat.jm().format(due)} – ${DateFormat.jm().format(due.add(Duration(minutes: minutes)))} (${durationLabel(minutes)})'
                  : null,
              onDragStart: movable ? () => _start(entry, top, i) : null,
              onDragUpdate: movable ? _update : null,
              onDragEnd: movable ? _end : null,
              onDragCancel: movable ? _stop : null,
              onResizeStart: movable ? () => _resizeStart(entry, span.end - span.start) : null,
              onResizeUpdate: movable ? _resizeUpdate : null,
              onResizeEnd: movable ? _resizeEnd : null,
              onResizeCancel: movable ? _resizeCancel : null,
            ),
          ));
        }
      }

      // The block being dragged, shown where it would land.
      final dragged = _dragging;
      if (dragged != null) {
        final t = _target();
        final height = _blockHeight(_spanOf(dragged));
        children.add(Positioned(
          top: t.minute / 60 * _hourHeight,
          left: _labelWidth + t.col * colW + 1,
          width: colW - 2,
          height: height,
          child: IgnorePointer(
            child: _Ghost(
              entry: dragged,
              due: DateTime(days[t.col].year, days[t.col].month, days[t.col].day,
                  t.minute ~/ 60, t.minute % 60),
              height: height,
            ),
          ),
        ));
      }

      // "Now" line.
      final todayIndex = days.indexWhere((d) => isSameDay(d, widget.today));
      if (todayIndex >= 0) {
        final now = DateTime.now();
        children.add(Positioned(
          top: (now.hour * 60 + now.minute) / 60 * _hourHeight - 1,
          left: _labelWidth + todayIndex * colW,
          width: colW,
          height: 2,
          child: const ColoredBox(color: AppColors.red),
        ));
      }

      return SizedBox(height: 24 * _hourHeight, child: Stack(children: children));
    });
  }
}

Color _accentOf(BuildContext context, TaskItem t) => t.priority == Priority.none
    ? Theme.of(context).colorScheme.primary
    : priorityColor(t.priority);

class _Block extends StatelessWidget {
  final CalendarEntry entry;
  final double height;
  final bool showTime;
  final bool faded;
  final String? rangeLabel; // shown while the block is being resized

  // Press and hold, then drag: move the task.
  final VoidCallback? onDragStart;
  final GestureLongPressMoveUpdateCallback? onDragUpdate;
  final VoidCallback? onDragEnd;
  final VoidCallback? onDragCancel;

  // Drag the bottom edge: change the duration.
  final VoidCallback? onResizeStart;
  final GestureDragUpdateCallback? onResizeUpdate;
  final VoidCallback? onResizeEnd;
  final VoidCallback? onResizeCancel;

  const _Block({
    required this.entry,
    required this.height,
    required this.showTime,
    this.faded = false,
    this.rangeLabel,
    this.onDragStart,
    this.onDragUpdate,
    this.onDragEnd,
    this.onDragCancel,
    this.onResizeStart,
    this.onResizeUpdate,
    this.onResizeEnd,
    this.onResizeCancel,
  });

  @override
  Widget build(BuildContext context) {
    final t = entry.task;
    final accent = _accentOf(context, t);
    final lines = ((height - 4) / 12).floor().clamp(1, 8).toInt();
    final text = rangeLabel != null
        ? '$rangeLabel\n${t.title}'
        : (showTime ? '${DateFormat.jm().format(t.due!)} ${t.title}' : t.title);
    void open() => Navigator.push(
        context, MaterialPageRoute(builder: (_) => TaskDetailPage(taskId: t.id)));

    final content = ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: ColoredBox(
        color: accent.withValues(alpha: entry.projected ? 0.08 : 0.2),
        child: Row(children: [
          Container(width: 3, color: accent),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(3, 2, 2, 2),
              child: Text(
                text,
                maxLines: lines,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10,
                  height: 1.15,
                  fontStyle: entry.projected ? FontStyle.italic : null,
                  decoration: t.done ? TextDecoration.lineThrough : null,
                  color: t.done ? Colors.grey : null,
                ),
              ),
            ),
          ),
        ]),
      ),
    );

    return Opacity(
      opacity: faded ? 0.35 : 1,
      child: GestureDetector(
        onLongPressStart: onDragStart == null ? null : (_) => onDragStart!(),
        onLongPressMoveUpdate: onDragUpdate,
        onLongPressEnd: onDragEnd == null ? null : (_) => onDragEnd!(),
        onLongPressCancel: onDragCancel,
        child: InkWell(
          onTap: open,
          child: Stack(children: [
            content,
            if (onResizeStart != null)
              // The bottom edge: a small grip you can drag to change the duration.
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: math.min(14.0, height / 2),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: open,
                  onVerticalDragStart: (_) => onResizeStart!(),
                  onVerticalDragUpdate: onResizeUpdate,
                  onVerticalDragEnd: (_) => onResizeEnd!(),
                  onVerticalDragCancel: onResizeCancel,
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: Container(
                      width: 20,
                      height: 3,
                      margin: const EdgeInsets.only(bottom: 2),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
              ),
          ]),
        ),
      ),
    );
  }
}

/// The dragged block, drawn at its snapped drop position with the new time.
class _Ghost extends StatelessWidget {
  final CalendarEntry entry;
  final DateTime due;
  final double height;
  const _Ghost({required this.entry, required this.due, required this.height});

  @override
  Widget build(BuildContext context) {
    final accent = _accentOf(context, entry.task);
    final lines = ((height - 6) / 12).floor().clamp(1, 8).toInt();
    return Container(
      padding: const EdgeInsets.fromLTRB(4, 2, 3, 2),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: accent, width: 2),
        boxShadow: const [BoxShadow(blurRadius: 8, color: Colors.black26)],
      ),
      child: Text(
        '${DateFormat.jm().format(due)}\n${entry.task.title}',
        maxLines: lines + 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 10, height: 1.15, fontWeight: FontWeight.w700),
      ),
    );
  }
}
