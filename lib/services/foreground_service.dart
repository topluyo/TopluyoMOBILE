
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

/// Manages the foreground service and persistent notification for voice/video calls.
///
/// When the user joins a voice channel, a persistent notification is shown
/// with "Mikrofon Aç/Kapat" and "Ayrıl" buttons. This keeps the app alive
/// in the background on both Android and iOS.
class ForegroundServiceManager {
  static bool _isRunning = false;

  /// Whether the foreground service is currently active.
  static bool get isRunning => _isRunning;

  /// Initialize the foreground task configuration.
  ///
  /// Must be called once at app startup (in main.dart).
  static void initialize() {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'topluyo_call',
        channelName: 'Sesli Sohbet',
        channelDescription: 'Sesli sohbet sırasında uygulamayı arka planda çalıştırır',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
        visibility: NotificationVisibility.VISIBILITY_PUBLIC,
        playSound: false,
        enableVibration: false,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: true,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.nothing(),
        autoRunOnBoot: false,
        autoRunOnMyPackageReplaced: false,
        allowWakeLock: true,
        allowWifiLock: false,
      ),
    );
  }

  /// Start the foreground service with a persistent notification.
  ///
  /// Shows "Sesli Sohbet Aktif" notification with mic toggle and leave buttons.
  static Future<void> startService({bool micEnabled = true}) async {
    if (_isRunning) return;

    try {
      if (!await FlutterForegroundTask.isIgnoringBatteryOptimizations) {
        await FlutterForegroundTask.requestIgnoreBatteryOptimization();
      }
    } catch (_) {}

    await FlutterForegroundTask.startService(
      notificationTitle: 'Sesli Sohbet Aktif',
      notificationText: 'Arka planda çalışıyor',
      notificationButtons: [
        const NotificationButton(
          id: 'leave_call',
          text: '📞 Ayrıl',
        ),
      ],
      callback: _startCallback,
    );

    _isRunning = true;
  }

  /// Stop the foreground service and remove the notification.
  static Future<void> stopService() async {
    await FlutterForegroundTask.stopService();
    _isRunning = false;
  }

  /// Update the notification to reflect microphone state.
  static Future<void> updateNotification({required bool micEnabled}) async {
    if (!_isRunning) return;

    await FlutterForegroundTask.updateService(
      notificationTitle: 'Sesli Sohbet Aktif',
      notificationText: 'Arka planda çalışıyor',
      notificationButtons: [
        const NotificationButton(
          id: 'leave_call',
          text: '📞 Ayrıl',
        ),
      ],
    );
  }
}

/// Top-level callback function required by flutter_foreground_task.
///
/// This runs in an isolate. We use it as a minimal keepalive — actual
/// notification button handling is done via WillStartForegroundTask widget.
@pragma('vm:entry-point')
void _startCallback() {
  FlutterForegroundTask.setTaskHandler(_CallTaskHandler());
}

/// Minimal task handler for the foreground service isolate.
///
/// Notification button presses are handled by WillStartForegroundTask
/// in the main isolate, so this handler is intentionally minimal.
class _CallTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    // No-op: service just needs to stay alive
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    // No-op: we use eventAction.nothing()
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    // Cleanup if needed
  }

  @override
  void onNotificationButtonPressed(String id) {
    // Send button press to main isolate
    FlutterForegroundTask.sendDataToMain(id);
  }

  @override
  void onNotificationPressed() {
    // Tap on notification body — bring app to foreground
    FlutterForegroundTask.launchApp();
  }
}
