import 'task_list.dart';

abstract class ListRepository {
  Future<List<TaskList>> load();
  Future<void> save(List<TaskList> lists);
}
