import 'package:flutter/material.dart';

/// Icons offered when creating a habit. Habits store only the index,
/// so append new icons at the end to keep saved habits intact.
const habitIcons = <IconData>[
  Icons.water_drop_rounded,
  Icons.fitness_center_rounded,
  Icons.menu_book_rounded,
  Icons.self_improvement_rounded,
  Icons.bedtime_rounded,
  Icons.directions_run_rounded,
  Icons.code_rounded,
  Icons.music_note_rounded,
  Icons.brush_rounded,
  Icons.savings_rounded,
  Icons.restaurant_rounded,
  Icons.favorite_rounded,
];

IconData habitIcon(int index) => habitIcons[index % habitIcons.length];

const habitColors = <int>[
  0xFF5B5BF0,
  0xFF3B82F6,
  0xFF14B8A6,
  0xFF10B981,
  0xFFF59E0B,
  0xFFEC4899,
  0xFF8B5CF6,
  0xFFEF4444,
];
