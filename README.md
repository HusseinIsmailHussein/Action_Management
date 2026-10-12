# TickApp (TickTick-style Flutter starter)

## Run
    flutter create .        # generates android/ios/web folders (keeps lib/)
    # then follow NOTIFICATIONS_SETUP.md (manifest / gradle / AppDelegate)
    flutter pub get
    flutter run

Requires Flutter >= 3.38.1.

## Structure (feature-first, layered)
    lib/
      main.dart                   composition root (picks implementations)
      app_shell.dart              bottom-nav tab registry
      core/                       theme + design tokens (AppColors), shared widgets
                                  (AppCard, GradientFab, EmptyState), date helpers, navigator key
      features/
        tasks/
          domain/                 models, repository + ReminderScheduler interfaces, reminder rules
          data/                   storage + notification implementations
          application/            Riverpod controllers & derived providers
          presentation/           pages & widgets
        calendar/
          application/            calendar state + tasks-by-day providers
          presentation/           month grid, day timeline, page
        (calendar projects repeats only for the visible month; see visibleRangeProvider)
        backup/
          domain/                 BackupBundle: one JSON document with all data (+ validation)
          data/                   share-sheet exporter (share_plus)
          application/            BackupService: collect all repositories / restore them
          presentation/           Backup & restore screen
        onboarding/
          domain/                 sample tasks + habits (ids prefixed "sample-")
          data/                   "seen the intro" flag
          application/            first-run flag, add/remove sample data
          presentation/           4-page welcome flow (look & feel, start with samples or empty)
        shortcuts/
          domain/                 ShortcutAction (new task / new habit / start focus) + service interface
          data/                   quick_actions implementation
          application/            service provider (overridden in main.dart)
        settings/
          domain/                 AppSettings (theme mode, accent color) + repository interface
          data/                   local storage
          application/            settings controller (loaded before the first frame)
          presentation/           Settings screen: appearance, backup entry (add sections here)
        search/
          domain/                 matching + ranking across tasks, habits, lists, tags, filters, trash (pure Dart)
          application/            query + grouped results providers, recent searches
          presentation/           Search screen (search icon on Home and Tasks)
        review/
          domain/                 ReviewPeriod + buildReview: tasks, habits, focus and what's next (pure Dart)
          application/            selected week/month, review data provider
          presentation/           Review screen (opened from the Home tab)
        archive/
          domain/                 per-day history of finished tasks and met habit goals (pure Dart)
          application/            activity providers (week / month counts, 14-day chart)
          presentation/           Activity screen (opened from the Home tab)
        dashboard/
          application/            today's tasks, overdue count, combined day progress
          presentation/           Home tab: greeting, stats, up next, habit rings, focus card
        habits/
          domain/                 habit model, streak + completion rules (pure Dart)
          data/                   local storage
          application/            habit controller, today's groups + progress
          presentation/           habit cards, detail + heatmap, create/edit form
        focus/
          domain/                 phases, settings, session model, Pomodoro cycle rules
          data/                   local storage
          application/            timer state machine, stats providers
          presentation/           timer ring, controls, stats, settings

Dependency direction: presentation -> application -> domain <- data.
Features may import another feature's application/presentation (calendar uses tasks);
never the reverse.

## How to extend
- New screen/feature: create features/<name>/ (same layers), add one AppTab in app_shell.dart.
- New storage (Drift/Isar/Firebase): implement TaskRepository / ListRepository,
  change one line in the repository provider.
- New notification backend: implement ReminderScheduler, override reminderSchedulerProvider in main.dart.
- New reminder option: edit reminderPresetsFor / reminderLabel in domain/reminder.dart.
- New repeat rule (e.g. a specific day of the month): extend Recurrence in
  domain/recurrence.dart; the roll-forward logic is domain/next_occurrence.dart.
- New filter dimension: add a field + check + JSON in domain/task_filter.dart and a chip group
  in FilterEditor (presentation/filter_sheet.dart); saved filters pick it up automatically.
- Tags are plain strings on tasks (derived list in allTagsProvider); for tag colors or
  nesting, introduce a Tag model + repository like TaskList.
- Tab switches from anywhere: ref.read(tabRequestProvider.notifier).open(AppTabs.habits)
  (core/tab_request.dart). New dashboard section: add a widget in dashboard_page.dart.
- Cross-feature requests (e.g. "focus on this task") go through small providers in core/
  (focus_request.dart, timer_alarm.dart) so features don't import each other's UI.
- New timer phase rule or auto-start: edit domain/pomodoro.dart / FocusTimerController.
- New notification group: add a group name to NotificationBatch (core/notification_batch.dart)
  and an id range in local_notification_scheduler.dart.
- New habit rule (e.g. "3 times a week"): add it to Habit + habit_stats.dart; the UI only
  reads currentStreak/bestStreak/completionRate.
- Task notes are Markdown: parsing lives in domain/markdown.dart (pure Dart), rendering in
  presentation/markdown_view.dart, formatting toolbar in markdown_editor.dart.
- Task reminders are a list of "minutes before" values (several per task and per subtask).
- Backup a new kind of data: add a field to BackupBundle (toJson + parse) and read/write it in
  BackupService. A file-picker import can be added as another way to feed BackupBundle.parse().
- Sorting lives in domain/task_sorting.dart and grouping in domain/task_grouping.dart (pure Dart);
  the choice is saved by ViewOptionsController. A new sort or group = one enum value + one case.
- Swipe actions show an Undo snackbar (restore via TaskController.restore); list sections can be
  collapsed (collapsedGroupsProvider).
- Manual order: TaskItem.order + TaskController.applyManualOrder (re-deals the existing positions,
  so it never needs renumbering). Drag UI is SliverReorderableList in home_page.dart.
- Deleting a task / habit goes through TaskController.remove / HabitController.remove, which also
  store it in the trash (trash_controller.dart / habit_trash_controller.dart); restore() brings it
  back. The Trash screen lives in settings/. Trash is not part of backups.
- Search buttons call ref.read(openSearchProvider)(context) (core/search_launcher.dart), which
  main.dart points at the search screen. A new searchable kind = a field in SearchResults + a section.
- The review's text summary is built in review/domain/review_text.dart; sharing goes through
  ReviewSharer (share_plus implementation in review/data, clipboard fallback in the screen).
- Quick add: the parser is domain/quick_add.dart (pure Dart, tested in test/quick_add_test.dart);
  the add sheet shows what it detected as chips. A new phrase = one more take(...) rule there.
- New smart view: add to SmartView + a case in matchesSmart.
- New task field (tags, repeat...): add to TaskItem (+ toJson/fromJson/copyWith),
  then add a control in task_detail_page.dart. All edits go through TaskController.edit().
- Sunday-first calendar: change kFirstWeekday in core/date_utils.dart.

## Included
Tasks (rich Markdown notes with checklists, due date + time + duration, several reminders, repeat
(daily to yearly, custom intervals, chosen weekdays, end date or count, optionally from completion date), priority, tags, pin, won't do, comments, duplicate; subtasks with
their own date, time and reminders), custom colored lists,
smart views with sort (smart / due / priority / title / created / manual drag-to-reorder, reversible) and grouping (date / priority / list), tag views, filters (priority / due / list / tags) that can be saved as named drawer entries, search, month calendar (shows future repeats) + hourly day timeline, local notifications
(tap opens the task; rescheduled automatically on every change), local persistence, light/dark.
Home-screen shortcuts: long-press the app icon for New task, New habit, Start focus.
Welcome flow on first launch (optional sample data, removable from Settings).
Natural-language quick add ("Dentist friday 3pm for 1h #health !high every week").
Light / dark / system theme and a choice of accent colors.
Trash: deleted tasks and habits are kept 30 days and can be restored (Settings > Trash);
Undo bars for deleting tasks, habits, lists and saved filters.
Backup & restore of all data (share a .json file or copy it; restore by pasting).
Global search (with recent searches; also in the Calendar menu): tasks (titles, notes, subtasks, comments, tags), habits, lists, tags, filters, trash.
Weekly & monthly review (done, slipped with quick reschedule, habits, focus, next period),
shareable as plain text.
Activity history: finished tasks and habit goals by day, with weekly stats and a 14-day chart.
Home dashboard (greeting + day progress, tasks/habits/focus at a glance, up next, quick habit check-ins).
Habit tracker with optional daily reminders (daily or chosen weekdays, daily goals like 8 glasses, streaks, 30-day rate,
month heatmap with back-filling).
Pomodoro focus timer (optionally tied to a task, alarm when the app is in the background,
today/week stats, adjustable durations).
Data from earlier versions migrates automatically.
