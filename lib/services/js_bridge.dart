import 'package:flutter_inappwebview/flutter_inappwebview.dart';

/// Manages JavaScript injection into the WebView.
///
/// Provides three injection blocks:
/// 1. Signal Interceptor — captures postMessage cable events
/// 2. Error Reporter — sends JS/native errors to Route.api (channel 33591)
/// 3. Compatibility Check — detects OS version and warns on unsupported features
class JsBridge {
  /// Injects all JavaScript blocks into the WebView controller.
  ///
  /// Should be called in `onLoadStop` after the page has fully loaded.
  static Future<void> injectAll(InAppWebViewController controller) async {
    await controller.evaluateJavascript(source: _flutterBridge);
    await controller.evaluateJavascript(source: _errorReporter);
    await controller.evaluateJavascript(source: _compatibilityCheck);
  }

  /// Block 1: Flutter Bridge
  ///
  /// Exposes the Flutter object to the window so the frontend can call
  /// native methods like EnableInBackgroundMicrophone.
  static const String _flutterBridge = '''
(function() {
  if (window.Flutter) return;
  
  // Define Flutter using prototype to avoid DataCloneError during postMessage.
  // The structured clone algorithm ignores prototype functions.
  function TopluyoFlutter() {}
  TopluyoFlutter.prototype.EnableInBackgroundMicrophone = function(enable) {
    try {
      window.flutter_inappwebview.callHandler('EnableInBackgroundMicrophone', enable);
    } catch(e) {
      console.warn('[Topluyo-Mobile] Flutter handler unavailable:', e);
    }
  };
  window.Flutter = new TopluyoFlutter();

  // Add Flutter class to body as requested
  if (document.body) {
    document.body.classList.add("Flutter");
  } else {
    // In case body is not ready yet, wait for DOMContentLoaded
    document.addEventListener('DOMContentLoaded', function() {
      document.body.classList.add("Flutter");
    });
  }
})();
''';

  /// Block 2: Error Reporter
  ///
  /// Captures JavaScript errors and unhandled promise rejections,
  /// then reports them via Route.api to channel 33591.
  /// Also exposes `__topluyo_reportNativeError` for Flutter-side error reporting.
  static const String _errorReporter = '''
(function() {
  if (window.__topluyo_error_injected) return;
  window.__topluyo_error_injected = true;

  // Core error reporting function
  window.__topluyo_reportError = function(errorText) {
    try {
      if (typeof Route !== 'undefined' && Route.api) {
        Route.api({
          api: "/!api/post/add",
          data: { channel_id: 33591, code: "", text: errorText }
        });
      } else if (window.Route && window.Route.api) {
        window.Route.api({
          api: "/!api/post/add",
          data: { channel_id: 33591, code: "", text: errorText }
        });
      }
    } catch(e) {
      // Silently fail if error reporting itself errors
    }
  };

  // Catch JS runtime errors
  window.addEventListener('error', function(event) {
    var errorText = '[Topluyo-Mobile/JS] ' +
      event.message + ' | ' +
      (event.filename || 'unknown') + ':' +
      (event.lineno || '?') + ':' +
      (event.colno || '?');
      
    if (event.error && event.error.stack) {
      errorText += '\\nStack: ' + event.error.stack;
    }

    window.__topluyo_reportError(errorText);
  });

  // Catch unhandled promise rejections
  window.addEventListener('unhandledrejection', function(event) {
    var errorText = '[Topluyo-Mobile/Promise] ' +
      (event.reason ? (event.reason.message || String(event.reason)) : 'Unknown rejection');

    window.__topluyo_reportError(errorText);
  });

  // Callable from Flutter native side
  window.__topluyo_reportNativeError = function(errorText) {
    window.__topluyo_reportError('[Topluyo-Mobile/Native] ' + errorText);
  };
})();
''';

  /// Block 3: Compatibility Check
  ///
  /// Detects the device OS and version from userAgent, determines which
  /// features are supported, and reports back to Flutter via callHandler('onCompatCheck').
  /// If a feature is unsupported, a warning is sent via the error reporter.
  static const String _compatibilityCheck = '''
(function() {
  if (window.__topluyo_compat_injected) return;
  window.__topluyo_compat_injected = true;

  var ua = navigator.userAgent;
  var info = {
    platform: 'unknown',
    version: 0,
    supported: {
      foregroundService: false,
      camera: false,
      microphone: false
    }
  };

  // Detect Android version
  var androidMatch = ua.match(/Android\\s+([\\d.]+)/);
  if (androidMatch) {
    info.platform = 'android';
    info.version = parseFloat(androidMatch[1]);
    info.supported.microphone = true;
    info.supported.camera = true;
    info.supported.foregroundService = (info.version >= 8.0);
  }

  // Detect iOS version
  var iosMatch = ua.match(/OS\\s+([\\d_]+)\\s+like\\s+Mac\\s+OS/);
  if (iosMatch) {
    info.platform = 'ios';
    info.version = parseFloat(iosMatch[1].replace(/_/g, '.'));
    info.supported.microphone = (info.version >= 14.5);
    info.supported.camera = (info.version >= 14.5);
    info.supported.foregroundService = true;
  }

  // Store globally for reference
  window.__topluyo_compat = info;

  // Report to Flutter
  try {
    window.flutter_inappwebview.callHandler('onCompatCheck', JSON.stringify(info));
  } catch(e) {
    console.warn('[Topluyo-Mobile] Compat check handler unavailable:', e);
  }

  // Warn if features are unsupported
  if (!info.supported.foregroundService && window.__topluyo_reportError) {
    window.__topluyo_reportError(
      '[Compat] Foreground service desteklenmiyor: ' + info.platform + ' ' + info.version
    );
  }
  if (!info.supported.microphone && window.__topluyo_reportError) {
    window.__topluyo_reportError(
      '[Compat] Mikrofon desteklenmiyor: ' + info.platform + ' ' + info.version
    );
  }
  if (!info.supported.camera && window.__topluyo_reportError) {
    window.__topluyo_reportError(
      '[Compat] Kamera desteklenmiyor: ' + info.platform + ' ' + info.version
    );
  }
})();
''';

  /// Reports a native (Dart/Flutter) error to the frontend via JS injection.
  ///
  /// Call this when a Dart exception is caught and the WebView is available.
  static Future<void> reportNativeError(
    InAppWebViewController controller,
    String errorDescription,
  ) async {
    // Escape single quotes and newlines for safe JS string injection
    final escaped = errorDescription
        .replaceAll('\\', '\\\\')
        .replaceAll("'", "\\'")
        .replaceAll('\n', '\\n')
        .replaceAll('\r', '');
    await controller.evaluateJavascript(
      source: "window.__topluyo_reportNativeError('$escaped');",
    );
  }
}
