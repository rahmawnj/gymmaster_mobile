import 'package:flutter/services.dart';

class ScreenSecurityService {
  static const MethodChannel _channel = MethodChannel(
    'gymmaster/screen_security',
  );

  const ScreenSecurityService();

  Future<void> setScreenProtection(bool enabled) async {
    try {
      await _channel.invokeMethod<void>('setScreenProtection', <String, bool>{
        'enabled': enabled,
      });
    } on MissingPluginException {
      // iOS/web/desktop do not expose Android FLAG_SECURE through this channel.
    } on PlatformException {
      // Keep the app usable even if the platform cannot toggle screen security.
    }
  }
}
