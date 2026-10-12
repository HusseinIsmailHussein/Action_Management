import 'package:flutter/material.dart';

Future<DateTime?> pickDate(BuildContext context, {DateTime? initial}) {
  final now = DateTime.now();
  var first = now.subtract(const Duration(days: 365));
  if (initial != null && initial.isBefore(first)) first = initial;
  return showDatePicker(
    context: context,
    initialDate: initial ?? now,
    firstDate: first,
    lastDate: now.add(const Duration(days: 3650)),
  );
}

Future<TimeOfDay?> pickTimeOfDay(BuildContext context,
        {DateTime? initial, required bool hasTime}) =>
    showTimePicker(
      context: context,
      initialTime: hasTime && initial != null
          ? TimeOfDay.fromDateTime(initial)
          : TimeOfDay.now(),
    );
