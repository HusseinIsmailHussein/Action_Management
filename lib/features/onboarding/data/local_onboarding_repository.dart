import 'package:shared_preferences/shared_preferences.dart';
import '../domain/onboarding_repository.dart';

class LocalOnboardingRepository implements OnboardingRepository {
  static const _key = 'onboarding_done_v1';

  @override
  Future<bool> isCompleted() async =>
      (await SharedPreferences.getInstance()).getBool(_key) ?? false;

  @override
  Future<void> setCompleted(bool value) async =>
      (await SharedPreferences.getInstance()).setBool(_key, value);
}
