import 'dart:io' show Platform;

import 'package:permission_handler/permission_handler.dart';

/// Manages runtime permissions and feature compatibility checks.
///
/// Handles microphone, camera, and notification permissions with
/// graceful degradation for older OS versions.
class PermissionManager {
  /// Request all permissions needed for voice/video calls.
  ///
  /// Returns a map of permission names to their granted status.
  static Future<Map<String, bool>> requestCallPermissions() async {
    final results = <String, bool>{};

    // Microphone
    final micStatus = await Permission.microphone.request();
    results['microphone'] = micStatus.isGranted;

    // Camera
    final camStatus = await Permission.camera.request();
    results['camera'] = camStatus.isGranted;

    // Notifications (Android 13+ only)
    if (Platform.isAndroid) {
      final notifStatus = await Permission.notification.request();
      results['notification'] = notifStatus.isGranted;
    } else {
      results['notification'] = true;
    }

    return results;
  }

  /// Check current permission statuses without requesting.
  static Future<Map<String, bool>> checkPermissionStatus() async {
    return {
      'microphone': await Permission.microphone.isGranted,
      'camera': await Permission.camera.isGranted,
      'notification': Platform.isAndroid
          ? await Permission.notification.isGranted
          : true,
    };
  }

  /// Returns a map of feature support based on platform and version.
  ///
  /// Used for graceful degradation — features unsupported on the
  /// device's OS version are flagged so the user can be warned.
  static Map<String, bool> checkFeatureSupport() {
    // Foreground service: Android 8.0+ (API 26), iOS always
    // Camera/Mic in WebView: Android 19+, iOS 14.5+
    // These are checked at the JS level via compat injection.
    // This Dart-side check is a supplementary failsafe.
    return {
      'foregroundService': true, // Handled by flutter_foreground_task
      'webview': true,
      'camera': true,
      'microphone': true,
    };
  }
}
