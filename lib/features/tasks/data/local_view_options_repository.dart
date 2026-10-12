import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../domain/view_options.dart';
import '../domain/view_options_repository.dart';

class LocalViewOptionsRepository implements ViewOptionsRepository {
  static const _key = 'view_options_v1';

  @override
  Future<ViewOptions> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return const ViewOptions();
    return ViewOptions.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  @override
  Future<void> save(ViewOptions options) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(options.toJson()));
  }
}
