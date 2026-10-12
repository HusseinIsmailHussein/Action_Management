import 'task_filter.dart';

/// A named TaskFilter that appears in the drawer like a smart list.
class SavedFilter {
  final String id;
  final String name;
  final TaskFilter filter;
  const SavedFilter({required this.id, required this.name, required this.filter});

  SavedFilter copyWith({String? name, TaskFilter? filter}) =>
      SavedFilter(id: id, name: name ?? this.name, filter: filter ?? this.filter);

  Map<String, dynamic> toJson() =>
      {'id': id, 'name': name, 'filter': filter.toJson()};

  factory SavedFilter.fromJson(Map<String, dynamic> j) => SavedFilter(
        id: j['id'] as String,
        name: j['name'] as String,
        filter: TaskFilter.fromJson(j['filter'] as Map<String, dynamic>),
      );
}
