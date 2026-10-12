import 'package:flutter/material.dart';
import '../../../core/theme.dart';
import '../application/task_controller.dart';
import '../domain/task_list.dart';

Color smartColor(SmartView v) => switch (v) {
      SmartView.today => AppColors.blue,
      SmartView.upcoming => AppColors.orange,
      SmartView.all => AppColors.violet,
      SmartView.completed => AppColors.green,
    };

IconData smartIcon(SmartView v) => switch (v) {
      SmartView.today => Icons.today_rounded,
      SmartView.upcoming => Icons.date_range_rounded,
      SmartView.all => Icons.all_inbox_rounded,
      SmartView.completed => Icons.check_circle_rounded,
    };

class ViewStyle {
  final Color color;
  final IconData icon;
  const ViewStyle(this.color, this.icon);
}

/// Accent color + icon for whatever view is selected.
ViewStyle styleFor(ViewSelection sel, {TaskList? list}) {
  if (sel.smart != null) return ViewStyle(smartColor(sel.smart!), smartIcon(sel.smart!));
  if (sel.listId != null) {
    return ViewStyle(
        list == null ? AppColors.brand : Color(list.color), Icons.folder_rounded);
  }
  if (sel.tag != null) return const ViewStyle(AppColors.pink, Icons.tag_rounded);
  return const ViewStyle(AppColors.teal, Icons.filter_alt_rounded);
}
