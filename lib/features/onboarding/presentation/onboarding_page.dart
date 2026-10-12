import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/app_card.dart';
import '../../settings/presentation/appearance_controls.dart';
import '../application/onboarding_controller.dart';
import '../application/sample_data_service.dart';

/// Welcome flow: four short pages ending with look & feel and a choice to
/// start with sample data. With [firstRun] false (replayed from Settings) it
/// is just a tour and closes when done.
class OnboardingPage extends ConsumerStatefulWidget {
  final bool firstRun;
  const OnboardingPage({super.key, this.firstRun = true});
  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage> {
  static const _lastPage = 3;
  final _controller = PageController();
  int _page = 0;
  bool _busy = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _goTo(int page) => _controller.animateToPage(page,
      duration: const Duration(milliseconds: 300), curve: Curves.easeOutCubic);

  Future<void> _finish({required bool withSamples}) async {
    if (_busy) return;
    if (!widget.firstRun) {
      Navigator.pop(context);
      return;
    }
    setState(() => _busy = true);
    try {
      if (withSamples) await ref.read(sampleDataServiceProvider).add();
    } catch (_) {
      // Sample data is a nicety; never block the user from starting.
    }
    // Completing swaps this page for the app, so nothing runs after it.
    await ref.read(onboardingCompletedProvider.notifier).complete();
  }

  Widget _slide({
    required IconData icon,
    required Color color,
    required String title,
    required String body,
    List<Widget> children = const [],
  }) =>
      Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            _Hero(icon: icon, color: color),
            const SizedBox(height: 28),
            Text(title,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            Text(body,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 15,
                    height: 1.4,
                    color: Theme.of(context).colorScheme.onSurfaceVariant)),
            if (children.isNotEmpty) ...[const SizedBox(height: 20), ...children],
          ]),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final accent = AppAccent.of(context);
    final last = _page == _lastPage;

    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          SizedBox(
            height: 48,
            child: Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: widget.firstRun
                    ? (last
                        ? null
                        : TextButton(
                            onPressed: () => _goTo(_lastPage), child: const Text('Skip')))
                    : IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.pop(context),
                      ),
              ),
            ),
          ),
          Expanded(
            child: PageView(
              controller: _controller,
              onPageChanged: (i) => setState(() => _page = i),
              children: [
                _slide(
                  icon: Icons.check_rounded,
                  color: accent,
                  title: 'Welcome to TickApp',
                  body: 'Tasks, calendar, habits and focus time, all in one calm place.',
                ),
                _slide(
                  icon: Icons.checklist_rounded,
                  color: AppColors.blue,
                  title: 'Plan your day',
                  body: 'Capture anything fast, then shape it as it grows.',
                  children: const [
                    _Feature(Icons.today_rounded, AppColors.blue, 'Smart views',
                        'Today, Upcoming, lists, tags and saved filters.'),
                    _Feature(Icons.notifications_active_rounded, AppColors.orange,
                        'Reminders & repeat', 'Several reminders, flexible repeats.'),
                    _Feature(Icons.notes_rounded, AppColors.violet, 'Notes & subtasks',
                        'Rich notes with checklists, dated subtasks.'),
                    _Feature(Icons.calendar_month_rounded, AppColors.teal, 'Calendar',
                        'Month and hour-by-hour day view.'),
                  ],
                ),
                _slide(
                  icon: Icons.local_fire_department_rounded,
                  color: AppColors.pink,
                  title: 'Build routines',
                  body: 'Stay consistent and protect your attention.',
                  children: const [
                    _Feature(Icons.local_fire_department_rounded, AppColors.pink, 'Habits',
                        'Daily goals, streaks and a month heatmap.'),
                    _Feature(Icons.timer_rounded, AppColors.violet, 'Focus timer',
                        'Pomodoro sessions you can tie to a task.'),
                    _Feature(Icons.home_rounded, AppColors.brand, 'Home',
                        'Everything for today at a glance.'),
                  ],
                ),
                _slide(
                  icon: Icons.palette_rounded,
                  color: accent,
                  title: 'Make it yours',
                  body: 'Pick a look. You can change it later in Settings.',
                  children: const [AppCard(child: AppearanceControls())],
                ),
              ],
            ),
          ),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            for (var i = 0; i <= _lastPage; i++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: i == _page ? 24 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: i == _page ? accent : accent.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
          ]),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
            child: !last
                ? SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      style: FilledButton.styleFrom(padding: const EdgeInsets.all(16)),
                      onPressed: () => _goTo(_page + 1),
                      child: const Text('Next'),
                    ),
                  )
                : widget.firstRun
                    ? Column(children: [
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(padding: const EdgeInsets.all(16)),
                            onPressed: _busy ? null : () => _finish(withSamples: true),
                            icon: const Icon(Icons.auto_awesome_rounded),
                            label: const Text('Start with sample tasks'),
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(padding: const EdgeInsets.all(16)),
                            onPressed: _busy ? null : () => _finish(withSamples: false),
                            child: const Text('Start empty'),
                          ),
                        ),
                      ])
                    : SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          style: FilledButton.styleFrom(padding: const EdgeInsets.all(16)),
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Done'),
                        ),
                      ),
          ),
        ]),
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  final IconData icon;
  final Color color;
  const _Hero({required this.icon, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        width: 120,
        height: 120,
        decoration: BoxDecoration(
          gradient: color.gradient,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
                color: color.withValues(alpha: 0.35),
                blurRadius: 28,
                offset: const Offset(0, 12)),
          ],
        ),
        child: Icon(icon, size: 56, color: Colors.white),
      );
}

class _Feature extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  const _Feature(this.icon, this.color, this.title, this.subtitle);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(children: [
          IconBadge(icon: icon, color: color, size: 44),
          const SizedBox(width: 16),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              Text(subtitle,
                  style: TextStyle(
                      fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ]),
          ),
        ]),
      );
}
