import 'package:shared_preferences/shared_preferences.dart';

class AppLockService {
  AppLockService._();

  static final AppLockService instance = AppLockService._();

  static const _enabledKey = 'app_lock_enabled';
  static const _pinKey = 'app_lock_pin';

  Future<SharedPreferences> _prefs() {
    return SharedPreferences.getInstance();
  }

  Future<bool> isEnabled() async {
    final prefs = await _prefs();
    return prefs.getBool(_enabledKey) ?? false;
  }

  Future<void> setEnabled(bool value) async {
    final prefs = await _prefs();
    await prefs.setBool(_enabledKey, value);
  }

  Future<void> clearLegacyPin() async {
    final prefs = await _prefs();
    await prefs.remove(_pinKey);
  }
}
