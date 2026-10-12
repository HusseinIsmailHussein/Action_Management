const inboxId = 'inbox';

class TaskList {
  final String id;
  final String name;
  final int color; // ARGB int, keeps domain free of Flutter imports

  const TaskList({required this.id, required this.name, required this.color});

  factory TaskList.inbox() =>
      const TaskList(id: inboxId, name: 'Inbox', color: 0xFF4772FA);

  TaskList copyWith({String? name, int? color}) =>
      TaskList(id: id, name: name ?? this.name, color: color ?? this.color);

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'color': color};

  factory TaskList.fromJson(Map<String, dynamic> j) => TaskList(
      id: j['id'] as String, name: j['name'] as String, color: j['color'] as int);
}
