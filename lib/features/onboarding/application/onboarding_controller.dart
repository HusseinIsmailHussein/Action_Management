import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/local_onboarding_repository.dart';
import '../domain/onboarding_repository.dart';

final onboardingRepositoryProvider =
    Provider<OnboardingRepository>((ref) => LocalOnboardingRepository());

/// true once the welcome flow has been finished. main.dart loads the saved
/// value before the first frame, so the right screen shows immediately.
class OnboardingController extends Notifier<bool> {
  OnboardingController([this._initial = false]);
  final bool _initial;

  @override
  bool build() => _initial;

  Future<void> complete() async {
    state = true;
    await ref.read(onboardingRepositoryProvider).setCompleted(true);
  }
}

final onboardingCompletedProvider =
    NotifierProvider<OnboardingController, bool>(OnboardingController.new);
