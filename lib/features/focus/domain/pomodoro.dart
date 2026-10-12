enum FocusPhase { focus, shortBreak, longBreak }

extension FocusPhaseX on FocusPhase {
  String get label => switch (this) {
        FocusPhase.focus => 'Focus',
        FocusPhase.shortBreak => 'Short break',
        FocusPhase.longBreak => 'Long break',
      };
}

class FocusSettings {
  final int focusMinutes;
  final int shortBreakMinutes;
  final int longBreakMinutes;
  final int longBreakEvery; // a long break after this many focus sessions

  const FocusSettings({
    this.focusMinutes = 25,
    this.shortBreakMinutes = 5,
    this.longBreakMinutes = 15,
    this.longBreakEvery = 4,
  });

  int secondsFor(FocusPhase p) =>
      60 *
      switch (p) {
        FocusPhase.focus => focusMinutes,
        FocusPhase.shortBreak => shortBreakMinutes,
        FocusPhase.longBreak => longBreakMinutes,
      };

  FocusSettings copyWith({
    int? focusMinutes,
    int? shortBreakMinutes,
    int? longBreakMinutes,
    int? longBreakEvery,
  }) =>
      FocusSettings(
        focusMinutes: focusMinutes ?? this.focusMinutes,
        shortBreakMinutes: shortBreakMinutes ?? this.shortBreakMinutes,
        longBreakMinutes: longBreakMinutes ?? this.longBreakMinutes,
        longBreakEvery: longBreakEvery ?? this.longBreakEvery,
      );

  Map<String, dynamic> toJson() => {
        'focus': focusMinutes,
        'short': shortBreakMinutes,
        'long': longBreakMinutes,
        'every': longBreakEvery,
      };

  factory FocusSettings.fromJson(Map<String, dynamic> j) => FocusSettings(
        focusMinutes: (j['focus'] ?? 25) as int,
        shortBreakMinutes: (j['short'] ?? 5) as int,
        longBreakMinutes: (j['long'] ?? 15) as int,
        longBreakEvery: (j['every'] ?? 4) as int,
      );
}

/// The Pomodoro cycle: focus, short break, focus... with a long break after
/// every [FocusSettings.longBreakEvery] completed focus sessions.
/// [completedFocusCount] includes the session that just ended.
FocusPhase nextPhase(FocusPhase current, int completedFocusCount, FocusSettings s) {
  if (current != FocusPhase.focus) return FocusPhase.focus;
  final longDue = completedFocusCount > 0 && completedFocusCount % s.longBreakEvery == 0;
  return longDue ? FocusPhase.longBreak : FocusPhase.shortBreak;
}
