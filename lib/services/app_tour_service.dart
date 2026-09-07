import 'package:shared_preferences/shared_preferences.dart';

class AppTourService {
  AppTourService._();

  static final AppTourService instance = AppTourService._();

  static const _memberHomeTourCompletedKey = 'member_home_tour_completed';

  Future<SharedPreferences> _prefs() {
    return SharedPreferences.getInstance();
  }

  Future<bool> isMemberHomeTourCompleted() async {
    final prefs = await _prefs();
    return prefs.getBool(_memberHomeTourCompletedKey) ?? false;
  }

  Future<void> markMemberHomeTourCompleted() async {
    final prefs = await _prefs();
    await prefs.setBool(_memberHomeTourCompletedKey, true);
  }
}
