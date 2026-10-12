enum SortBy { smart, dueDate, priority, title, created, manual }

extension SortByX on SortBy {
  String get label => switch (this) {
        SortBy.smart => 'Smart',
        SortBy.dueDate => 'Due date',
        SortBy.priority => 'Priority',
        SortBy.title => 'Title',
        SortBy.created => 'Created',
        SortBy.manual => 'Manual',
      };
}

enum GroupBy { none, date, priority, list }

extension GroupByX on GroupBy {
  String get label => switch (this) {
        GroupBy.none => 'None',
        GroupBy.date => 'Date',
        GroupBy.priority => 'Priority',
        GroupBy.list => 'List',
      };
}

/// How the task list is ordered and sectioned.
/// Natural orders: due date soonest first, priority high to low, title A-Z,
/// created newest first. [reversed] flips them (not used by Smart).
class ViewOptions {
  final SortBy sort;
  final bool reversed;
  final GroupBy group;
  const ViewOptions({
    this.sort = SortBy.smart,
    this.reversed = false,
    this.group = GroupBy.none,
  });

  bool get isDefault => sort == SortBy.smart && !reversed && group == GroupBy.none;

  ViewOptions copyWith({SortBy? sort, bool? reversed, GroupBy? group}) => ViewOptions(
        sort: sort ?? this.sort,
        reversed: reversed ?? this.reversed,
        group: group ?? this.group,
      );

  Map<String, dynamic> toJson() =>
      {'sort': sort.index, 'reversed': reversed, 'group': group.index};

  factory ViewOptions.fromJson(Map<String, dynamic> j) {
    final s = ((j['sort'] ?? 0) as int).clamp(0, SortBy.values.length - 1).toInt();
    final g = ((j['group'] ?? 0) as int).clamp(0, GroupBy.values.length - 1).toInt();
    return ViewOptions(
      sort: SortBy.values[s],
      reversed: (j['reversed'] ?? false) as bool,
      group: GroupBy.values[g],
    );
  }
}
