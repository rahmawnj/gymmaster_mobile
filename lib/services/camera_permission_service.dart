import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

enum CameraPermissionResult { granted, denied, permanentlyDenied, unsupported }

class CameraPermissionService {
  const CameraPermissionService();

  Future<CameraPermissionResult> ensureCameraPermission() async {
    if (!_supportsCameraPermissionPrompt) {
      return CameraPermissionResult.unsupported;
    }

    var status = await Permission.camera.status;
    if (status.isGranted || status.isLimited) {
      return CameraPermissionResult.granted;
    }

    status = await Permission.camera.request();
    if (status.isGranted || status.isLimited) {
      return CameraPermissionResult.granted;
    }

    if (status.isPermanentlyDenied || status.isRestricted) {
      return CameraPermissionResult.permanentlyDenied;
    }

    return CameraPermissionResult.denied;
  }

  Future<bool> openSettings() {
    return openAppSettings();
  }

  bool get _supportsCameraPermissionPrompt {
    if (kIsWeb) {
      return false;
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.iOS:
        return true;
      case TargetPlatform.fuchsia:
      case TargetPlatform.linux:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
        return false;
    }
  }
}
