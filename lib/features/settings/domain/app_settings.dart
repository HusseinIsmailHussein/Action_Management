enum AppThemeMode { system, light, dark }

/// Colors offered as the app accent (ARGB).
const kAccentChoices = <int>[
  0xFF5B5BF0, // indigo (default)
  0xFF3B82F6, // blue
  0xFF14B8A6, // teal
  0xFF10B981, // green
  0xFFF59E0B, // amber
  0xFFEC4899, // pink
  0xFF8B5CF6, // violet
  0xFFEF4444, // red
];

/// User preferences. Add new options here (+ copyWith/toJson/fromJson).
class AppSettings {
  final AppThemeMode themeMode;
  final int accent; // ARGB

  const AppSettings({
    this.themeMode = AppThemeMode.system,
    this.accent = 0xFF5B5BF0,
  });

  AppSettings copyWith({AppThemeMode? themeMode, int? accent}) => AppSettings(
        themeMode: themeMode ?? this.themeMode,
        accent: accent ?? this.accent,
      );

  Map<String, dynamic> toJson() => {'themeMode': themeMode.index, 'accent': accent};

  factory AppSettings.fromJson(Map<String, dynamic> j) {
    final mode = (j['themeMode'] ?? 0) as int;
    return AppSettings(
      themeMode: AppThemeMode.values[mode.clamp(0, AppThemeMode.values.length - 1).toInt()],
      accent: (j['accent'] ?? 0xFF5B5BF0) as int,
    );
  }
}
