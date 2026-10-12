import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Opens the global search screen. main.dart plugs in the real screen, so
/// features can offer a search button without importing the search feature.
final openSearchProvider =
    Provider<void Function(BuildContext context)>((ref) => (context) {});
