import 'view_options.dart';

abstract class ViewOptionsRepository {
  Future<ViewOptions> load();
  Future<void> save(ViewOptions options);
}
